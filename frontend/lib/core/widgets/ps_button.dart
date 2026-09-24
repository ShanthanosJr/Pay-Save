import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum PsButtonVariant { primary, light, scrim }

/// Foreal buttons: ink pill (primary), white pill with soft shadow (light),
/// translucent dark pill over photos (scrim). Radius 10, height 53.
class PsButton extends StatelessWidget {
  const PsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PsButtonVariant.primary,
    this.trailing,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed; // null = disabled
  final PsButtonVariant variant;
  final IconData? trailing;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg) = switch (variant) {
      PsButtonVariant.primary => (AppColors.ink, AppColors.onDark),
      PsButtonVariant.light => (AppColors.surface, AppColors.ink),
      PsButtonVariant.scrim => (AppColors.scrim, AppColors.onDark),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.button),
            boxShadow: variant == PsButtonVariant.light ? AppColors.cardShadow : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.button),
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: 53,
                  minWidth: expand ? double.infinity : 0,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                        )
                      else ...[
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: AppText.button.copyWith(color: fg),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          Icon(trailing, size: 18, color: fg),
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
