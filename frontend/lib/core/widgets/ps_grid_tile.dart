import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A 2-column home grid tile, e.g. "Turn order" / "My savings" (design-system §4.2).
class PsGridTile extends StatelessWidget {
  const PsGridTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.caption,
    this.onTap,
    this.onAddTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? caption;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: AppColors.greenBright, size: 28),
                  if (onAddTap != null)
                    Semantics(
                      button: true,
                      label: 'Add',
                      child: InkWell(
                        onTap: onAddTap,
                        borderRadius: BorderRadius.circular(AppRadii.addButton),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: AppSpace.minTouch,
                            minHeight: AppSpace.minTouch,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(AppRadii.addButton),
                          ),
                          child: const Icon(Icons.add, color: AppColors.textPrimary, size: 18),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              Text(title, style: AppText.cardTitle),
              const SizedBox(height: AppSpace.xs),
              Text(subtitle, style: AppText.bodyStrong),
              if (caption != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(caption!, style: AppText.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
