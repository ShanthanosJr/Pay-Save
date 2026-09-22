import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Header circle-and-role switcher (design-system §4.2). Replaces the
/// prototype's global "Select your role" because roles are per circle
/// (MASTER_PLAN §6).
class PsCircleSwitcher extends StatelessWidget {
  const PsCircleSwitcher({super.key, required this.circleName, this.onTap});

  final String circleName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: circleName,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceRaised,
                child: Icon(Icons.groups, size: 16, color: AppColors.greenBright),
              ),
              const SizedBox(width: AppSpace.xs),
              Text(circleName, style: AppText.section),
              const Icon(Icons.expand_more, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
