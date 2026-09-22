import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Montserrat for headings, Poppins for body (docs/design-system.md §2).
/// Both lack Sinhala/Tamil glyphs, so every style falls back to Noto.
/// Bundle the Noto fonts as assets in pubspec.yaml under these family names.
const _fallback = ['Noto Sans Sinhala', 'Noto Sans Tamil'];

TextStyle _m(double size, FontWeight w, {Color c = AppColors.textPrimary, double? ls}) =>
    GoogleFonts.montserrat(fontSize: size, fontWeight: w, color: c, letterSpacing: ls)
        .copyWith(fontFamilyFallback: _fallback, height: 1.25);

TextStyle _p(double size, FontWeight w, {Color c = AppColors.textSecondary}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c)
        .copyWith(fontFamilyFallback: _fallback, height: 1.45);

abstract final class AppText {
  static final wordmark = _m(34, FontWeight.w800, ls: 0.5);
  static final display = _m(28, FontWeight.w700);
  static final greeting = _m(22, FontWeight.w700);
  static final section = _m(16, FontWeight.w600);
  static final cardTitle = _m(17, FontWeight.w600);
  static final amount = _m(18, FontWeight.w700);
  static final button = _m(16, FontWeight.w700);
  static final body = _p(16, FontWeight.w300);
  static final bodyStrong = _p(16, FontWeight.w500, c: AppColors.textPrimary);
  static final caption = _p(12, FontWeight.w400, c: AppColors.textTertiary);

  static TextTheme get textTheme => TextTheme(
        displaySmall: display,
        headlineSmall: greeting,
        titleLarge: cardTitle,
        titleMedium: section,
        bodyLarge: body,
        bodyMedium: _p(14, FontWeight.w400),
        labelLarge: button,
        bodySmall: caption,
      );
}
