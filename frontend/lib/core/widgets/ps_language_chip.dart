import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Language choice over the hero photo. Selected = white, others translucent.
/// Kept >= 48dp tall.
class PsLanguageChip extends StatelessWidget {
  const PsLanguageChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: Container(
          height: AppSpace.minTouch,
          constraints: const BoxConstraints(minWidth: AppSpace.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : AppColors.scrim,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppText.label.copyWith(
                color: selected ? AppColors.ink : AppColors.onDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
