import 'package:flutter/material.dart';

/// Pay&Save colour tokens. Source of truth: docs/design-system.md §1.
/// Never hard-code a Color in a widget; use these.
abstract final class AppColors {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF161616);
  static const surfaceRaised = Color(0xFF222222);
  static const searchFill = Color(0xFFD9D9D9);
  static const searchText = Color(0xFF7A7A7A);

  static const green = Color(0xFF1B6B3E);
  static const greenDeep = Color(0xFF0E4527);
  static const greenBright = Color(0xFF2FA360);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB8B8B8);
  static const textTertiary = Color(0xFF8C8C8C);
  static const divider = Color(0xFF2A2A2A);

  static const statusVerified = Color(0xFF2FA360);
  static const statusPending = Color(0xFFE3A33B);
  static const statusDue = Color(0xFFE5484D);

  static const primaryGradient = LinearGradient(
    colors: [green, greenDeep],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF1E1E1E), Color(0xFF2B2B2B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const photoOverlay = LinearGradient(
    colors: [Color(0x00000000), Color(0xFF000000)],
    stops: [0.35, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

abstract final class AppRadii {
  static const button = 16.0;
  static const hero = 20.0;
  static const tile = 18.0;
  static const search = 12.0;
  static const chip = 10.0;
  static const addButton = 8.0;
}

abstract final class AppSpace {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
  static const screen = 20.0;
  static const minTouch = 48.0; // NFR-06
}
