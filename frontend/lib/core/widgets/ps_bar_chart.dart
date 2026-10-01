import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class PsBar {
  const PsBar({required this.label, required this.value, this.highlight = false, this.empty = false});

  final String label;
  final int value;
  final bool highlight;
  final bool empty;
}

/// Soft mint bars with the axis label inside the foot of each bar.
class PsBarChart extends StatelessWidget {
  const PsBarChart({super.key, required this.bars, this.height = 132, required this.semanticLabel});

  final List<PsBar> bars;
  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final max = bars.fold<int>(1, (m, b) => b.value > m ? b.value : m);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final b in bars)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: b.empty ? 0 : b.value / max),
                    duration: const Duration(milliseconds: 700),
                    curve: AppMotion.curve,
                    builder: (context, t, _) => Container(
                      height: b.empty ? 28 : 28 + (height - 28) * t,
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: b.empty
                            ? Colors.transparent
                            : (b.highlight ? AppColors.forest600 : AppColors.mint),
                        border: b.empty ? const Border(bottom: BorderSide(color: AppColors.strokeStrong, width: 2)) : null,
                        borderRadius: b.empty ? null : BorderRadius.circular(12),
                      ),
                      child: Text(
                        b.label,
                        style: AppText.caption.copyWith(
                          color: b.highlight ? AppColors.onForest : AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
