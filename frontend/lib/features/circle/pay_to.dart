import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/payouts/payout_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_arithmetic_row.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../core/widgets/ps_skeleton.dart';
import '../../l10n/gen/app_localizations.dart';
import '../payouts/payout_ui.dart';
import 'circle_setup.dart';

/// Who to pay this cycle and exactly how, with copy buttons. The server
/// logs every time these details are shown.
class PayToCard extends ConsumerStatefulWidget {
  const PayToCard({super.key, required this.circleId, this.onMethodChosen});

  final String circleId;

  /// Lets the record-payment form follow the method the payer picked.
  final ValueChanged<PayoutKind>? onMethodChosen;

  @override
  ConsumerState<PayToCard> createState() => _PayToCardState();
}

class _PayToCardState extends ConsumerState<PayToCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(payToProvider(widget.circleId));
    final p = async.value;
    if (p == null) {
      return async.hasError
          ? Text(messageFor(l10n, async.error!), style: AppText.footnote)
          : const PsSkeletonRows(count: 1, leading: PsSkeletonLeading.badge);
    }

    if (p.youReceive) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(AppRadii.card)),
        child: Row(
          children: [
            const Icon(Icons.celebration_rounded, color: AppColors.success, size: 28),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.youReceiveTitle, style: AppText.headline),
                  Text(l10n.youReceiveBody, style: AppText.footnote),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final methods = p.methods;
    final tab = _tab.clamp(0, methods.isEmpty ? 0 : methods.length - 1);
    final chosen = methods.isEmpty ? null : methods[tab];
    final handOver = p.collectionMode == CollectionMode.viaOrganizer && p.amount.count != 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.stroke),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                PsUserAvatar(name: p.payee.fullName, avatarUrl: p.payee.avatarUrl, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(handOver ? l10n.handOverPot(p.payee.fullName) : l10n.payToTitle, style: AppText.caption),
                      Text(p.payee.fullName, style: AppText.section),
                      Text(l10n.payToSubtitle(p.cycleNumber, shortDate(l10n, p.dueDate)), style: AppText.footnote),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l10n.amountToPay, style: AppText.caption),
                    Text(formatLkr(p.amount.totalMinor), style: AppText.figureSmall),
                  ],
                ),
              ],
            ),
          ),
          if (handOver)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: PsArithmeticRow(
                summary: l10n.arithmeticSummary(
                  p.amount.count,
                  l10n.statusVerified.toLowerCase(),
                  formatMinor(p.amount.unitMinor),
                  formatMinor(p.amount.totalMinor),
                ),
              ),
            ),
          if (p.collectionMode == CollectionMode.viaOrganizer && !handOver)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CollectionModeExplainer(mode: p.collectionMode),
            ),
          const Divider(height: 1, color: AppColors.stroke),
          if (chosen == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.warning),
                  const SizedBox(width: AppSpace.s),
                  Expanded(child: Text(l10n.payeeNoDetails(p.payee.fullName), style: AppText.footnote)),
                ],
              ),
            )
          else ...[
            if (methods.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < methods.length; i++)
                      ChoiceChip(
                        avatar: Icon(
                          payoutKindIcon(methods[i].kind),
                          size: 18,
                          color: i == tab ? AppColors.onForest : AppColors.forest700,
                        ),
                        label: Text(
                          methods[i].preferred
                              ? '${payoutKindLabel(l10n, methods[i].kind)} · ${l10n.preferredLabel}'
                              : payoutKindLabel(l10n, methods[i].kind),
                        ),
                        selected: i == tab,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _tab = i);
                          widget.onMethodChosen?.call(methods[i].kind);
                        },
                        labelStyle: AppText.label.copyWith(color: i == tab ? AppColors.onForest : AppColors.ink),
                        selectedColor: AppColors.forest700,
                        backgroundColor: AppColors.surface,
                        shape: const StadiumBorder(side: BorderSide(color: AppColors.stroke)),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Column(children: _detailRows(l10n, chosen.details)),
            ),
            if (chosen.kind != PayoutKind.cash) ...[
              const Divider(height: 1, color: AppColors.stroke),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: _CopyRow(label: l10n.referenceToUse, value: p.reference, emphasise: true),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _detailRows(AppLocalizations l10n, PayoutDetails d) => switch (d.kind) {
    PayoutKind.bankTransfer => [
      _CopyRow(label: l10n.bankNameLabel, value: d.bankName ?? '', copy: false),
      if (d.branch != null) _CopyRow(label: l10n.branchShort, value: d.branch!, copy: false),
      _CopyRow(label: l10n.accountNameLabel, value: d.accountName ?? ''),
      _CopyRow(label: l10n.accountNumberLabel, value: _groups(d.accountNumber ?? ''), raw: d.accountNumber, emphasise: true),
    ],
    PayoutKind.mobileWallet => [
      _CopyRow(label: l10n.walletProviderLabel, value: d.provider ?? '', copy: false),
      _CopyRow(label: l10n.registeredNameLabel, value: d.accountName ?? ''),
      _CopyRow(label: l10n.walletNumberLabel, value: d.number ?? '', emphasise: true),
    ],
    PayoutKind.lankaqr => [
      _CopyRow(label: l10n.merchantNameLabel, value: d.merchantName ?? ''),
      _CopyRow(label: l10n.lankaqrReferenceLabel, value: d.reference ?? '', emphasise: true),
    ],
    PayoutKind.cash => [
      _CopyRow(label: l10n.payoutKindCash, value: d.note ?? l10n.payoutKindCashHint, copy: false),
    ],
  };

  /// "007123456789" → "0071 2345 6789": easier to read back over the phone.
  static String _groups(String digits) =>
      [for (var i = 0; i < digits.length; i += 4) digits.substring(i, (i + 4).clamp(0, digits.length))].join(' ');
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, this.raw, this.copy = true, this.emphasise = false});

  final String label;
  final String value;

  /// What goes on the clipboard when it differs from what is shown.
  final String? raw;
  final bool copy;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption),
                Text(
                  value,
                  style: emphasise
                      ? AppText.figureSmall.copyWith(fontSize: 18, letterSpacing: 0.6)
                      : AppText.bodyStrong,
                ),
              ],
            ),
          ),
          if (copy)
            IconButton(
              tooltip: l10n.copyValue(label),
              constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
              icon: const Icon(Icons.copy_rounded, color: AppColors.forest700, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: raw ?? value));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copiedToast(label))));
              },
            ),
        ],
      ),
    );
  }
}

/// "Who to pay this cycle" as a standalone sheet.
Future<void> showPayToSheet(BuildContext context, String circleId) {
  final l10n = AppLocalizations.of(context);
  return showPsSheet<void>(
    context: context,
    title: l10n.whoToPay,
    builder: (_) => PayToCard(circleId: circleId),
  );
}
