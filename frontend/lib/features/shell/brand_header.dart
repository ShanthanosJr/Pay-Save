import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_logo.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/theme/app_typography.dart';

/// Forest header for signed-in screens: logo, notifications, profile.
class BrandHeader extends ConsumerWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final name = auth is AuthLoggedIn ? auth.user.fullName : '';

    return Row(
      children: [
        PsLogo(size: 30, wordmark: l10n.wordmark),
        const Spacer(),
        PsGlassIconButton(
          icon: Icons.notifications_rounded,
          label: l10n.notificationsLabel,
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
              child: PsAvatar(name: name, size: 44),
            ),
          ),
        ),
      ],
    );
  }
}

void showNotificationsSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showPsSheet<void>(
    context: context,
    title: l10n.notificationsLabel,
    subtitle: l10n.recentActivity,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final circle = ref.watch(activeCircleProvider).value;
      if (circle == null) return Text(l10n.noActivity, style: AppText.body);
      final entries = ref.watch(ledgerProvider((circleId: circle.id, all: false))).value ?? const <LedgerEntry>[];
      final recent = entries.where((e) => e.type != LedgerType.memberAdded).take(6).toList();
      if (recent.isEmpty) return Text(l10n.noActivity, style: AppText.body);
      return Column(children: [
        for (final e in recent)
          PsListRow(
            icon: switch (e.type) {
              LedgerType.contributionVerified => Icons.verified_rounded,
              LedgerType.correction => Icons.undo_rounded,
              LedgerType.payout => Icons.south_west_rounded,
              LedgerType.cycleClosed => Icons.lock_rounded,
              LedgerType.turnOrderSet => Icons.format_list_numbered_rounded,
              _ => Icons.receipt_long_rounded,
            },
            tone: e.type == LedgerType.correction ? PsBadgeTone.warning : PsBadgeTone.forest,
            title: switch (e.type) {
              LedgerType.contributionVerified => l10n.heroCardTitle,
              LedgerType.correction => l10n.entryCorrection,
              LedgerType.payout => l10n.entryPayout(e.cycleNumber ?? 0),
              LedgerType.cycleClosed => l10n.entryCycleClosed(e.cycleNumber ?? 0),
              LedgerType.turnOrderSet => l10n.entryTurnOrder,
              _ => l10n.entryContribution(e.cycleNumber ?? 0),
            },
            subtitle: '${e.reference} · ${dateTime(l10n, e.createdAt)}',
          ),
      ]);
    }),
  );
}
