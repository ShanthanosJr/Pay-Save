import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/circles/circle_labels.dart';
import '../../core/format/money.dart';
import '../../core/notifications/notifications.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_skeleton.dart';
import '../../l10n/gen/app_localizations.dart';
import '../shell/async_states.dart';

/// What the notification says, in the reader's language.
String notificationTitle(AppLocalizations l10n, AppNotification n) {
  final cycle = n.intOf('cycleNumber') ?? 0;
  final ref = n.textOf('reference') ?? '';
  return switch (n.kind) {
    'payment_recorded' => l10n.notifPaymentRecorded(ref),
    'payment_recorded_for_you' => l10n.notifPaymentRecordedForYou(cycle),
    'payment_verified' => l10n.notifPaymentVerified(ref),
    'payment_rejected' => l10n.notifPaymentRejected(ref),
    'cycle_closed' => l10n.notifCycleClosed(cycle),
    'payout_due_to_you' => l10n.notifPayoutToYou(cycle),
    'circle_started' => l10n.notifCircleStarted,
    'circle_invitation' => l10n.notifInvitation,
    'member_joined' => l10n.notifMemberJoined,
    'member_removed' => n.textOf('via') == 'left' ? l10n.notifMemberLeft : l10n.notifMemberRemoved,
    'reminder_due' => (n.intOf('daysLeft') ?? 0) == 0 ? l10n.notifDueToday(cycle) : l10n.notifDueIn(cycle, n.intOf('daysLeft') ?? 0),
    'reminder_overdue' => l10n.notifOverdue(cycle),
    'organizer_nudge' => l10n.notifNudge(cycle),
    'dispute_consent_requested' => l10n.notifDisputeConsent,
    'dispute_updated' => switch (n.textOf('status')) {
        'resolved' => l10n.notifDisputeResolved,
        'declined' => l10n.notifDisputeDeclined,
        _ => l10n.notifDisputeConsented,
      },
    'evidence_viewed' => l10n.notifEvidenceViewed,
    _ => l10n.notifGeneric,
  };
}

String? notificationDetail(AppLocalizations l10n, AppNotification n) {
  final amount = n.intOf('amountMinor');
  final total = n.intOf('totalMinor');
  final count = n.intOf('count');
  final unit = n.intOf('unitMinor');
  return switch (n.kind) {
    'payment_rejected' => n.textOf('reason'),
    'member_removed' => n.textOf('reason'),
    'cycle_closed' || 'payout_due_to_you' when total != null && count != null && unit != null =>
      l10n.arithmeticVerified(count, formatLkr(unit), formatLkr(total)),
    'circle_started' when n.intOf('turn') != null => l10n.turnNumber(n.intOf('turn')!),
    'reminder_due' || 'reminder_overdue' || 'organizer_nudge' when amount != null => formatLkr(amount),
    _ => amount == null ? null : formatLkr(amount),
  };
}

(IconData, PsBadgeTone) _look(String kind) => switch (kind) {
      'payment_verified' => (Icons.verified_rounded, PsBadgeTone.forest),
      'payment_rejected' => (Icons.undo_rounded, PsBadgeTone.warning),
      'payment_recorded' || 'payment_recorded_for_you' => (Icons.receipt_long_rounded, PsBadgeTone.mint),
      'cycle_closed' => (Icons.lock_rounded, PsBadgeTone.forest),
      'payout_due_to_you' => (Icons.south_west_rounded, PsBadgeTone.forest),
      'reminder_due' || 'organizer_nudge' => (Icons.alarm_rounded, PsBadgeTone.mint),
      'reminder_overdue' => (Icons.alarm_rounded, PsBadgeTone.warning),
      'member_removed' => (Icons.person_remove_rounded, PsBadgeTone.warning),
      'evidence_viewed' => (Icons.visibility_rounded, PsBadgeTone.warning),
      'dispute_consent_requested' || 'dispute_updated' => (Icons.gavel_rounded, PsBadgeTone.mint),
      _ => (Icons.groups_rounded, PsBadgeTone.mint),
    };

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Unread when the page opened, so the highlight survives marking them read.
  Set<String>? _fresh;

  Future<void> _markRead(Inbox inbox) async {
    if (_fresh != null) return;
    _fresh = {for (final n in inbox.items) if (!n.read) n.id};
    if (_fresh!.isEmpty) return;
    try {
      await ref.read(notificationsApiProvider).markRead();
      ref.invalidate(inboxProvider);
    } catch (_) {
      // the badge simply stays until the next visit
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(inboxProvider);
    final inbox = async.value;
    if (inbox != null) WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(inbox));

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.notificationsLabel, backLabel: l10n.backLabel),
        children: [
          if (inbox == null && async.hasError)
            SheetError(error: async.error!, onRetry: () => ref.invalidate(inboxProvider))
          else if (inbox == null)
            const PsSkeletonRows(count: 6, leading: PsSkeletonLeading.badge)
          else if (inbox.items.isEmpty)
            EmptyState(
              icon: Icons.notifications_none_rounded,
              title: l10n.notificationsEmptyTitle,
              body: l10n.notificationsEmptyBody,
            )
          else
            for (final n in inbox.items)
              Builder(builder: (context) {
                final (icon, tone) = _look(n.kind);
                final detail = notificationDetail(l10n, n);
                final isNew = _fresh?.contains(n.id) ?? !n.read;
                return PsListRow(
                  icon: icon,
                  tone: tone,
                  title: notificationTitle(l10n, n),
                  subtitle: [
                    if (n.circleName != null) n.circleName!,
                    ?detail,
                    dateTime(l10n, n.createdAt),
                  ].join(' · '),
                  trailing: isNew
                      ? Semantics(
                          label: l10n.notifNewLabel,
                          child: const Icon(Icons.circle, size: 10, color: AppColors.forest600),
                        )
                      : null,
                );
              }),
          if (inbox != null && inbox.items.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xl),
            Text(l10n.notificationsFootnote, style: AppText.footnote),
          ],
        ],
      ),
    );
  }
}
