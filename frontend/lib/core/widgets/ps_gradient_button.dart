import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Primary action: the green gradient pill from the reference ("Get Started").
class PsGradientButton extends StatelessWidget {
  const PsGradientButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed; // null = disabled (e.g. Pay now after recording, U-01)

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.button),
              onTap: onPressed,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: Center(child: Text(label, style: AppText.button)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
