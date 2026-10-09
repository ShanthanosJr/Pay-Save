import 'package:flutter/material.dart';

import '../../core/circles/circle_models.dart';
import '../../core/payouts/payout_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';

/// Licensed commercial and specialised banks members commonly use.
const sriLankanBanks = [
  'Bank of Ceylon',
  "People's Bank",
  'Commercial Bank',
  'Hatton National Bank',
  'Sampath Bank',
  'Seylan Bank',
  'National Savings Bank',
  'Nations Trust Bank',
  'NDB Bank',
  'DFCC Bank',
  'Pan Asia Bank',
  'Union Bank',
  'Cargills Bank',
  'Amãna Bank',
  'HDFC Bank',
  'Regional Development Bank',
  'Sanasa Development Bank',
];

String payoutKindLabel(AppLocalizations l10n, PayoutKind k) => switch (k) {
  PayoutKind.bankTransfer => l10n.payoutKindBank,
  PayoutKind.mobileWallet => l10n.payoutKindWallet,
  PayoutKind.lankaqr => l10n.payoutKindLankaqr,
  PayoutKind.cash => l10n.payoutKindCash,
};

String payoutKindHint(AppLocalizations l10n, PayoutKind k) => switch (k) {
  PayoutKind.bankTransfer => l10n.payoutKindBankHint,
  PayoutKind.mobileWallet => l10n.payoutKindWalletHint,
  PayoutKind.lankaqr => l10n.payoutKindLankaqrHint,
  PayoutKind.cash => l10n.payoutKindCashHint,
};

IconData payoutKindIcon(PayoutKind k) => switch (k) {
  PayoutKind.bankTransfer => Icons.account_balance_rounded,
  PayoutKind.mobileWallet => Icons.phone_iphone_rounded,
  PayoutKind.lankaqr => Icons.qr_code_2_rounded,
  PayoutKind.cash => Icons.payments_rounded,
};

/// The recording method that matches how the payee wants to be paid.
PaymentMethod paymentMethodFor(PayoutKind k) => switch (k) {
  PayoutKind.bankTransfer => PaymentMethod.bankTransfer,
  PayoutKind.mobileWallet => PaymentMethod.mobileWallet,
  PayoutKind.lankaqr => PaymentMethod.lankaqr,
  PayoutKind.cash => PaymentMethod.cash,
};

/// A payment method drawn like the thing it is: a bank card, a wallet, cash.
/// Shows only the masked summary; full numbers never appear here.
class PayoutMethodCard extends StatelessWidget {
  const PayoutMethodCard({
    super.key,
    required this.kind,
    required this.summary,
    this.holder,
    this.isDefault = false,
    this.preferred = false,
    this.trailing,
    this.onTap,
    this.selected,
  });

  final PayoutKind kind;
  final String summary;
  final String? holder;
  final bool isDefault;
  final bool preferred;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// When not null the card is a checkbox (selection lists).
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bank = kind == PayoutKind.bankTransfer;
    final fg = bank ? AppColors.onForest : AppColors.ink;
    final sub = bank ? AppColors.onForestMuted : AppColors.inkMuted;
    final isSelected = selected == true;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: [
        payoutKindLabel(l10n, kind),
        summary,
        ?holder,
        if (isDefault) l10n.defaultLabel,
        if (preferred) l10n.preferredLabel,
      ].join(', '),
      excludeSemantics: trailing == null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.m),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              decoration: BoxDecoration(
                gradient: bank ? AppColors.headerGradient : null,
                color: bank ? null : (kind == PayoutKind.cash ? AppColors.warningSoft : AppColors.surface),
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(
                  color: isSelected ? AppColors.forest600 : (bank ? Colors.transparent : AppColors.stroke),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bank ? AppColors.glass : AppColors.mintSoft,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Icon(payoutKindIcon(kind), color: bank ? AppColors.onForest : AppColors.forest700),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payoutKindLabel(l10n, kind), style: AppText.caption.copyWith(color: sub)),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: AppText.headline.copyWith(color: fg, letterSpacing: bank ? 0.5 : null),
                        ),
                        if (holder != null) ...[
                          const SizedBox(height: 2),
                          Text(holder!, style: AppText.footnote.copyWith(color: sub)),
                        ],
                        if (isDefault || preferred) ...[
                          const SizedBox(height: 6),
                          PsStatusPill(
                            label: isDefault ? l10n.defaultLabel : l10n.preferredLabel,
                            tone: PsPillTone.success,
                            icon: Icons.star_rounded,
                            filled: !bank,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selected != null)
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? (bank ? AppColors.onForest : AppColors.forest600) : sub,
                      size: 28,
                    ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
