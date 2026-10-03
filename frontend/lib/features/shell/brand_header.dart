import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_logo.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../l10n/gen/app_localizations.dart';
import '../circle/sample_circle.dart';

/// Forest header for signed-in screens: logo, notifications, profile.
class BrandHeader extends ConsumerWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthLoggedIn ? auth.user : null;

    return Row(
      children: [
        PsLogo(size: 30, wordmark: l10n.wordmark),
        const Spacer(),
        PsGlassIconButton(
          icon: Icons.notifications_rounded,
          label: l10n.notificationsLabel,
          badge: '2',
          onTap: () => showNotificationsSheet(context),
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

void showNotificationsSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final date = DateFormat.MMMd(l10n.localeName).format(SampleCircle.dueDate);
  showPsSheet<void>(
    context: context,
    title: l10n.notificationsLabel,
    builder: (ctx) => Column(children: [
      PsListRow(
        icon: Icons.priority_high_rounded,
        tone: PsBadgeTone.danger,
        title: l10n.contributionDueTitle,
        subtitle: '${l10n.cycleOf(SampleCircle.currentCycle, SampleCircle.totalCycles)} · '
            '${l10n.dueInDays(date, SampleCircle.daysLeft)}',
        trailing: Semantics(
          label: l10n.unreadLabel,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
          ),
        ),
      ),
      PsListRow(
        icon: Icons.check_rounded,
        title: l10n.heroCardTitle,
        subtitle: l10n.notifVerifiedBody('PS-1038', 3),
        trailing: Semantics(
          label: l10n.unreadLabel,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
          ),
        ),
      ),
      PsListRow(
        icon: Icons.swap_vert_rounded,
        tone: PsBadgeTone.mint,
        title: l10n.notifTurnTitle,
        subtitle: l10n.receivesInCycle(SampleCircle.myTurn),
      ),
    ]),
  );
}
