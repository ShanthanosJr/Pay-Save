import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Every total is shown with its parts: "3 verified × LKR 5,000 = LKR 15,000",
/// never a bare number.
class PsArithmeticRow extends StatelessWidget {
  const PsArithmeticRow({
    super.key,
    required this.summary,
    this.onTap,
  });

  final String summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.mintSoft,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          children: [
            const Icon(Icons.functions_rounded, size: 18, color: AppColors.forest700),
            const SizedBox(width: 8),
            Expanded(child: Text(summary, style: AppText.label.copyWith(color: AppColors.forest800))),
          ],
        ),
      ),
    );
  }
}
