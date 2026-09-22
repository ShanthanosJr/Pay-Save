import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Every total is shown with its parts (NFR-07): "3 verified x LKR 5,000 =
/// LKR 15,000", never a bare number. Tapping it is meant to list the
/// underlying entries (wired up once the ledger API exists).
class PsArithmeticRow extends StatelessWidget {
  const PsArithmeticRow({
    super.key,
    required this.summary,
    required this.totalLabel,
    this.onTap,
  });

  /// The full sentence, e.g. "3 verified × LKR 5,000 = LKR 15,000".
  final String summary;

  /// The bold trailing amount, e.g. "LKR 15,000", shown in textPrimary.
  final String totalLabel;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: summary, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            Text(totalLabel, style: AppText.bodyStrong),
          ],
        ),
      ),
    );
  }
}
