import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Section title with an optional trailing action ("See more", "Invite").
class PsSectionHeader extends StatelessWidget {
  const PsSectionHeader({super.key, required this.title, this.trailing, this.large = false});

  final String title;
  final Widget? trailing;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: large ? AppText.title : AppText.section),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Grey group label above a set of rows ("Alerts", "Storage").
class PsGroupLabel extends StatelessWidget {
  const PsGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: AppSpace.s, top: AppSpace.xs),
        child: Text(text, style: AppText.footnote),
      );
}

/// Pill segmented control (Standard / Enhanced / Maximised).
class PsSegmented<T> extends StatelessWidget {
  const PsSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.onForest = false,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool onForest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onForest ? AppColors.glass : const Color(0xFFE4E8E5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: onForest ? Border.all(color: AppColors.glassStrong) : null,
      ),
      child: Row(
        children: [
          for (final (value, label) in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: AppMotion.medium,
                    curve: AppMotion.curve,
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: value == selected ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      boxShadow: value == selected ? AppColors.cardShadow : null,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(
                        color: value == selected
                            ? AppColors.ink
                            : (onForest ? AppColors.onForest : AppColors.inkMuted),
                        fontWeight: value == selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three thin progress bars, as on the reference "Add new sensor" sheet.
class PsStepBars extends StatelessWidget {
  const PsStepBars({super.key, required this.step, required this.total, this.onForest = false});

  final int step;
  final int total;
  final bool onForest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i < step;
        return Expanded(
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.curve,
            height: 5,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 8),
            decoration: BoxDecoration(
              color: done
                  ? (onForest ? AppColors.onForest : AppColors.forest600)
                  : (onForest ? AppColors.glassStrong : AppColors.stroke),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
        );
      }),
    );
  }
}
