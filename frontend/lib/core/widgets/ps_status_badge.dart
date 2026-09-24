import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Mirrors the contribution state machine.
enum ContributionStatus { due, overdue, pendingSync, recorded, verified }

/// Status is always icon + word, never colour alone.
class PsStatusBadge extends StatelessWidget {
  const PsStatusBadge({super.key, required this.status, required this.label});

  final ContributionStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, Color bg) = switch (status) {
      ContributionStatus.due => (Icons.schedule, AppColors.ink, AppColors.hairline),
      ContributionStatus.overdue => (Icons.error_outline, AppColors.statusDue, const Color(0x1AC0392B)),
      ContributionStatus.pendingSync => (Icons.cloud_off_outlined, AppColors.statusPending, AppColors.cream),
      ContributionStatus.recorded => (Icons.hourglass_top, AppColors.statusPending, AppColors.cream),
      ContributionStatus.verified => (Icons.check_circle, AppColors.statusVerified, const Color(0x1A1F7A4D)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.chip)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
