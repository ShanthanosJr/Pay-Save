import 'package:flutter/material.dart';
import '../../core/api/error_messages.dart';
import '../../core/community/community.dart';
import '../../core/widgets/ps_sheet.dart';
import '../community/community_labels.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/circles/circle_labels.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/format/status_label.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';
import '../shell/async_states.dart';
import '../shell/brand_header.dart';
import '../shell/circle_switcher.dart';

enum _Filter { all, verified, pending }

/// The member's passbook (FR-02, FR-08): every ledger entry, never edited.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Filter _filter = _Filter.all;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final circle = ref.watch(activeCircleProvider).value;

    return PsForestPage(
      header: const BrandHeader(),
      children: [
        PsSectionHeader(title: l10n.navHistory, large: true),
        if (circle == null)
          EmptyState(icon: Icons.receipt_long_rounded, title: l10n.historyEmptyTitle, body: l10n.historyEmptyBody)
        else ...[
          Align(alignment: AlignmentDirectional.centerStart, child: CircleSwitcherChip(circle: circle)),
          const SizedBox(height: AppSpace.m),
          if (circle.isOrganizer) ...[
            PsSegmented<bool>(
              segments: [(false, l10n.scopeMine), (true, l10n.scopeAll)],
              selected: _all,
              onChanged: (v) => setState(() => _all = v),
            ),
            const SizedBox(height: AppSpace.m),
          ],
          PsSegmented<_Filter>(
            segments: [
              (_Filter.all, l10n.filterAll),
              (_Filter.verified, l10n.filterVerified),
              (_Filter.pending, l10n.filterPending),
            ],
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpace.m),
          // ER-02: the promise sits where every visitor sees it
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkSubtle),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.recordsAppendOnly, style: AppText.caption)),
          ]),
          const SizedBox(height: AppSpace.l),
          ref.watch(ledgerProvider((circleId: circle.id, all: _all && circle.isOrganizer))).when(
                loading: () => const SheetLoading(),
                error: (e, _) => SheetError(
                  error: e,
                  onRetry: () => ref.invalidate(ledgerProvider((circleId: circle.id, all: _all))),
                ),
                data: (entries) {
                  final shown = entries.where((e) => switch (_filter) {
                        _Filter.all => true,
                        _Filter.verified => e.type == LedgerType.contributionRecorded && e.status == 'verified',
                        _Filter.pending => e.type == LedgerType.contributionRecorded && e.status == 'recorded',
                      });
                  if (shown.isEmpty) {
                    return _filter == _Filter.pending
                        ? EmptyState(icon: Icons.hourglass_empty_rounded, title: l10n.emptyPendingTitle, body: l10n.emptyPendingBody)
                        : EmptyState(icon: Icons.receipt_long_rounded, title: l10n.historyEmptyTitle, body: l10n.historyEmptyBody);
                  }
                  final byId = {for (final e in entries) e.id: e};
                  return Column(children: [
                    for (final e in shown) _EntryRow(circleId: circle.id, entry: e, byId: byId, showSubject: _all),
                  ]);
                },
              ),
        ],
      ],
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.circleId, required this.entry, required this.byId, required this.showSubject});

  final String circleId;

  final LedgerEntry entry;
  final Map<String, LedgerEntry> byId;
  final bool showSubject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final e = entry;
    void dispute() => showRaiseDisputeSheet(context, ref, circleId: circleId, entry: e);
    final when = dateTime(l10n, e.createdAt);
    final who = showSubject && e.subjectName != null ? '${e.subjectName} · ' : '';

    switch (e.type) {
      case LedgerType.contributionRecorded:
        final status = switch (e.status) {
          'verified' => ContributionStatus.verified,
          'corrected' => null,
          _ => ContributionStatus.recorded,
        };
        final method = [
          if (e.method != null) methodLabel(l10n, e.method!),
          if (e.provider != null) e.provider!,
          if (e.receiptReference != null) e.receiptReference!,
        ].join(' · ');
        return PsListRow(
          icon: status == null ? Icons.remove_done_rounded : PsStatusBadge.styleFor(status).$1,
          tone: switch (status) {
            ContributionStatus.verified => PsBadgeTone.forest,
            null => PsBadgeTone.neutral,
            _ => PsBadgeTone.info,
          },
          title: '$who${l10n.entryContribution(e.cycleNumber ?? 0)}',
          subtitle: [e.reference, if (method.isNotEmpty) method, when].join(' · '),
          trailing: Text(formatLkr(e.amountMinor ?? 0), style: AppText.label),
          onTap: dispute,
          below: Align(
            alignment: AlignmentDirectional.centerStart,
            child: status == null
                ? PsStatusPill(label: l10n.statusCorrected, tone: PsPillTone.neutral, icon: Icons.undo_rounded, filled: false)
                : PsStatusBadge(status: status, label: statusLabel(l10n, status)),
          ),
        );
      case LedgerType.correction:
        final target = byId[e.targetEntryId];
        return PsListRow(
          icon: Icons.undo_rounded,
          tone: PsBadgeTone.warning,
          title: '$who${l10n.entryCorrection} · ${e.reference}',
          onTap: dispute,
          subtitle: [
            l10n.correctsRef(target?.reference ?? ''),
            if (e.note != null) '“${e.note}”',
            when,
          ].join('\n'),
          trailing: e.amountMinor == null
              ? null
              : Text('−${formatMinor(e.amountMinor!.abs())}', style: AppText.label.copyWith(color: AppColors.warning)),
        );
      case LedgerType.contributionVerified:
        return PsListRow(
          icon: Icons.verified_rounded,
          title: '$who${l10n.entryVerification}',
          subtitle: [byId[e.targetEntryId]?.reference ?? e.reference, l10n.recordedBy(e.actorName), when].join(' · '),
        );
      case LedgerType.payout:
        return PsListRow(
          icon: Icons.south_west_rounded,
          tone: PsBadgeTone.mint,
          title: '$who${l10n.entryPayout(e.cycleNumber ?? 0)}',
          onTap: dispute,
          subtitle: '${e.reference} · $when',
          trailing: Text(formatLkr(e.amountMinor ?? 0), style: AppText.label.copyWith(color: AppColors.success)),
        );
      case LedgerType.memberAdded:
        return PsListRow(
          icon: Icons.person_add_alt_1_rounded,
          tone: PsBadgeTone.mint,
          title: l10n.entryMemberAdded(e.subjectName ?? ''),
          subtitle: '${e.reference} · $when',
        );
      case LedgerType.turnOrderSet:
        return PsListRow(icon: Icons.format_list_numbered_rounded, tone: PsBadgeTone.mint, title: l10n.entryTurnOrder, subtitle: '${e.reference} · $when');
      case LedgerType.cycleClosed:
        return PsListRow(icon: Icons.lock_rounded, tone: PsBadgeTone.neutral, title: l10n.entryCycleClosed(e.cycleNumber ?? 0), subtitle: '${e.reference} · $when');
      case LedgerType.memberRemoved:
        return PsListRow(icon: Icons.person_remove_rounded, tone: PsBadgeTone.neutral, title: l10n.entryMemberRemoved(e.subjectName ?? ''), subtitle: [e.reference, if (e.note != null) '“${e.note}”', when].join(' · '));
    }
  }
}

/// A record the member disagrees with can be put in front of a community
/// officer, but only after everyone it concerns agrees (U-05).
void showRaiseDisputeSheet(BuildContext context, WidgetRef ref, {required String circleId, required LedgerEntry entry}) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  showPsSheet<void>(
    context: context,
    title: l10n.raiseDisputeTitle(entry.reference),
    subtitle: l10n.raiseDisputeBody,
    builder: (ctx) => Column(children: [
      for (final c in DisputeCategory.values)
        PsListRow(
          icon: Icons.gavel_rounded,
          tone: PsBadgeTone.mint,
          title: disputeCategoryLabel(l10n, c),
          showChevron: true,
          onTap: () async {
            Navigator.of(ctx).pop();
            try {
              await ref.read(communityApiProvider).raise(circleId, entry.id, c);
              ref.invalidate(disputesProvider(circleId));
              messenger.showSnackBar(SnackBar(content: Text(l10n.disputeRaisedToast)));
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
            }
          },
        ),
    ]),
  );
}
