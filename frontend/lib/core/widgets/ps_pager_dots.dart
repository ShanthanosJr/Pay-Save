import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Active dot is a 16x4 ink pill, inactive dots are 4x4.
class PsPagerDots extends StatelessWidget {
  const PsPagerDots({super.key, required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 4,
          height: 4,
          decoration: BoxDecoration(
            color: active ? AppColors.ink : AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
