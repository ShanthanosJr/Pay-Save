import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum PsButtonVariant { primary, secondary, light, glass, danger }

/// Pill button. primary = ink, secondary = white with hairline, light = white
/// on the forest header, glass = translucent on forest, danger = red.
class PsButton extends StatefulWidget {
  const PsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PsButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed; // null = disabled
  final PsButtonVariant variant;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;
  final bool compact;

  @override
  State<PsButton> createState() => _PsButtonState();
}

class _PsButtonState extends State<PsButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final (Color bg, Color fg, Color? border) = switch (widget.variant) {
      PsButtonVariant.primary => (AppColors.ink, AppColors.onForest, null),
      PsButtonVariant.secondary => (AppColors.surface, AppColors.ink, AppColors.strokeStrong),
      PsButtonVariant.light => (AppColors.surface, AppColors.ink, null),
      PsButtonVariant.glass => (AppColors.glass, AppColors.onForest, AppColors.glassStrong),
      PsButtonVariant.danger => (AppColors.danger, AppColors.onForest, null),
    };
    final height = widget.compact ? 48.0 : 56.0;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: AnimatedOpacity(
          opacity: widget.onPressed == null ? 0.38 : 1,
          duration: AppMotion.fast,
          child: Material(
            color: bg,
            shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: height,
                  minWidth: widget.expand ? double.infinity : 0,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.compact ? 18 : 24),
                  child: Row(
                    mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.loading)
                        SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                        )
                      else ...[
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 20, color: fg),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: AppText.button.copyWith(color: fg, fontSize: widget.compact ? 15 : 16),
                          ),
                        ),
                        if (widget.trailingIcon != null) ...[
                          const SizedBox(width: 10),
                          Icon(widget.trailingIcon, size: 20, color: fg),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small white "See more ›" pill used beside section titles.
class PsPillLink extends StatelessWidget {
  const PsPillLink({super.key, required this.label, required this.onTap, this.icon = Icons.chevron_right});

  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              decoration: const ShapeDecoration(
                color: AppColors.surface,
                shape: StadiumBorder(side: BorderSide(color: AppColors.stroke)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: AppText.label),
                const SizedBox(width: 2),
                Icon(icon, size: 18, color: AppColors.ink),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round translucent icon button for the forest header (bell, back, close).
class PsGlassIconButton extends StatelessWidget {
  const PsGlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.onForest = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final bool onForest;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badge == null ? label : '$label, $badge',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: AppSpace.minTouch,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Material(
              color: onForest ? AppColors.glass : AppColors.surface,
              shape: CircleBorder(
                side: BorderSide(color: onForest ? AppColors.glassStrong : AppColors.stroke),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Icon(icon, size: 22, color: onForest ? AppColors.onForest : AppColors.ink),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.forest600, width: 2),
                ),
                child: Text(
                  badge!,
                  style: AppText.caption.copyWith(color: AppColors.onForest, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
