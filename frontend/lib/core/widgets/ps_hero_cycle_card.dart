import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'ps_gradient_button.dart';
import 'ps_status_badge.dart';

/// The home hero card (design-system §4.2). Its badge and button are driven
/// entirely by the contribution state machine (MASTER_PLAN §5.2) — never
/// computed separately on this screen (AGENTS.md rule 7).
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
    this.onPayNow,
  });

  final String circleName;
  final String cycleLabel;
  final String amountLabel;
  final ContributionStatus status;
  final String statusLabel;
  final String payNowLabel;
  final String viewRecordLabel;
  final VoidCallback? onPayNow; // null hides/disables Pay now (U-01)

  @override
  Widget build(BuildContext context) {
    final showPayNow = status == ContributionStatus.due || status == ContributionStatus.overdue;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(circleName, style: AppText.cardTitle),
            const SizedBox(height: AppSpace.xs),
            Text(cycleLabel, style: AppText.caption),
            const SizedBox(height: AppSpace.m),
            Row(
              children: [
                Text(amountLabel, style: AppText.amount),
                const SizedBox(width: AppSpace.s),
                PsStatusBadge(status: status, label: statusLabel),
              ],
            ),
            const SizedBox(height: AppSpace.l),
            if (showPayNow)
              PsGradientButton(label: payNowLabel, onPressed: onPayNow)
            else
              OutlinedButton(onPressed: () {}, child: Text(viewRecordLabel)),
          ],
        ),
      ),
    );
  }
}
