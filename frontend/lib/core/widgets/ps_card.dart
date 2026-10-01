import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// White card with a hairline and a whisper of shadow.
class PsCard extends StatelessWidget {
  const PsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = AppRadii.card,
    this.color = AppColors.surface,
    this.dashed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppColors.stroke),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: AppColors.cardShadow),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
