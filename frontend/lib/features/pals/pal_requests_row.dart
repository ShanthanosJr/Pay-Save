import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../l10n/gen/app_localizations.dart';

/// "Pal requests" entry with the waiting count (icon + number + words).
class PalRequestsRow extends ConsumerWidget {
  const PalRequestsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final waiting = ref.watch(palRequestCountProvider);
    return PsListRow(
      icon: Icons.group_add_rounded,
      tone: waiting > 0 ? PsBadgeTone.forest : PsBadgeTone.mint,
      title: l10n.palRequestsTitle,
      subtitle: waiting > 0 ? l10n.palRequestsWaiting(waiting) : l10n.palRequestsSubtitle,
      showChevron: true,
      trailing: waiting > 0
          ? ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minWidth: 26),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: Text(
                  waiting > 99 ? '99+' : '$waiting',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.onForest, fontWeight: FontWeight.w700),
                ),
              ),
            )
          : null,
      onTap: () => context.push('/pals/requests'),
    );
  }
}
