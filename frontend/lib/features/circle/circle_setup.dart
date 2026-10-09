import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../l10n/gen/app_localizations.dart';
import '../payouts/payout_method_picker.dart';
import '../payouts/payout_ui.dart';

/// "Getting ready to start": seats, payment details, readiness. Each line
/// is an icon plus words, never colour alone.
class SetupChecklist extends StatelessWidget {
  const SetupChecklist({super.key, required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = detail.setup;
    final missing = s.membersMissingPayout.length;
    final enoughMembers = s.seatsTaken >= 2;
    final progress = s.seatsTotal == 0 ? 0.0 : s.seatsTaken / s.seatsTotal;

    return PsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PsIconBadge(
                icon: s.canStart ? Icons.rocket_launch_rounded : Icons.checklist_rounded,
                tone: s.canStart ? PsBadgeTone.forest : PsBadgeTone.warning,
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(s.canStart ? l10n.setupReady : l10n.setupTitle, style: AppText.section)),
            ],
          ),
          const SizedBox(height: AppSpace.l),
          Semantics(
            label: l10n.setupSeats(s.seatsTaken, s.seatsTotal),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.stroke,
                color: AppColors.forest600,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          _Check(
            done: s.seatsTaken >= s.seatsTotal,
            text: [
              l10n.setupSeats(s.seatsTaken, s.seatsTotal),
              if (s.pendingInvitations > 0) l10n.setupInvited(s.pendingInvitations),
            ].join(' · '),
          ),
          _Check(done: missing == 0, text: missing == 0 ? l10n.setupPayoutAllSet : l10n.setupPayoutMissing(missing)),
          if (!enoughMembers) _Check(done: false, text: l10n.setupNeedMembers),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.done, required this.text});

  final bool done;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 20,
          color: done ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(child: Text(text, style: AppText.callout)),
      ],
    ),
  );
}

/// Organizer picks how money flows; members just see it explained.
class CollectionModeSelector extends ConsumerStatefulWidget {
  const CollectionModeSelector({super.key, required this.detail});

  final CircleDetail detail;

  @override
  ConsumerState<CollectionModeSelector> createState() => _CollectionModeSelectorState();
}

class _CollectionModeSelectorState extends ConsumerState<CollectionModeSelector> {
  bool _busy = false;

  Future<void> _set(CollectionMode mode) async {
    final s = widget.detail.summary;
    if (mode == s.collectionMode || _busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(circlesApiProvider).setCollectionMode(s.id, mode);
      refreshCircle(ref, s.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.detail.summary;
    final mode = s.collectionMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PsSectionHeader(title: l10n.whoCollectsTitle),
        if (s.isOrganizer && s.status == CircleStatus.draft) ...[
          PsSegmented<CollectionMode>(
            segments: [
              (CollectionMode.directToRecipient, l10n.modeDirect),
              (CollectionMode.viaOrganizer, l10n.modeViaOrganizer),
            ],
            selected: mode,
            onChanged: _set,
          ),
          const SizedBox(height: AppSpace.s),
        ],
        CollectionModeExplainer(mode: mode),
      ],
    );
  }
}

/// A two-node diagram: who pays whom, with the sentence underneath.
class CollectionModeExplainer extends StatelessWidget {
  const CollectionModeExplainer({super.key, required this.mode});

  final CollectionMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direct = mode == CollectionMode.directToRecipient;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(AppRadii.small)),
      child: Row(
        children: [
          Icon(direct ? Icons.call_split_rounded : Icons.hub_rounded, color: AppColors.forest700),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(direct ? l10n.modeDirect : l10n.modeViaOrganizer, style: AppText.label),
                const SizedBox(height: 2),
                Text(
                  direct ? l10n.modeDirectBody : l10n.modeViaOrganizerBody,
                  style: AppText.footnote.copyWith(color: AppColors.forest800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Organizer's pending invitations, each cancellable.
class PendingInvitations extends ConsumerWidget {
  const PendingInvitations({super.key, required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (detail.invitations.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final inv in detail.invitations)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.stroke, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Opacity(
                    opacity: 0.7,
                    child: PsUserAvatar(name: inv.person.fullName, avatarUrl: inv.person.avatarUrl, size: 42),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.person.fullName, style: AppText.headline),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.mail_outline_rounded, size: 15, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text(l10n.invitedPill, style: AppText.caption.copyWith(color: AppColors.warning)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cancelInvitation(inv.person.fullName),
                    constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
                    icon: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref.read(circlesApiProvider).cancelInvitation(detail.id, inv.id);
                        refreshCircle(ref, detail.id);
                        messenger.showSnackBar(SnackBar(content: Text(l10n.invitationCancelledToast)));
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "How you get paid in this circle": what this circle may see of mine.
class MyCirclePayoutCard extends ConsumerWidget {
  const MyCirclePayoutCard({super.key, required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mine = detail.myPayout;
    final missing = mine.isEmpty;

    Future<void> change() async {
      final messenger = ScaffoldMessenger.of(context);
      final picked = await showPayoutPickerSheet(
        context,
        circleName: detail.summary.name,
        currentIds: [for (final m in mine) m.id],
        currentPreferred: mine.where((m) => m.preferred).firstOrNull?.id,
      );
      if (picked == null || picked.isEmpty) return;
      try {
        await ref.read(circlesApiProvider).sharePayout(detail.id, picked.ids, picked.preferredId ?? picked.ids.first);
        refreshCircle(ref, detail.id);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: missing ? AppColors.warningSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: missing ? AppColors.warning : AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                missing ? Icons.error_outline_rounded : Icons.account_balance_wallet_rounded,
                color: missing ? AppColors.warning : AppColors.forest700,
              ),
              const SizedBox(width: AppSpace.s),
              Expanded(child: Text(l10n.yourPayoutForCircle, style: AppText.headline)),
            ],
          ),
          const SizedBox(height: AppSpace.s),
          if (missing)
            Text(l10n.yourPayoutMissing, style: AppText.footnote.copyWith(color: AppColors.ink))
          else
            for (final m in mine)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(payoutKindIcon(m.kind), size: 18, color: AppColors.inkMuted),
                    const SizedBox(width: AppSpace.s),
                    Expanded(child: Text(m.summary, style: AppText.bodyStrong)),
                    if (m.preferred && mine.length > 1)
                      Text(l10n.preferredLabel, style: AppText.caption.copyWith(color: AppColors.success)),
                  ],
                ),
              ),
          const SizedBox(height: AppSpace.m),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PsButton(
              label: missing ? l10n.choosePayoutAction : l10n.changePayoutAction,
              icon: missing ? Icons.add_rounded : Icons.edit_outlined,
              variant: missing ? PsButtonVariant.primary : PsButtonVariant.secondary,
              compact: true,
              expand: false,
              onPressed: change,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon + words for a member's payout readiness.
class MemberPayoutTag extends StatelessWidget {
  const MemberPayoutTag({super.key, required this.member});

  final CircleMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ok = member.payoutReady;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.verified_rounded : Icons.schedule_rounded,
          size: 15,
          color: ok ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            ok
                ? [l10n.payoutReadyWord, ...member.payoutKinds.map((k) => payoutKindLabel(l10n, k))].join(' · ')
                : l10n.payoutMissingWord,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: ok ? AppColors.success : AppColors.warning),
          ),
        ),
      ],
    );
  }
}

/// Organizer's entry to the invite screen.
class InvitePalsButton extends StatelessWidget {
  const InvitePalsButton({super.key, required this.detail});

  final CircleDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final open = detail.setup.seatsOpen;
    return PsButton(
      label: '${l10n.invitePals} · ${l10n.seatsLeft(open)}',
      icon: Icons.group_add_rounded,
      variant: PsButtonVariant.secondary,
      onPressed: open == 0 ? null : () => context.push('/circles/${detail.id}/invite'),
    );
  }
}
