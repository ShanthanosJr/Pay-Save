import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_labels.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_arithmetic_row.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';
import '../payouts/payout_method_picker.dart';
import 'circle_setup.dart';

/// Everything needed to decide, then one step: choose how you get paid and join.
class InvitationScreen extends ConsumerStatefulWidget {
  const InvitationScreen({super.key, required this.invitationId});

  final String invitationId;

  @override
  ConsumerState<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends ConsumerState<InvitationScreen> {
  PayoutSelection? _payout;
  bool _busy = false;
  String? _error;

  Future<void> _accept(MyInvitation inv) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sel = _payout;
    if (sel == null || sel.isEmpty) {
      setState(() => _error = l10n.choosePayoutRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await ref
          .read(circlesApiProvider)
          .acceptInvitation(inv.id, methodIds: sel.ids, preferredId: sel.preferredId);
      ref.invalidate(myInvitationsProvider);
      ref.read(selectedCircleIdProvider.notifier).select(d.id);
      refreshCircle(ref, d.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.joinedToast(inv.name))));
      router.go('/circle');
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(MyInvitation inv) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showPsSheet<bool>(
      context: context,
      title: l10n.declineConfirmTitle,
      subtitle: l10n.declineConfirmBody(inv.organizer.fullName),
      builder: (ctx) => Row(
        children: [
          Expanded(
            child: PsButton(
              label: l10n.cancelLabel,
              variant: PsButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: PsButton(
              label: l10n.declineInvitation,
              variant: PsButtonVariant.danger,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(circlesApiProvider).declineInvitation(inv.id);
      ref.invalidate(myInvitationsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.declinedToast)));
      if (router.canPop()) router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myInvitationsProvider);
    final inv = async.value?.where((i) => i.id == widget.invitationId).firstOrNull;

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.circleInvitationsTitle, backLabel: l10n.backLabel),
        children: [
          if (inv == null && async.isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.forest700, strokeWidth: 2)),
            )
          else if (inv == null)
            Text(l10n.errInvitationGone, style: AppText.body)
          else ...[
            _Hero(inv: inv),
            const SizedBox(height: AppSpace.l),
            PsArithmeticRow(
              summary: l10n.potArithmetic(
                inv.payout.count,
                formatLkr(inv.payout.unitMinor),
                formatLkr(inv.payout.totalMinor),
              ),
            ),
            const SizedBox(height: AppSpace.l),
            _Terms(inv: inv),
            const SizedBox(height: AppSpace.xl),
            CollectionModeExplainer(mode: inv.collectionMode),
            if (inv.palsInside.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xl),
              PsGroupLabel(l10n.palsInsideLabel),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in inv.palsInside)
                    Chip(
                      avatar: PsUserAvatar(name: n, avatarUrl: null, size: 24),
                      label: Text(n, style: AppText.label),
                      backgroundColor: AppColors.surface,
                      shape: const StadiumBorder(side: BorderSide(color: AppColors.stroke)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpace.xxl),
            PsSectionHeader(title: l10n.howYouGetPaidHere),
            Text(l10n.choosePayoutBody, style: AppText.footnote),
            const SizedBox(height: AppSpace.m),
            PayoutMethodPicker(selection: _payout, onChanged: (s) => setState(() => _payout = s)),
            if (_error != null) ...[const SizedBox(height: AppSpace.l), ErrorBanner(_error!)],
            const SizedBox(height: AppSpace.xl),
            PsButton(
              label: l10n.acceptInvitation,
              icon: Icons.how_to_reg_rounded,
              loading: _busy,
              onPressed: () => _accept(inv),
            ),
            const SizedBox(height: AppSpace.m),
            PsButton(
              label: l10n.declineInvitation,
              variant: PsButtonVariant.secondary,
              onPressed: _busy ? null : () => _decline(inv),
            ),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.inv});

  final MyInvitation inv;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PsUserAvatar(name: inv.organizer.fullName, avatarUrl: inv.organizer.avatarUrl, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.invitedBy(inv.organizer.fullName), style: AppText.footnote),
                    const SizedBox(height: 2),
                    Text(inv.name, style: AppText.title),
                  ],
                ),
              ),
            ],
          ),
          if (inv.message != null) ...[
            const SizedBox(height: AppSpace.m),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  topLeft: Radius.circular(6),
                ),
              ),
              child: Text('“${inv.message}”', style: AppText.body.copyWith(color: AppColors.ink)),
            ),
          ],
          const SizedBox(height: AppSpace.m),
          Text(l10n.membersSoFar(inv.memberCount, inv.plannedCycles), style: AppText.caption),
        ],
      ),
    );
  }
}

class _Terms extends StatelessWidget {
  const _Terms({required this.inv});

  final MyInvitation inv;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final facts = [
      (Icons.payments_outlined, l10n.contributionLabel, formatLkr(inv.contributionMinor)),
      (Icons.event_repeat_rounded, l10n.intervalLabel, intervalLabel(l10n, inv.interval)),
      (Icons.repeat_rounded, l10n.cyclesCountLabel, '${inv.plannedCycles}'),
      (Icons.swap_vert_rounded, l10n.turnRuleLabel, turnRuleLabel(l10n, inv.turnRule)),
      if (inv.firstDueDate != null)
        (Icons.flag_outlined, l10n.startsOn(''), longDate(l10n, inv.firstDueDate!)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - AppSpace.m) / 2;
        return Wrap(
          spacing: AppSpace.m,
          runSpacing: AppSpace.m,
          children: [
            for (final (icon, label, value) in facts)
              Container(
                width: w,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: AppColors.forest700),
                    const SizedBox(height: 6),
                    Text(label.trim(), style: AppText.caption),
                    Text(value, style: AppText.headline),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Invitations waiting for me, shown on Home and the Circles tab.
class InvitationsBanner extends ConsumerWidget {
  const InvitationsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(myInvitationsProvider).value ?? const <MyInvitation>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final inv in list)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.m),
            child: Material(
              color: AppColors.forest800,
              borderRadius: BorderRadius.circular(AppRadii.card),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/circle-invitations/${inv.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      PsUserAvatar(name: inv.organizer.fullName, avatarUrl: inv.organizer.avatarUrl, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.mail_rounded, size: 15, color: AppColors.mint),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    l10n.circleInvitationsTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption.copyWith(color: AppColors.mint),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.invitationCardTitle(inv.organizer.fullName, inv.name),
                              style: AppText.headline.copyWith(color: AppColors.onForest),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatLkr(inv.contributionMinor)} · ${intervalLabel(l10n, inv.interval)}',
                              style: AppText.footnote.copyWith(color: AppColors.onForestMuted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.onForest),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
