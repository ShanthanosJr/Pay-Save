import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/format/status_label.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_arithmetic_row.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';
import '../circle/record_payment_sheet.dart';
import '../shell/async_states.dart';
import '../shell/brand_header.dart';
import '../shell/circle_switcher.dart';

/// Member dashboard on live data. Status always comes from the server's
/// `v_cycle_member_status`, never from local arithmetic.
class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final firstName = auth is AuthLoggedIn ? auth.user.firstName : '';
    final active = ref.watch(activeCircleProvider);

    return PsForestPage(
      header: const BrandHeader(),
      children: [
        Text(l10n.greeting(firstName), style: AppText.display),
        const SizedBox(height: AppSpace.xs),
        ...active.when(
          loading: () => const [SheetLoading()],
          error: (e, _) => [SheetError(error: e, onRetry: () => ref.invalidate(myCirclesProvider))],
          data: (circle) => circle == null
              ? [
                  const SizedBox(height: AppSpace.l),
                  EmptyState(
                    icon: Icons.diversity_3_rounded,
                    title: l10n.noCirclesTitle,
                    body: l10n.noCirclesBody,
                    actions: [
                      PsButton(label: l10n.createCircle, icon: Icons.add_rounded, onPressed: () => context.push('/circles/new')),
                      PsButton(
                        label: l10n.joinCircle,
                        icon: Icons.qr_code_rounded,
                        variant: PsButtonVariant.secondary,
                        onPressed: () => context.push('/circles/join'),
                      ),
                    ],
                  ),
                ]
              : [
                  Align(alignment: AlignmentDirectional.centerStart, child: CircleSwitcherChip(circle: circle)),
                  const SizedBox(height: AppSpace.l),
                  _CircleHome(circle: circle),
                ],
        ),
      ],
    );
  }
}

class _CircleHome extends ConsumerWidget {
  const _CircleHome({required this.circle});

  final CircleSummary circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(circleDetailProvider(circle.id));
    return detail.when(
      loading: () => const SheetLoading(),
      error: (e, _) => SheetError(error: e, onRetry: () => ref.invalidate(circleDetailProvider(circle.id))),
      data: (d) => switch (d.summary.status) {
        CircleStatus.draft => _DraftHome(detail: d),
        CircleStatus.active => _ActiveHome(detail: d),
        CircleStatus.completed => _CompletedHome(detail: d),
      },
    );
  }
}

class _DraftHome extends StatelessWidget {
  const _DraftHome({required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = detail.summary;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PsCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const PsIconBadge(icon: Icons.hourglass_top_rounded, tone: PsBadgeTone.warning),
            const SizedBox(width: 14),
            Expanded(child: Text(l10n.draftTitle, style: AppText.section)),
          ]),
          const SizedBox(height: AppSpace.m),
          Text(
            s.isOrganizer
                ? l10n.draftBodyOrganizer(detail.members.length, s.plannedCycles)
                : l10n.draftBodyMember(detail.members.length, s.plannedCycles),
            style: AppText.body,
          ),
          const SizedBox(height: AppSpace.l),
          _MembersStrip(members: detail.members, planned: s.plannedCycles),
        ]),
      ),
      if (s.joinCode != null) ...[
        const SizedBox(height: AppSpace.m),
        JoinCodeCard(code: s.joinCode!),
      ],
      if (s.isOrganizer) ...[
        const SizedBox(height: AppSpace.xl),
        PsButton(
          label: l10n.turnOrderSetupTitle,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () => context.go('/circle'),
        ),
      ],
    ]);
  }
}

class _MembersStrip extends StatelessWidget {
  const _MembersStrip({required this.members, required this.planned});

  final List<CircleMember> members;
  final int planned;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final m in members) Tooltip(message: m.displayName, child: PsAvatar(name: m.displayName, size: 40)),
      for (var i = members.length; i < planned; i++)
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.strokeStrong, width: 1.5),
          ),
          child: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.inkSubtle),
        ),
    ]);
  }
}

/// Big, copyable join code (the circle's invitation).
class JoinCodeCard extends StatelessWidget {
  const JoinCodeCard({super.key, required this.code});

  final String code;

  String get pretty => code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.joinCodeLabel.toUpperCase(),
                style: AppText.caption.copyWith(color: AppColors.mint, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Semantics(
              label: code.split('').join(' '),
              excludeSemantics: true,
              child: Text(pretty, style: AppText.figure.copyWith(color: AppColors.onForest, letterSpacing: 2)),
            ),
            const SizedBox(height: 6),
            Text(l10n.shareCodeHint, style: AppText.footnote.copyWith(color: AppColors.onForestMuted)),
          ]),
        ),
        PsGlassIconButton(
          icon: Icons.copy_rounded,
          label: l10n.copyCode,
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.codeCopied)));
          },
        ),
      ]),
    );
  }
}

class _ActiveHome extends ConsumerWidget {
  const _ActiveHome({required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = detail.summary;
    final cycle = s.currentCycle;
    final current = detail.current;
    if (cycle == null || current == null) return _CompletedHome(detail: detail);

    final status = cycle.myStatus;
    final unit = s.contributionMinor;
    final days = daysUntil(cycle.dueDate);
    final dueText = l10n.dueInDays(shortDate(l10n, cycle.dueDate), days < 0 ? 0 : days);
    final recipient = cycle.recipient;
    final mine = ref.watch(ledgerProvider((circleId: s.id, all: false))).value ?? const <LedgerEntry>[];
    final myVerified = mine.where((e) => e.type == LedgerType.contributionRecorded && e.status == 'verified').toList();
    final queue = s.isOrganizer ? ref.watch(verifyQueueProvider(s.id)).value ?? const <VerifyItem>[] : const <VerifyItem>[];
    final totals = current.totals;

    final (String title, String body, Widget action) = switch (status) {
      ContributionStatus.due || ContributionStatus.overdue => (
          l10n.contributionDueTitle,
          '${l10n.cycleOf(cycle.number, s.plannedCycles)} · ${formatLkr(unit)}',
          PsButton(
            label: l10n.payNow,
            icon: Icons.arrow_outward_rounded,
            onPressed: () => showRecordPaymentSheet(
              context,
              circle: s,
              cycleNumber: cycle.number,
              payeeName: recipient?.isYou == true ? l10n.youLabel : recipient?.displayName,
            ),
          ),
        ),
      ContributionStatus.recorded || ContributionStatus.pendingSync => (
          l10n.statusAwaiting,
          l10n.recordedBody(cycle.myContribution?.reference ?? '', shortDate(l10n, cycle.myContribution?.recordedAt ?? DateTime.now())),
          PsButton(label: l10n.viewRecord, variant: PsButtonVariant.secondary, onPressed: () => context.go('/history')),
        ),
      ContributionStatus.verified => (
          l10n.heroCardTitle,
          l10n.verifiedBody(
            cycle.myContribution?.reference ?? '',
            shortDate(l10n, cycle.myContribution?.verifiedAt ?? DateTime.now()),
          ),
          PsButton(label: l10n.viewRecord, variant: PsButtonVariant.secondary, onPressed: () => context.go('/history')),
        ),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PsSectionHeader(title: l10n.thisCycle),
      _AttentionCard(
        title: title,
        body: body,
        meta: recipient == null ? dueText : '$dueText · ${l10n.payeeLine(recipient.isYou ? l10n.youLabel : recipient.displayName)}',
        status: status,
        statusLabel: statusLabel(l10n, status),
        action: action,
      ),
      if (queue.isNotEmpty) ...[
        const SizedBox(height: AppSpace.m),
        PsListRow(
          icon: Icons.fact_check_rounded,
          tone: PsBadgeTone.info,
          title: l10n.toVerifyTitle,
          subtitle: l10n.toVerifyBody(queue.length),
          showChevron: true,
          onTap: () => context.push('/circles/${s.id}/verify'),
        ),
      ],
      const SizedBox(height: AppSpace.xxxl),
      PsSectionHeader(title: l10n.dashboardTitle),
      Row(children: [
        Expanded(
          child: _StatTile(
            label: l10n.mySavingsTile,
            value: formatLkr(myVerified.length * unit),
            caption: l10n.verifiedCount(myVerified.length),
            badge: const PsIconBadge(icon: Icons.savings_rounded, size: 36),
          ),
        ),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: _StatTile(
            label: l10n.thisCycle,
            value: statusLabel(l10n, status),
            valueColor: status == ContributionStatus.overdue ? AppColors.danger : null,
            caption: dueText,
            badge: PsIconBadge(
              icon: PsStatusBadge.styleFor(status).$1,
              tone: switch (status) {
                ContributionStatus.verified => PsBadgeTone.forest,
                ContributionStatus.overdue => PsBadgeTone.danger,
                ContributionStatus.recorded => PsBadgeTone.info,
                _ => PsBadgeTone.warning,
              },
              size: 36,
            ),
          ),
        ),
      ]),
      const SizedBox(height: AppSpace.m),
      PsCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(l10n.collectionTitle, style: AppText.callout.copyWith(color: AppColors.inkMuted))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadii.pill)),
              child: Text(l10n.cycleLabel(cycle.number), style: AppText.label),
            ),
          ]),
          const SizedBox(height: AppSpace.l),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatLkr(totals.verified.totalMinor), style: AppText.figure),
          ),
          const SizedBox(height: 6),
          Text(l10n.collectionOf(formatMinor(totals.expectedMinor)), style: AppText.footnote),
          const SizedBox(height: AppSpace.l),
          _CollectionBar(totals: totals),
          const SizedBox(height: AppSpace.l),
          PsArithmeticRow(
            summary: l10n.arithmeticSummary(
              totals.verified.count,
              l10n.statusVerified.toLowerCase(),
              formatMinor(totals.verified.unitMinor),
              formatMinor(totals.verified.totalMinor),
            ),
          ),
        ]),
      ),
      const SizedBox(height: AppSpace.xxxl),
      PsSectionHeader(
        title: l10n.turnOrderTitle,
        trailing: PsPillLink(label: l10n.seeMore, onTap: () => context.go('/circle')),
      ),
      for (final m in (detail.members.where((m) => (m.payoutPosition ?? 0) >= cycle.number).toList()
            ..sort((a, b) => a.payoutPosition!.compareTo(b.payoutPosition!)))
          .take(3))
        PsListRow(
          leading: PsAvatar(name: m.displayName, size: 42),
          title: m.isYou ? l10n.youLabel : m.displayName,
          subtitle: l10n.receivesInCycle(m.payoutPosition!),
          trailing: m.payoutPosition == cycle.number
              ? PsStatusPill(label: l10n.turnCurrent, tone: PsPillTone.success, icon: Icons.south_west_rounded)
              : m.payoutPosition == cycle.number + 1
                  ? PsStatusPill(label: l10n.turnNext, tone: PsPillTone.info, filled: false)
                  : null,
        ),
    ]);
  }
}

class _CompletedHome extends ConsumerWidget {
  const _CompletedHome({required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.emoji_events_rounded,
      title: l10n.completedTitle,
      body: l10n.completedBody,
      actions: [
        PsButton(label: l10n.navHistory, variant: PsButtonVariant.secondary, onPressed: () => context.go('/history')),
      ],
    );
  }
}

/// Verified / awaiting / unpaid as one segmented bar with a legend.
class _CollectionBar extends StatelessWidget {
  const _CollectionBar({required this.totals});

  final CycleTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final due = totals.membersDue == 0 ? 1 : totals.membersDue;
    final parts = [
      (totals.verified.count, AppColors.forest600, l10n.statusVerified),
      (totals.awaiting.count, AppColors.info, l10n.statusAwaiting),
      (totals.unpaidCount, AppColors.mint, l10n.legendUnpaid),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: SizedBox(
          height: 14,
          child: Row(children: [
            for (final (n, color, _) in parts)
              if (n > 0)
                Expanded(
                  flex: n * 1000 ~/ due,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: AppMotion.curve,
                    builder: (context, t, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(widthFactor: t, child: ColoredBox(color: color, child: const SizedBox.expand())),
                    ),
                  ),
                ),
          ]),
        ),
      ),
      const SizedBox(height: AppSpace.m),
      Wrap(spacing: 14, runSpacing: 6, children: [
        for (final (n, color, label) in parts)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(child: Text('$label · $n', style: AppText.caption)),
          ]),
      ]),
    ]);
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.title,
    required this.body,
    required this.meta,
    required this.status,
    required this.statusLabel,
    required this.action,
  });

  final String title;
  final String body;
  final String meta;
  final ContributionStatus status;
  final String statusLabel;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final urgent = status == ContributionStatus.due || status == ContributionStatus.overdue;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.stroke),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PsIconBadge(
              icon: urgent ? Icons.priority_high_rounded : PsStatusBadge.styleFor(status).$1,
              tone: urgent
                  ? PsBadgeTone.danger
                  : status == ContributionStatus.verified
                      ? PsBadgeTone.forest
                      : PsBadgeTone.info,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.section.copyWith(fontSize: 19)),
                const SizedBox(height: 4),
                Text(body, style: AppText.body.copyWith(color: AppColors.ink)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  PsStatusBadge(status: status, label: statusLabel, filled: !urgent || status == ContributionStatus.overdue),
                  Text(meta, style: AppText.footnote),
                ]),
              ]),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadii.card)),
          ),
          child: action,
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.badge, this.caption, this.valueColor});

  final String label;
  final String value;
  final Widget badge;
  final String? caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: AppText.footnote)),
          badge,
        ]),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.figureSmall.copyWith(color: valueColor)),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(caption!, style: AppText.caption, maxLines: 2),
        ],
      ]),
    );
  }
}
