import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Inter for UI text, Inter Tight for large figures. Neither carries Sinhala
/// or Tamil glyphs, so every style falls back to the bundled Noto fonts.
const _fallback = ['Noto Sans Sinhala', 'Noto Sans Tamil'];

TextStyle _s(
  double size,
  int weight, {
  String family = 'Inter',
  Color color = AppColors.ink,
  double tracking = -0.02,
  double height = 1.25,
}) =>
    TextStyle(
      fontFamily: family,
      fontFamilyFallback: _fallback,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation.weight(weight.toDouble())],
      color: color,
      letterSpacing: size * tracking,
      height: height,
    );

abstract final class AppText {
  static final hero = _s(40, 700, family: 'Inter Tight', color: AppColors.onForest, tracking: -0.035, height: 1.04);
  static final display = _s(30, 700, tracking: -0.03, height: 1.12);
  static final title = _s(24, 700, tracking: -0.025, height: 1.18);
  static final section = _s(20, 700, tracking: -0.02, height: 1.2);
  static final headline = _s(17, 600, tracking: -0.015, height: 1.3);
  static final body = _s(16, 400, color: AppColors.inkMuted, tracking: -0.01, height: 1.45);
  static final bodyStrong = _s(16, 500, tracking: -0.01, height: 1.4);
  static final callout = _s(15, 500, tracking: -0.01, height: 1.35);
  static final footnote = _s(14, 400, color: AppColors.inkMuted, tracking: -0.005, height: 1.4);
  static final label = _s(14, 600, tracking: -0.005, height: 1.25);
  static final caption = _s(12, 500, color: AppColors.inkSubtle, tracking: 0, height: 1.3);
  static final button = _s(16, 600, tracking: -0.01, height: 1.2);
  static final figure = _s(36, 700, family: 'Inter Tight', tracking: -0.03, height: 1.0);
  static final figureSmall = _s(20, 700, family: 'Inter Tight', tracking: -0.02, height: 1.1);
  static final brand = _s(19, 600, color: AppColors.onForest, tracking: -0.02, height: 1.1);

  static TextTheme get textTheme => TextTheme(
        displaySmall: display,
        headlineSmall: title,
        titleLarge: section,
        titleMedium: headline,
        bodyLarge: body,
        bodyMedium: footnote,
        labelLarge: button,
        bodySmall: caption,
      );
}
