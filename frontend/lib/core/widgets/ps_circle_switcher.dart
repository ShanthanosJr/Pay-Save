import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Header circle switcher (roles are per circle).
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
                radius: 15,
                backgroundColor: AppColors.cream,
                child: Icon(Icons.groups, size: 16, color: AppColors.terracotta),
              ),
              const SizedBox(width: AppSpace.s),
              Text(circleName, style: AppText.title),
              const Icon(Icons.expand_more, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
