import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Inter Tight for headings, Inter for body, Instrument Serif italic for
/// accent words — as measured on the Foreal template. None carry Sinhala or
/// Tamil glyphs, so every style falls back to the bundled Noto fonts.
const _fallback = ['Noto Sans Sinhala', 'Noto Sans Tamil'];

TextStyle _s(
  String family,
  double size,
  int weight, {
  Color color = AppColors.ink,
  double tracking = -0.04,
  double height = 1.1,
  FontStyle style = FontStyle.normal,
}) =>
    TextStyle(
      fontFamily: family,
      fontFamilyFallback: _fallback,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation.weight(weight.toDouble())],
      fontStyle: style,
      color: color,
      letterSpacing: size * tracking,
      height: height,
    );

abstract final class AppText {
  static final display = _s('Inter Tight', 42, 400, height: 1.0);
  static final displayAccent =
      _s('Instrument Serif', 42, 400, style: FontStyle.italic, height: 1.0);
  static final headline = _s('Inter Tight', 30, 400, height: 1.05);
  static final headlineAccent =
      _s('Instrument Serif', 30, 400, style: FontStyle.italic, height: 1.05);
  static final title = _s('Inter Tight', 18, 500, height: 1.2);
  static final button = _s('Inter Tight', 16, 500, tracking: -0.02, height: 1.25);
  static final body = _s('Inter', 16, 400, color: AppColors.inkMuted, height: 1.45);
  static final bodyStrong = _s('Inter', 16, 500, height: 1.4);
  static final small = _s('Inter', 14, 400, color: AppColors.inkMuted, height: 1.4);
  static final label = _s('Inter', 14, 600, tracking: -0.02, height: 1.2);
  static final caption = _s('Inter', 12, 500, color: AppColors.inkMuted, tracking: -0.02);
  static final amount = _s('Inter Tight', 22, 500, height: 1.1);

  static TextTheme get textTheme => TextTheme(
        displaySmall: display,
        headlineSmall: headline,
        titleLarge: title,
        titleMedium: bodyStrong,
        bodyLarge: body,
        bodyMedium: small,
        labelLarge: button,
        bodySmall: caption,
      );
}
