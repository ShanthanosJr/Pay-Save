import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/payouts/payout_models.dart';
import '../../core/payouts/payouts_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';
import 'payout_ui.dart';

/// Two steps: choose the kind, then fill only what that kind needs.
/// Pops with the new method's id so callers (e.g. accepting an invitation)
/// can select it straight away.
class AddPaymentMethodScreen extends ConsumerStatefulWidget {
  const AddPaymentMethodScreen({super.key});

  @override
  ConsumerState<AddPaymentMethodScreen> createState() => _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState extends ConsumerState<AddPaymentMethodScreen> {
  final _form = GlobalKey<FormState>();
  PayoutKind? _kind;
  String _bank = sriLankanBanks.first;
  String _wallet = walletProviders.first;
  final _bankOther = TextEditingController();
  final _branch = TextEditingController();
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _account2 = TextEditingController();
  final _number = TextEditingController();
  final _merchant = TextEditingController();
  final _qrRef = TextEditingController();
  final _note = TextEditingController();
  bool _makeDefault = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Most accounts are in the member's own name; prefill it.
    final a = ref.read(authControllerProvider);
    if (a is AuthLoggedIn) _holder.text = a.user.fullName;
  }

  @override
  void dispose() {
    for (final c in [_bankOther, _branch, _holder, _account, _account2, _number, _merchant, _qrRef, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[\s-]'), '');

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final other = _bank == l10n.bankOther;
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final details = switch (_kind!) {
      PayoutKind.bankTransfer => PayoutDetails(
        kind: PayoutKind.bankTransfer,
        bankName: other ? _bankOther.text.trim() : _bank,
        branch: opt(_branch),
        accountName: _holder.text.trim(),
        accountNumber: _digits(_account.text),
      ),
      PayoutKind.mobileWallet => PayoutDetails(
        kind: PayoutKind.mobileWallet,
        provider: _wallet == l10n.providerOther ? 'Other' : _wallet,
        accountName: _holder.text.trim(),
        number: normalizePhone(_number.text) ?? _number.text.trim(),
      ),
      PayoutKind.lankaqr => PayoutDetails(
        kind: PayoutKind.lankaqr,
        merchantName: _merchant.text.trim(),
        reference: _qrRef.text.trim(),
      ),
      PayoutKind.cash => PayoutDetails(kind: PayoutKind.cash, note: opt(_note)),
    };

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final before = (ref.read(myPayoutMethodsProvider).value ?? const []).map((m) => m.id).toSet();
      final after = await ref.read(payoutsApiProvider).add(details, makeDefault: _makeDefault);
      ref.invalidate(myPayoutMethodsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.methodAddedToast)));
      final created = after.where((m) => !before.contains(m.id)).firstOrNull ?? after.last;
      router.pop(created.id);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = _kind;
    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.addPaymentMethod, backLabel: l10n.backLabel),
        children: kind == null ? _chooser(l10n) : _formFor(l10n, kind),
      ),
    );
  }

  List<Widget> _chooser(AppLocalizations l10n) => [
    Text(l10n.addPaymentMethodSubtitle, style: AppText.section),
    const SizedBox(height: AppSpace.l),
    for (final k in PayoutKind.values)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.m),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: const BorderSide(color: AppColors.stroke),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _kind = k),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.mintSoft,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Icon(payoutKindIcon(k), color: AppColors.forest700, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payoutKindLabel(l10n, k), style: AppText.headline),
                        const SizedBox(height: 2),
                        Text(payoutKindHint(l10n, k), style: AppText.footnote),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                ],
              ),
            ),
          ),
        ),
      ),
  ];

  List<Widget> _formFor(AppLocalizations l10n, PayoutKind kind) {
    final v = Validators(l10n);
    String? required2(String? s, int min) => (s ?? '').trim().length < min ? l10n.errRequired : null;
    final banks = [...sriLankanBanks, l10n.bankOther];
    final wallets = [...walletProviders, l10n.providerOther];

    return [
      Row(
        children: [
          Icon(payoutKindIcon(kind), color: AppColors.forest700),
          const SizedBox(width: AppSpace.s),
          Expanded(child: Text(payoutKindLabel(l10n, kind), style: AppText.section)),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, AppSpace.minTouch)),
            onPressed: _busy ? null : () => setState(() => _kind = null),
            child: Text(l10n.changePayoutAction, style: AppText.label.copyWith(color: AppColors.forest700)),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.l),
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (kind) {
            PayoutKind.bankTransfer => [
              PsGroupLabel(l10n.bankNameLabel),
              DropdownButtonFormField<String>(
                initialValue: _bank,
                isExpanded: true,
                items: [for (final b in banks) DropdownMenuItem(value: b, child: Text(b, style: AppText.bodyStrong))],
                onChanged: (b) => setState(() => _bank = b ?? _bank),
              ),
              if (_bank == l10n.bankOther) ...[
                const SizedBox(height: AppSpace.l),
                PsTextField(
                  label: l10n.bankNameOtherLabel,
                  controller: _bankOther,
                  maxLength: 60,
                  validator: (s) => required2(s, 2),
                ),
              ],
              const SizedBox(height: AppSpace.l),
              PsTextField(label: l10n.branchLabel, controller: _branch, maxLength: 60),
              const SizedBox(height: AppSpace.l),
              PsTextField(
                label: l10n.accountNameLabel,
                controller: _holder,
                maxLength: 80,
                validator: (s) => required2(s, 2),
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: AppSpace.l),
              PsTextField(
                label: l10n.accountNumberLabel,
                controller: _account,
                keyboardType: TextInputType.number,
                maxLength: 24,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 -]'))],
                validator: (s) => RegExp(r'^\d{6,20}$').hasMatch(_digits(s ?? '')) ? null : l10n.errAccountNumber,
              ),
              const SizedBox(height: AppSpace.l),
              PsTextField(
                label: l10n.confirmAccountNumberLabel,
                helper: l10n.confirmAccountNumberHint,
                controller: _account2,
                keyboardType: TextInputType.number,
                maxLength: 24,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 -]'))],
                validator: (s) => _digits(s ?? '') == _digits(_account.text) ? null : l10n.errAccountMismatch,
              ),
            ],
            PayoutKind.mobileWallet => [
              PsGroupLabel(l10n.walletProviderLabel),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in wallets)
                    ChoiceChip(
                      label: Text(w),
                      selected: _wallet == w,
                      onSelected: (_) => setState(() => _wallet = w),
                      showCheckmark: false,
                      labelStyle: AppText.label.copyWith(color: _wallet == w ? AppColors.onForest : AppColors.ink),
                      selectedColor: AppColors.forest700,
                      backgroundColor: AppColors.surface,
                      shape: const StadiumBorder(side: BorderSide(color: AppColors.stroke)),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.l),
              PsTextField(
                label: l10n.registeredNameLabel,
                controller: _holder,
                maxLength: 80,
                validator: (s) => required2(s, 2),
              ),
              const SizedBox(height: AppSpace.l),
              PsTextField(
                label: l10n.walletNumberLabel,
                hint: l10n.phoneHint,
                controller: _number,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: v.phone,
              ),
            ],
            PayoutKind.lankaqr => [
              PsTextField(
                label: l10n.merchantNameLabel,
                controller: _merchant,
                maxLength: 80,
                validator: (s) => required2(s, 2),
              ),
              const SizedBox(height: AppSpace.l),
              PsTextField(
                label: l10n.lankaqrReferenceLabel,
                controller: _qrRef,
                maxLength: 40,
                textInputAction: TextInputAction.done,
                validator: (s) => required2(s, 3),
              ),
            ],
            PayoutKind.cash => [
              PsTextField(
                label: l10n.cashNoteLabel,
                hint: l10n.cashNoteHint,
                controller: _note,
                maxLength: 120,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
            ],
          },
        ),
      ),
      const SizedBox(height: AppSpace.l),
      Material(
        type: MaterialType.transparency,
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _makeDefault,
          onChanged: (b) => setState(() => _makeDefault = b),
          title: Text(l10n.makeDefaultLabel, style: AppText.bodyStrong),
          activeTrackColor: AppColors.forest600,
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: AppSpace.s),
          Expanded(child: Text(l10n.paymentMethodsPrivacy, style: AppText.footnote)),
        ],
      ),
      if (_error != null) ...[const SizedBox(height: AppSpace.l), ErrorBanner(_error!)],
      const SizedBox(height: AppSpace.xl),
      PsButton(label: l10n.savePaymentMethod, icon: Icons.check_rounded, loading: _busy, onPressed: _save),
    ];
  }
}
