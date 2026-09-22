import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Mirrors the contribution state machine (docs/MASTER_PLAN.md §5.2).
enum ContributionStatus { due, overdue, pendingSync, recorded, verified }

/// Status is always icon + word, never colour alone (design-system §5.4).
class PsStatusBadge extends StatelessWidget {
  const PsStatusBadge({super.key, required this.status, required this.label});

  final ContributionStatus status;
  final String label; // localised text supplied by caller

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (status) {
      ContributionStatus.due => (Icons.schedule, AppColors.textSecondary),
      ContributionStatus.overdue => (Icons.error_outline, AppColors.statusDue),
      ContributionStatus.pendingSync => (Icons.cloud_off_outlined, AppColors.statusPending),
      ContributionStatus.recorded => (Icons.hourglass_top, AppColors.statusPending),
      ContributionStatus.verified => (Icons.check_circle, AppColors.statusVerified),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: AppText.caption.copyWith(color: color))),
      ]),
    );
  }
}
