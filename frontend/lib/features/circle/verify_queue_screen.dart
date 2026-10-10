import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/circles/circle_labels.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_skeleton.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/auth_scaffold.dart';
import '../shell/async_states.dart';
import 'verify_actions.dart';

class VerifyQueueScreen extends ConsumerWidget {
  const VerifyQueueScreen({super.key, required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.watch(verifyQueueProvider(circleId));
    return AuthScaffold(
      titlePlain: l10n.verifyQueueTitlePlain,
      titleAccent: l10n.verifyQueueTitleAccent,
      subtitle: l10n.verifyQueueSubtitle,
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      child: queue.when(
        loading: () => const PsSkeletonRows(count: 4, trailing: true),
        error: (e, _) => SheetError(error: e, onRetry: () => ref.invalidate(verifyQueueProvider(circleId))),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.done_all_rounded, title: l10n.queueEmptyTitle, body: l10n.queueEmptyBody)
            : Column(children: [
                for (final i in items)
                  PsListRow(
                    leading: PsAvatar(name: i.subjectName, size: 44),
                    title: i.subjectName,
                    subtitle: [
                      i.reference,
                      if (i.method != null) methodLabel(l10n, i.method!),
                      if (i.receiptReference != null) i.receiptReference!,
                      shortDate(l10n, i.recordedAt),
                    ].join(' · '),
                    trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(formatLkr(i.amountMinor), style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      const PsIconBadge(icon: Icons.hourglass_top_rounded, tone: PsBadgeTone.info, size: 24),
                    ]),
                    showChevron: true,
                    onTap: () => showReviewPaymentSheet(context, circleId: circleId, p: PendingPayment.fromItem(i)),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSubtle),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.rejectBody, style: Theme.of(context).textTheme.bodySmall)),
                ]),
              ]),
      ),
    );
  }
}
