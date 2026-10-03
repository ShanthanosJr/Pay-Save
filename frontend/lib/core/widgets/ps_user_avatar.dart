import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../social/social_providers.dart';
import '../theme/app_colors.dart';
import 'ps_icon_badge.dart';

/// A member's profile photo, falling back to initials while loading, on
/// error, or when they have none.
class PsUserAvatar extends ConsumerWidget {
  const PsUserAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.size = 44,
    this.ring = false,
    this.tone,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final bool ring;
  final Color? tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = PsAvatar(name: name, size: size, ring: ring, tone: tone);
    final url = avatarUrl;
    if (url == null) return fallback;
    final bytes = ref.watch(avatarBytesProvider(url)).value;
    if (bytes == null) return fallback;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: ring ? Border.all(color: AppColors.surface, width: size * 0.06) : null,
          boxShadow: ring ? AppColors.cardShadow : null,
          image: DecorationImage(
            image: ResizeImage(
              MemoryImage(bytes),
              width: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              policy: ResizeImagePolicy.fit,
            ),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
