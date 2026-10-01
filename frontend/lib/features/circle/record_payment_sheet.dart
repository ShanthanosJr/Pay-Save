import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';

/// Records a payment the member already made (Pay&Save never moves money).
/// With [subject] set, the organizer records cash on that member's behalf.
Future<void> showRecordPaymentSheet(
  BuildContext context, {
  required CircleSummary circle,
  required int cycleNumber,
  String? payeeName,
  CircleMember? subject,
}) {
  final l10n = AppLocalizations.of(context);
  return showPsSheet<void>(
    context: context,
    title: subject == null ? l10n.recordPaymentTitle : l10n.recordForMember,
    subtitle: subject != null
        ? l10n.recordForMemberSubtitle(subject.displayName, cycleNumber)
        : payeeName == null
            ? null
            : l10n.recordPaymentSubtitle(payeeName, cycleNumber),
    builder: (_) => _RecordPaymentBody(circle: circle, cycleNumber: cycleNumber, subject: subject),
  );
}

class _RecordPaymentBody extends ConsumerStatefulWidget {
  const _RecordPaymentBody({required this.circle, required this.cycleNumber, this.subject});

  final CircleSummary circle;
  final int cycleNumber;
  final CircleMember? subject;

  @override
  ConsumerState<_RecordPaymentBody> createState() => _RecordPaymentBodyState();
}

class _RecordPaymentBodyState extends ConsumerState<_RecordPaymentBody> {
  // Kept for the life of the sheet so a retry can never create a second record.
  final _clientEntryId = const Uuid().v4();
  final _reference = TextEditingController();
  late PaymentMethod _method = widget.subject == null ? PaymentMethod.bankTransfer : PaymentMethod.cash;
  String _provider = walletProviders.first;
  bool _busy = false;
  String? _error;
  LedgerEntry? _saved;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ref0 = _reference.text.trim();
      final entry = await ref.read(circlesApiProvider).recordContribution(
            widget.circle.id,
            cycleNumber: widget.cycleNumber,
            method: _method,
            clientEntryId: _clientEntryId,
            provider: _method == PaymentMethod.mobileWallet ? _provider : null,
            receiptReference: ref0.isEmpty ? null : ref0,
            subjectUserId: widget.subject?.userId,
          );
      if (!mounted) return;
      refreshCircle(ref, widget.circle.id);
      setState(() => _saved = entry);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = _saved;
    if (saved != null) return _Confirmation(entry: saved);

    final hint = switch (_method) {
      PaymentMethod.cash => l10n.receiptRefHintCash,
      PaymentMethod.mobileWallet => l10n.receiptRefHintWallet,
      _ => l10n.receiptRefHintBank,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PsInfoRow(label: l10n.amountLabel, value: formatLkr(widget.circle.contributionMinor)),
      const SizedBox(height: AppSpace.s),
      PsGroupLabel(l10n.methodLabel),
      for (final m in PaymentMethod.values)
        Semantics(
          selected: _method == m,
          inMutuallyExclusiveGroup: true,
          child: PsListRow(
            icon: methodIcon(m),
            tone: _method == m ? PsBadgeTone.forest : PsBadgeTone.neutral,
            title: methodLabel(l10n, m),
            onTap: _busy ? null : () => setState(() => _method = m),
            trailing: Icon(
              _method == m ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: _method == m ? AppColors.forest600 : AppColors.strokeStrong,
            ),
          ),
        ),
      if (_method == PaymentMethod.mobileWallet) ...[
        PsGroupLabel(l10n.providerLabel),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in [...walletProviders, l10n.providerOther])
            ChoiceChip(
              label: Text(p),
              selected: _provider == p,
              onSelected: (_) => setState(() => _provider = p),
              showCheckmark: false,
              labelStyle: AppText.label.copyWith(color: _provider == p ? AppColors.onForest : AppColors.ink),
              selectedColor: AppColors.forest700,
              backgroundColor: AppColors.surface,
              shape: const StadiumBorder(side: BorderSide(color: AppColors.stroke)),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
        ]),
        const SizedBox(height: AppSpace.m),
      ],
      const SizedBox(height: AppSpace.s),
      PsTextField(
        label: l10n.receiptRefLabel,
        hint: hint,
        controller: _reference,
        maxLength: 64,
        textInputAction: TextInputAction.done,
      ),
      if (_error != null) ...[
        const SizedBox(height: AppSpace.l),
        ErrorBanner(_error!),
      ],
      const SizedBox(height: AppSpace.xl),
      PsButton(label: l10n.recordPaymentCta, onPressed: _submit, loading: _busy, icon: Icons.check_rounded),
      const SizedBox(height: AppSpace.m),
      PsButton(
        label: l10n.cancelLabel,
        variant: PsButtonVariant.secondary,
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
      ),
    ]);
  }
}

/// FR-01: an immediate, dated confirmation with the reference.
class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: AppMotion.medium,
          curve: Curves.easeOutBack,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: const PsIconBadge(icon: Icons.check_rounded, size: 76),
        ),
      ),
      const SizedBox(height: AppSpace.l),
      Text(entry.reference, textAlign: TextAlign.center, style: AppText.figure),
      const SizedBox(height: AppSpace.s),
      Center(child: PsStatusBadge(status: ContributionStatus.recorded, label: l10n.statusAwaiting)),
      const SizedBox(height: AppSpace.l),
      Text(
        l10n.recordedSuccessBody(entry.reference, dateTime(l10n, entry.createdAt)),
        textAlign: TextAlign.center,
        style: AppText.body,
      ),
      const SizedBox(height: AppSpace.l),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(AppRadii.small)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.shield_rounded, size: 20, color: AppColors.forest700),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.recordSafety, style: AppText.footnote.copyWith(color: AppColors.forest800))),
        ]),
      ),
      const SizedBox(height: AppSpace.xl),
      PsButton(label: l10n.doneLabel, onPressed: () => Navigator.of(context).pop()),
    ]);
  }
}
