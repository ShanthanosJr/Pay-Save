import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A 2-column home tile.
class PsGridTile extends StatelessWidget {
  const PsGridTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.caption,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Icon(icon, color: AppColors.terracotta, size: 22),
              ),
              const Spacer(),
              Text(title, style: AppText.small),
              const SizedBox(height: AppSpace.xs),
              Text(subtitle, style: AppText.title),
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
