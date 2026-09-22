import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A horizontally scrollable row of quick-link chips (design-system §4.2).
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
        itemBuilder: (context, i) => ChoiceChip(
          label: Text(labels[i]),
          selected: i == selectedIndex,
          onSelected: (_) => onSelected?.call(i),
        ),
      ),
    );
  }
}
