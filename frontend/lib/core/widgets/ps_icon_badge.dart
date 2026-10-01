import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PsBadgeTone { forest, mint, danger, info, warning, neutral }

/// Round icon badge (the green dot icons beside list rows and stat tiles).
class PsIconBadge extends StatelessWidget {
  const PsIconBadge({super.key, required this.icon, this.tone = PsBadgeTone.forest, this.size = 40});

  final IconData icon;
  final PsBadgeTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      PsBadgeTone.forest => (AppColors.forest700, AppColors.onForest),
      PsBadgeTone.mint => (AppColors.mintSoft, AppColors.forest700),
      PsBadgeTone.danger => (AppColors.danger, AppColors.onForest),
      PsBadgeTone.info => (AppColors.info, AppColors.onForest),
      PsBadgeTone.warning => (AppColors.warningSoft, AppColors.warning),
      PsBadgeTone.neutral => (AppColors.canvas, AppColors.inkMuted),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.52, color: fg),
      ),
    );
  }
}

/// Initials avatar with a soft ring.
class PsAvatar extends StatelessWidget {
  const PsAvatar({super.key, required this.name, this.size = 44, this.ring = false, this.tone});

  final String name;
  final double size;
  final bool ring;
  final Color? tone;

  static const _tones = [
    Color(0xFFDDEBDF),
    Color(0xFFE8E2D6),
    Color(0xFFDCE6EF),
    Color(0xFFEBDDE0),
    Color(0xFFE4E1EE),
  ];

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = tone ?? _tones[name.hashCode.abs() % _tones.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: ring ? Border.all(color: AppColors.surface, width: size * 0.06) : null,
          boxShadow: ring ? AppColors.cardShadow : null,
        ),
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
            color: AppColors.forest800,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}
