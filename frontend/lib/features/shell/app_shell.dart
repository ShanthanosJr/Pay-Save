import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/circles/circles_providers.dart';
import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/gen/app_localizations.dart';

/// Signed-in frame with a labelled bottom navigation (icon-only nav fails
/// users with low digital confidence).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unread = ref.watch(chatUnreadProvider);
    final requests = ref.watch(palRequestCountProvider);
    final total = unread + requests;
    final invites = ref.watch(myInvitationsProvider).value?.length ?? 0;
    Widget circlesIcon(IconData icon) => Badge(
          isLabelVisible: invites > 0,
          backgroundColor: AppColors.danger,
          textStyle: AppText.caption.copyWith(fontWeight: FontWeight.w700),
          label: Text('$invites', semanticsLabel: l10n.circleInvitationsTitle),
          child: Icon(icon),
        );
    Widget chatIcon(IconData icon) => Badge(
          isLabelVisible: total > 0,
          backgroundColor: AppColors.danger,
          textStyle: AppText.caption.copyWith(fontWeight: FontWeight.w700),
          label: Text(total > 99 ? '99+' : '$total', semanticsLabel: l10n.socialBadgeLabel(unread, requests)),
          child: Icon(icon),
        );
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: circlesIcon(Icons.groups_outlined),
              selectedIcon: circlesIcon(Icons.groups_rounded),
              label: l10n.navCircles,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: l10n.navHistory,
            ),
            NavigationDestination(
              icon: chatIcon(Icons.chat_bubble_outline_rounded),
              selectedIcon: chatIcon(Icons.chat_bubble_rounded),
              label: l10n.navChats,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
