import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Cream tag with terracotta text (the HOUSE / VILLA chips on Foreal).
class PsTag extends StatelessWidget {
  const PsTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppText.label.copyWith(color: AppColors.terracotta, fontSize: 12),
      ),
    );
  }
}
