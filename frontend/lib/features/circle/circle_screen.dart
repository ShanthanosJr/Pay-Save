import 'package:flutter/material.dart';
import 'circle_tools.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/format/status_label.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';
import '../home/member_home_screen.dart' show JoinCodeCard;
import '../shell/async_states.dart';
import '../shell/brand_header.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../core/widgets/ps_skeleton.dart';
import 'circle_setup.dart';
import 'invitation_screen.dart' show InvitationsBanner;
import 'pay_to.dart';
import 'record_payment_sheet.dart';
import 'verify_actions.dart';

class CircleScreen extends ConsumerWidget {
  const CircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(activeCircleProvider);

    return PsForestPage(
      header: const BrandHeader(),
      children: active.when(
        loading: () => const [PsSkeletonDashboard(chip: false)],
        error: (e, _) => [SheetError(error: e, onRetry: () => ref.invalidate(myCirclesProvider))],
        data: (circle) {
          if (circle == null) {
            return [
              const InvitationsBanner(),
              EmptyState(
                icon: Icons.groups_rounded,
                title: l10n.noCirclesTitle,
                body: l10n.noCirclesBody,
                actions: [
                  PsButton(label: l10n.createCircle, icon: Icons.add_rounded, onPressed: () => context.push('/circles/new')),
                  PsButton(
                    label: l10n.joinCircle,
                    variant: PsButtonVariant.secondary,
                    onPressed: () => context.push('/circles/join'),
                  ),
                ],
              ),
            ];
          }
          final detail = ref.watch(circleDetailProvider(circle.id));
          return detail.when(
            loading: () => const [PsSkeletonDashboard(chip: false)],
            error: (e, _) => [SheetError(error: e, onRetry: () => ref.invalidate(circleDetailProvider(circle.id)))],
            data: (d) => [const InvitationsBanner(), _CircleBody(detail: d)],
          );
        },
      ),
    );
  }
}

class _CircleBody extends StatelessWidget {
  const _CircleBody({required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = detail.summary;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PsSectionHeader(
        title: s.name,
        large: true,
        trailing: Semantics(
          label: l10n.circleCodeLabel(s.publicCode),
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.pill)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.tag_rounded, size: 16, color: AppColors.onForest),
              const SizedBox(width: 4),
              Text(s.publicCode, style: AppText.label.copyWith(color: AppColors.onForest)),
            ]),
          ),
        ),
      ),
      PsCard(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: IntrinsicHeight(
          child: Row(children: [
            _Fact(label: l10n.contributionLabel, value: formatLkr(s.contributionMinor)),
            const VerticalDivider(color: AppColors.stroke, width: 1),
            _Fact(label: l10n.intervalLabel, value: intervalLabel(l10n, s.interval)),
            const VerticalDivider(color: AppColors.stroke, width: 1),
            _Fact(label: l10n.turnRuleLabel, value: turnRuleLabel(l10n, s.turnRule)),
          ]),
        ),
      ),
      const SizedBox(height: AppSpace.xxxl),
      switch (s.status) {
        CircleStatus.draft => _DraftSetup(detail: detail),
        _ => _LiveCircle(detail: detail),
      },
      CircleTools(detail: detail),
    ]);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 6),
            Text(value, style: AppText.headline.copyWith(fontSize: 15)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- draft

class _DraftSetup extends ConsumerStatefulWidget {
  const _DraftSetup({required this.detail});

  final CircleDetail detail;

  @override
  ConsumerState<_DraftSetup> createState() => _DraftSetupState();
}

class _DraftSetupState extends ConsumerState<_DraftSetup> {
  late List<String> _order = widget.detail.members.map((m) => m.userId).toList();
  bool _busy = false;
  String? _error;

  @override
  void didUpdateWidget(_DraftSetup old) {
    super.didUpdateWidget(old);
    final ids = widget.detail.members.map((m) => m.userId).toSet();
    // Keep the organizer's arrangement; append newcomers, drop leavers.
    _order = [..._order.where(ids.contains), ...ids.where((id) => !_order.contains(id))];
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _order.length) return;
    setState(() {
      final t = _order[i];
      _order[i] = _order[j];
      _order[j] = t;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      refreshCircle(ref, widget.detail.id);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirmStart() {
    final l10n = AppLocalizations.of(context);
    final s = widget.detail.summary;
    final lottery = s.turnRule == TurnRule.lottery;
    showPsSheet<void>(
      context: context,
      title: l10n.startConfirmTitle(s.name),
      subtitle: l10n.startConfirmBody,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PsButton(
          label: lottery ? l10n.revealAndStart : l10n.startCircle,
          icon: Icons.play_arrow_rounded,
          onPressed: () {
            Navigator.of(ctx).pop();
            _run(() => ref.read(circlesApiProvider).start(s.id, order: lottery ? null : _order));
          },
        ),
        const SizedBox(height: 12),
        PsButton(label: l10n.cancelLabel, variant: PsButtonVariant.secondary, onPressed: () => Navigator.of(ctx).pop()),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = widget.detail;
    final s = d.summary;
    final lottery = s.turnRule == TurnRule.lottery;
    final organizer = s.isOrganizer;
    final ordered = organizer && !lottery ? _order.map(d.memberById).whereType<CircleMember>().toList() : d.members;

    final setup = d.setup;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SetupChecklist(detail: d),
      const SizedBox(height: AppSpace.l),
      MyCirclePayoutCard(detail: d),
      if (organizer) ...[
        const SizedBox(height: AppSpace.l),
        InvitePalsButton(detail: d),
      ],
      const SizedBox(height: AppSpace.xxl),
      CollectionModeSelector(detail: d),
      const SizedBox(height: AppSpace.xxl),
      PsSectionHeader(title: organizer && !lottery ? l10n.turnOrderSetupTitle : l10n.circleMembers),
      Text(
        organizer ? l10n.draftBodyOrganizer(d.members.length, s.plannedCycles) : l10n.draftBodyMember(d.members.length, s.plannedCycles),
        style: AppText.footnote,
      ),
      const SizedBox(height: AppSpace.m),
      for (var i = 0; i < ordered.length; i++)
        PsListRow(
          leading: _MemberAvatar(member: ordered[i], position: organizer && !lottery ? i + 1 : null),
          title: ordered[i].isYou ? '${ordered[i].displayName} (${l10n.youLabel})' : ordered[i].displayName,
          subtitle: [
            if (ordered[i].role == CircleRole.organizer) l10n.organizerLabel,
            ordered[i].payoutReady ? l10n.payoutReadyWord : l10n.payoutMissingWord,
          ].join(' · '),
          trailing: organizer && !lottery
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: l10n.moveUp(ordered[i].displayName),
                    onPressed: i == 0 || _busy ? null : () => _move(i, -1),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  IconButton(
                    tooltip: l10n.moveDown(ordered[i].displayName),
                    onPressed: i == ordered.length - 1 || _busy ? null : () => _move(i, 1),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ])
              : null,
        ),
      if (organizer) PendingInvitations(detail: d),
      if (s.joinCode != null && organizer) ...[
        const SizedBox(height: AppSpace.l),
        JoinCodeCard(code: s.joinCode!),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s, left: 4),
          child: Text(l10n.joinCodePalsNote, style: AppText.caption),
        ),
      ],
      if (lottery && d.lottery.commitment != null) ...[
        const SizedBox(height: AppSpace.m),
        _FingerprintCard(label: l10n.lotteryFingerprint, value: d.lottery.commitment!, body: l10n.lotteryCommitBody),
      ],
      if (_error != null) ...[const SizedBox(height: AppSpace.l), ErrorBanner(_error!)],
      if (organizer) ...[
        const SizedBox(height: AppSpace.xl),
        if (lottery && d.lottery.commitment == null)
          PsButton(
            label: l10n.drawOrder,
            icon: Icons.casino_rounded,
            loading: _busy,
            onPressed: () => _run(() => ref.read(circlesApiProvider).commitLottery(s.id)),
          )
        else
          PsButton(
            label: lottery ? l10n.revealAndStart : l10n.startCircle,
            icon: Icons.play_arrow_rounded,
            loading: _busy,
            onPressed: setup.canStart ? _confirmStart : null,
          ),
        if (!setup.canStart) ...[
          const SizedBox(height: AppSpace.s),
          Text(
            d.members.length < 2 ? l10n.errNotEnoughMembers : l10n.errPayoutMissingStart,
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ]);
  }
}

/// Avatar with a tiny readiness mark; the turn number in fixed-order setup.
class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, this.position});

  final CircleMember member;
  final int? position;

  @override
  Widget build(BuildContext context) {
    final ok = member.payoutReady;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(clipBehavior: Clip.none, children: [
        if (position != null)
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.mintSoft, shape: BoxShape.circle),
            child: Text('$position', style: AppText.label.copyWith(color: AppColors.forest800)),
          )
        else
          PsUserAvatar(name: member.displayName, avatarUrl: member.avatarUrl, size: 42),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: ok ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: Icon(ok ? Icons.check_rounded : Icons.schedule_rounded, size: 11, color: AppColors.onForest),
          ),
        ),
      ]),
    );
  }
}

class _FingerprintCard extends StatelessWidget {
  const _FingerprintCard({required this.label, required this.value, this.body});

  final String label;
  final String value;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PsIconBadge(icon: Icons.fingerprint_rounded, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppText.headline)),
        ]),
        const SizedBox(height: AppSpace.m),
        SelectableText(
          value,
          style: AppText.caption.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 0.6,
            height: 1.5,
          ),
        ),
        if (body != null) ...[const SizedBox(height: AppSpace.m), Text(body!, style: AppText.footnote)],
      ]),
    );
  }
}

// ---------------------------------------------------------------- live

class _LiveCircle extends StatelessWidget {
  const _LiveCircle({required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = detail.summary;
    final current = detail.current;
    final statusById = {for (final m in current?.members ?? const <CycleMemberStatus>[]) m.userId: m};
    final members = [...detail.members]
      ..sort((a, b) => (a.payoutPosition ?? 999).compareTo(b.payoutPosition ?? 999));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (current != null) ...[
        PsListRow(
          icon: Icons.account_balance_wallet_rounded,
          title: l10n.whoToPay,
          subtitle: l10n.payToSubtitle(current.number, shortDate(l10n, current.dueDate)),
          showChevron: true,
          onTap: () => showPayToSheet(context, s.id),
        ),
        const SizedBox(height: AppSpace.xl),
      ],
      PsSectionHeader(title: l10n.circleMembers),
      if (current != null)
        Container(
          margin: const EdgeInsets.only(bottom: AppSpace.m),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(AppRadii.small)),
          child: Row(children: [
            const Icon(Icons.verified_rounded, size: 18, color: AppColors.forest700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l10n.cycleOf(current.number, s.plannedCycles)} · '
                '${l10n.membersVerifiedSummary(current.totals.verified.count, current.totals.membersDue)}',
                style: AppText.footnote.copyWith(color: AppColors.forest800),
              ),
            ),
          ]),
        ),
      for (final m in members)
        _MemberRow(detail: detail, member: m, status: statusById[m.userId]),
      if (s.isOrganizer && current != null) ...[
        const SizedBox(height: AppSpace.m),
        PsButton(
          label: l10n.closeCycle(current.number),
          variant: PsButtonVariant.secondary,
          icon: Icons.lock_clock_rounded,
          onPressed: () => showCloseCycleSheet(context, detail: detail),
        ),
      ],
      const SizedBox(height: AppSpace.xxxl),
      PsSectionHeader(title: l10n.cyclesTitle),
      for (final c in detail.cycles)
        PsListRow(
          leading: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.closed ? AppColors.mintSoft : (c.number == current?.number ? AppColors.forest700 : AppColors.canvas),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${c.number}',
              style: AppText.label.copyWith(
                color: c.number == current?.number && !c.closed ? AppColors.onForest : AppColors.forest800,
              ),
            ),
          ),
          title: () {
            final r = detail.memberById(c.recipientUserId ?? '');
            if (r == null) return '—';
            return r.isYou ? l10n.youLabel : r.displayName;
          }(),
          subtitle: longDate(l10n, c.dueDate),
          trailing: c.closed
              ? PsStatusPill(label: l10n.cycleClosed, tone: PsPillTone.success, icon: Icons.check_rounded)
              : c.number == current?.number
                  ? PsStatusPill(label: l10n.cycleCurrent, tone: PsPillTone.info, filled: false)
                  : PsStatusPill(label: l10n.cycleUpcoming, tone: PsPillTone.neutral, filled: false),
        ),
      if (detail.lottery.seed != null) ...[
        const SizedBox(height: AppSpace.l),
        _FingerprintCard(label: l10n.lotteryFingerprint, value: detail.lottery.commitment ?? ''),
        const SizedBox(height: AppSpace.m),
        _FingerprintCard(label: l10n.lotterySeed, value: detail.lottery.seed!),
      ],
    ]);
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.detail, required this.member, this.status});

  final CircleDetail detail;
  final CircleMember member;
  final CycleMemberStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = detail.summary;
    final st = status?.status;
    final current = detail.current;

    VoidCallback? onTap;
    if (s.isOrganizer && current != null && st != null) {
      if (st == ContributionStatus.recorded && status!.contributionEntryId != null) {
        onTap = () => showReviewPaymentSheet(
              context,
              circleId: s.id,
              p: PendingPayment(
                entryId: status!.contributionEntryId!,
                reference: status!.reference ?? '',
                subjectName: member.displayName,
                amountMinor: s.contributionMinor,
                cycleNumber: current.number,
                method: status!.method,
                recordedAt: status!.recordedAt,
              ),
            );
      } else if (st == ContributionStatus.verified && status!.contributionEntryId != null) {
        onTap = () => showReverseVerificationSheet(
              context,
              circleId: s.id,
              entryId: status!.contributionEntryId!,
              reference: status!.reference ?? '',
            );
      } else if (st == ContributionStatus.due || st == ContributionStatus.overdue) {
        onTap = () => showRecordPaymentSheet(context, circle: s, cycleNumber: current.number, subject: member);
      }
    }

    final subtitle = [
      if (member.payoutPosition != null) l10n.turnNumber(member.payoutPosition!),
      if (member.role == CircleRole.organizer) l10n.organizerLabel,
      if (status?.reference != null) status!.reference!,
    ].join(' · ');

    return PsListRow(
      leading: PsAvatar(name: member.displayName, size: 46),
      title: member.isYou ? '${member.displayName} (${l10n.youLabel})' : member.displayName,
      subtitle: subtitle.isEmpty ? null : subtitle,
      trailing: st == null
          // no status this cycle: this member is the one being paid
          ? (current != null && detail.cycles.any((c) => c.number == current.number && c.recipientUserId == member.userId)
              ? PsStatusPill(label: l10n.turnCurrent, tone: PsPillTone.success, icon: Icons.south_west_rounded)
              : null)
          : PsStatusBadge(status: st, label: st == ContributionStatus.recorded ? l10n.filterPending : statusLabel(l10n, st)),
      showChevron: onTap != null,
      onTap: onTap,
    );
  }
}
