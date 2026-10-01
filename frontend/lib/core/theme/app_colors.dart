import 'package:flutter/material.dart';

/// Pay&Save "Forest" palette. Never hard-code a Color in a widget; use these.
abstract final class AppColors {
  // Forest header and brand
  static const forest900 = Color(0xFF14301F);
  static const forest800 = Color(0xFF1C3F2A);
  static const forest700 = Color(0xFF2A5A3C);
  static const forest600 = Color(0xFF3B6846);
  static const forest500 = Color(0xFF4B8657);
  static const mint = Color(0xFFD3E7D7);
  static const mintSoft = Color(0xFFEAF4EC);

  // Light sheet
  static const canvas = Color(0xFFF3F5F4);
  static const surface = Color(0xFFFFFFFF);
  static const stroke = Color(0xFFE5E9E6);
  static const strokeStrong = Color(0xFFD2D8D4);

  // Text
  static const ink = Color(0xFF121517);
  static const inkMuted = Color(0xFF55605A);
  static const inkSubtle = Color(0xFF6E7872);
  static const onForest = Color(0xFFFFFFFF);
  static const onForestMuted = Color(0xCCFFFFFF);
  static const glass = Color(0x29FFFFFF);
  static const glassStrong = Color(0x40FFFFFF);
  static const scrim = Color(0x80121517);

  // Status (always paired with an icon and a word)
  static const success = Color(0xFF1E7A55);
  static const successSoft = Color(0xFFE3F2EA);
  static const info = Color(0xFF1466D2);
  static const infoSoft = Color(0xFFE6EFFB);
  static const warning = Color(0xFF9A5B00);
  static const warningSoft = Color(0xFFFBF0DC);
  static const danger = Color(0xFFD9352A);
  static const dangerSoft = Color(0xFFFCE9E7);

  static const headerGradient = LinearGradient(
    colors: [forest800, forest600, forest500],
    stops: [0, 0.55, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const photoFade = LinearGradient(
    colors: [Color(0x2614301F), Color(0x0014301F), Color(0x9914301F), forest900],
    stops: [0.0, 0.22, 0.7, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const cardShadow = [
    BoxShadow(color: Color(0x0F14301F), offset: Offset(0, 8), blurRadius: 24),
  ];

  static const floatShadow = [
    BoxShadow(color: Color(0x2914301F), offset: Offset(0, 18), blurRadius: 40),
  ];
}

abstract final class AppRadii {
  static const sheet = 32.0;
  static const card = 22.0;
  static const field = 16.0;
  static const small = 12.0;
  static const pill = 999.0;
}

abstract final class AppSpace {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
  static const screen = 20.0;
  static const minTouch = 48.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
}
