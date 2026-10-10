import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_logo.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../core/notifications/notifications.dart';

/// Forest header for signed-in screens: logo, notifications, profile.
class BrandHeader extends ConsumerWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthLoggedIn ? auth.user : null;
    final unread = ref.watch(inboxProvider).value?.unread ?? 0;

    return Row(
      children: [
        PsLogo(size: 30, wordmark: l10n.wordmark),
        const Spacer(),
        PsGlassIconButton(
          icon: Icons.notifications_rounded,
          label: l10n.notificationsLabel,
          badge: unread == 0 ? null : (unread > 99 ? '99+' : '$unread'),
          onTap: () => context.push('/notifications'),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: l10n.openProfile,
          excludeSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go('/profile'),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: AppColors.glassStrong, shape: BoxShape.circle),
              child: PsUserAvatar(name: user?.fullName ?? '', avatarUrl: user?.avatarUrl, size: 44),
            ),
          ),
        ),
      ],
    );
  }
}
