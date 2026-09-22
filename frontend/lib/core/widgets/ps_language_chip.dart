import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Language choice chip for the Welcome screen (design-system §4.1).
/// Selected = green fill; touch target kept >= 48dp tall (NFR-06 / rule 12).
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
          constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.green : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.green : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Text(
            label,
            style: AppText.section.copyWith(
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
