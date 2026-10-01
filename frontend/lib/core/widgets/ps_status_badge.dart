import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Mirrors the contribution state machine.
enum ContributionStatus { due, overdue, pendingSync, recorded, verified }

enum PsPillTone { success, info, warning, danger, neutral }

/// Filled status pill ("Active" / "Pending" in the reference). Always an
/// icon plus a word — never colour alone.
class PsStatusPill extends StatelessWidget {
  const PsStatusPill({super.key, required this.label, required this.tone, this.icon, this.filled = true});

  final String label;
  final PsPillTone tone;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final (Color strong, Color soft) = switch (tone) {
      PsPillTone.success => (AppColors.success, AppColors.successSoft),
      PsPillTone.info => (AppColors.info, AppColors.infoSoft),
      PsPillTone.warning => (AppColors.warning, AppColors.warningSoft),
      PsPillTone.danger => (AppColors.danger, AppColors.dangerSoft),
      PsPillTone.neutral => (AppColors.inkMuted, AppColors.canvas),
    };
    final fg = filled ? AppColors.onForest : strong;
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 12 : 9, 5, 12, 5),
      decoration: BoxDecoration(
        color: filled ? strong : soft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(color: fg, fontSize: 13),
          ),
        ),
      ]),
    );
  }
}

/// Contribution status as a pill, driven by the state machine only.
class PsStatusBadge extends StatelessWidget {
  const PsStatusBadge({super.key, required this.status, required this.label, this.filled = true});

  final ContributionStatus status;
  final String label;
  final bool filled;

  static (IconData, PsPillTone) styleFor(ContributionStatus s) => switch (s) {
        ContributionStatus.due => (Icons.schedule_rounded, PsPillTone.neutral),
        ContributionStatus.overdue => (Icons.error_outline_rounded, PsPillTone.danger),
        ContributionStatus.pendingSync => (Icons.cloud_off_rounded, PsPillTone.warning),
        ContributionStatus.recorded => (Icons.hourglass_top_rounded, PsPillTone.info),
        ContributionStatus.verified => (Icons.check_circle_rounded, PsPillTone.success),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = styleFor(status);
    return PsStatusPill(
      label: label,
      tone: tone,
      icon: icon,
      filled: filled && status != ContributionStatus.due,
    );
  }
}
