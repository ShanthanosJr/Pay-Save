import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'ps_button.dart';
import 'ps_status_badge.dart';
import 'ps_tag.dart';

/// The home cycle card (a Foreal listing card). Its badge and button are
/// driven entirely by the contribution state machine — never computed
/// separately on the screen. Pay now is disabled once a record exists.
class PsHeroCycleCard extends StatelessWidget {
  const PsHeroCycleCard({
    super.key,
    required this.circleName,
    required this.cycleLabel,
    required this.amountLabel,
    required this.status,
    required this.statusLabel,
    required this.payNowLabel,
    required this.viewRecordLabel,
    this.tagLabel,
    this.onPayNow,
  });

  final String circleName;
  final String cycleLabel;
  final String amountLabel;
  final ContributionStatus status;
  final String statusLabel;
  final String payNowLabel;
  final String viewRecordLabel;
  final String? tagLabel;
  final VoidCallback? onPayNow;

  @override
  Widget build(BuildContext context) {
    final canPay = status == ContributionStatus.due || status == ContributionStatus.overdue;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE29678), Color(0xFFF0AF91)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(AppSpace.m),
            alignment: Alignment.topRight,
            child: tagLabel == null ? null : PsTag(label: tagLabel!),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(circleName, style: AppText.title),
                const SizedBox(height: AppSpace.xs),
                Text(cycleLabel, style: AppText.small),
                const SizedBox(height: AppSpace.m),
                Row(
                  children: [
                    Text(amountLabel, style: AppText.amount),
                    const SizedBox(width: AppSpace.m),
                    Flexible(child: PsStatusBadge(status: status, label: statusLabel)),
                  ],
                ),
                const SizedBox(height: AppSpace.l),
                if (canPay)
                  PsButton(label: payNowLabel, onPressed: onPayNow, trailing: Icons.arrow_forward)
                else
                  PsButton(label: viewRecordLabel, onPressed: () {}, variant: PsButtonVariant.light),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
