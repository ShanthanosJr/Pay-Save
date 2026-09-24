import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Light, airy theme matching the Foreal template.
abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.onDark,
      secondary: AppColors.terracotta,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.statusDue,
      outline: AppColors.border,
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: AppText.textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerColor: AppColors.hairline,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.title,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppText.small.copyWith(color: AppColors.placeholder),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(AppColors.hairline),
        enabledBorder: border(AppColors.hairline),
        focusedBorder: border(AppColors.ink, 1.5),
        errorBorder: border(AppColors.statusDue),
        focusedErrorBorder: border(AppColors.statusDue, 1.5),
        errorStyle: AppText.caption.copyWith(color: AppColors.statusDue),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.ink,
        height: 72,
        // Labels always shown: icon-only nav fails low-digital-confidence users.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppText.caption.copyWith(
            color: s.contains(WidgetState.selected) ? AppColors.ink : AppColors.inkMuted,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? AppColors.onDark : AppColors.inkMuted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.small.copyWith(color: AppColors.onDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
      ),
    );
  }
}
