import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Pay&Save ships dark-only, matching the reference design.
abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.green,
      onPrimary: AppColors.textPrimary,
      secondary: AppColors.greenBright,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.statusDue,
      outline: AppColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: AppText.textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerColor: AppColors.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.section,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.searchFill,
        hintStyle: AppText.body.copyWith(color: AppColors.searchText),
        prefixIconColor: AppColors.searchText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.search)),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bg,
        selectedColor: AppColors.green,
        labelStyle: AppText.section.copyWith(color: AppColors.textTertiary),
        secondaryLabelStyle: AppText.section,
        side: BorderSide.none,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.chip)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.green, width: 1.5),
          textStyle: AppText.button,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bg,
        indicatorColor: AppColors.green.withValues(alpha: 0.25),
        height: 68,
        // Labels always shown: icon-only nav fails NFR-06.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppText.caption.copyWith(
            color: s.contains(WidgetState.selected)
                ? AppColors.textPrimary
                : AppColors.textTertiary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? AppColors.textPrimary
                : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
