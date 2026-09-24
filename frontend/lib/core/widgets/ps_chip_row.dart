import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Filter chips: selected = ink fill, others white (ALL / RENT / SALE on Foreal).
/// Each chip is at least 48dp tall.
class PsChipRow extends StatelessWidget {
  const PsChipRow({super.key, required this.labels, this.selectedIndex = 0, this.onSelected});

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpace.minTouch,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpace.s),
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          return Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: selected ? AppColors.ink : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                onTap: () => onSelected?.call(i),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    labels[i].toUpperCase(),
                    style: AppText.label.copyWith(
                      color: selected ? AppColors.onDark : AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
