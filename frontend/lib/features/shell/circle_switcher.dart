import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../l10n/gen/app_localizations.dart';

/// Pill showing the focused circle; tapping opens the switcher.
class CircleSwitcherChip extends ConsumerWidget {
  const CircleSwitcherChip({super.key, required this.circle});

  final CircleSummary circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${l10n.switchCircle}: ${circle.name}',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => showCircleSwitcher(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const PsIconBadge(icon: Icons.groups_rounded, tone: PsBadgeTone.mint, size: 30),
            const SizedBox(width: 8),
            Flexible(child: Text(circle.name, style: AppText.callout, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.expand_more_rounded, color: AppColors.inkMuted),
          ]),
        ),
      ),
    );
  }
}

void showCircleSwitcher(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showPsSheet<void>(
    context: context,
    title: l10n.myCircles,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final circles = ref.watch(myCirclesProvider).value ?? const <CircleSummary>[];
      final active = ref.watch(activeCircleProvider).value;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final c in circles)
          Semantics(
            selected: c.id == active?.id,
            child: PsListRow(
              icon: Icons.groups_rounded,
              tone: c.id == active?.id ? PsBadgeTone.forest : PsBadgeTone.mint,
              title: c.name,
              subtitle: '${formatLkr(c.contributionMinor)} · ${c.isOrganizer ? l10n.organizerLabel : l10n.circleMembers}',
              trailing: c.id == active?.id ? const Icon(Icons.check_circle_rounded, color: AppColors.forest600) : null,
              onTap: () {
                ref.read(selectedCircleIdProvider.notifier).select(c.id);
                Navigator.of(ctx).pop();
              },
            ),
          ),
        const SizedBox(height: AppSpace.s),
        PsButton(
          label: l10n.createCircle,
          icon: Icons.add_rounded,
          onPressed: () {
            Navigator.of(ctx).pop();
            context.push('/circles/new');
          },
        ),
        const SizedBox(height: AppSpace.m),
        PsButton(
          label: l10n.joinCircle,
          variant: PsButtonVariant.secondary,
          icon: Icons.qr_code_rounded,
          onPressed: () {
            Navigator.of(ctx).pop();
            context.push('/circles/join');
          },
        ),
      ]);
    }),
  );
}
