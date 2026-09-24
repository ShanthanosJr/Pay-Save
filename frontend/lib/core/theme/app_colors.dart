import 'package:flutter/material.dart';

/// Pay&Save colour tokens, measured from the Foreal Framer template.
/// Never hard-code a Color in a widget; use these.
abstract final class AppColors {
  static const bg = Color(0xFFF8F8F8);
  static const surface = Color(0xFFFFFFFF);

  static const ink = Color(0xFF16232B);
  static const inkMuted = Color(0xFF4F5F69);
  static const placeholder = Color(0x8A041319);
  static const hairline = Color(0xFFE4E4E4);
  static const border = Color(0xFFC7C7C7);

  static const cream = Color(0xFFFFEBC6);
  static const terracotta = Color(0xFF7E4B3A);

  static const onDark = Color(0xFFFFFFFF);
  static const onDarkMuted = Color(0xB3FFFFFF);
  static const scrim = Color(0xCC222222);

  static const statusVerified = Color(0xFF1F7A4D);
  static const statusPending = Color(0xFF9A5B00);
  static const statusDue = Color(0xFFC0392B);

  static const cardShadow = [
    BoxShadow(color: Color(0x1F15222B), offset: Offset(0, 10), blurRadius: 20),
  ];
}

abstract final class AppRadii {
  static const button = 10.0;
  static const chip = 10.0;
  static const card = 14.0;
  static const cardLarge = 20.0;
  static const field = 10.0;
}

abstract final class AppSpace {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
  static const screen = 20.0;
  static const minTouch = 48.0;
}
