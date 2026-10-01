import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'ps_icon_badge.dart';

/// Rounded white row: leading badge or avatar, title/subtitle, trailing.
class PsListRow extends StatelessWidget {
  const PsListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.icon,
    this.tone = PsBadgeTone.forest,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.titleColor,
    this.below,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final PsBadgeTone tone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? titleColor;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: const BorderSide(color: AppColors.stroke),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                if (leading != null)
                  leading!
                else if (icon != null)
                  PsIconBadge(icon: icon!, tone: tone, size: 38),
                if (leading != null || icon != null) const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppText.headline.copyWith(color: titleColor)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: AppText.footnote),
                      ],
                      if (below != null) ...[const SizedBox(height: 8), below!],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
                if (showChevron) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label on the left, value on the right ("Phone Number  +94 77…  ☎").
class PsInfoRow extends StatelessWidget {
  const PsInfoRow({super.key, required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.stroke),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Row(children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: c.maxWidth * 0.42),
            child: Text(label, style: AppText.footnote, maxLines: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, style: AppText.bodyStrong, overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ]),
      ),
    );
  }
}
