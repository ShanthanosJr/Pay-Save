import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Every total is shown with its parts: "3 verified × LKR 5,000 = LKR 15,000",
/// never a bare number.
class PsArithmeticRow extends StatelessWidget {
  const PsArithmeticRow({
    super.key,
    required this.summary,
    required this.totalLabel,
    this.onTap,
  });

  final String summary;
  final String totalLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
        child: Row(
          children: [
            Expanded(child: Text(summary, style: AppText.caption)),
            const SizedBox(width: AppSpace.s),
            Text(totalLabel, style: AppText.bodyStrong),
          ],
        ),
      ),
    );
  }
}
