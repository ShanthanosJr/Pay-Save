import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/social/social_models.dart';
import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../core/widgets/ps_skeleton.dart';
import '../../l10n/gen/app_localizations.dart';
import '../people/pal_actions.dart';
import '../people/person_row.dart';

enum _Box { received, sent }

/// Requests waiting for me (accept / ignore) and the ones I sent (withdraw).
class PalRequestsScreen extends ConsumerStatefulWidget {
  const PalRequestsScreen({super.key});

  @override
  ConsumerState<PalRequestsScreen> createState() => _PalRequestsScreenState();
}

class _PalRequestsScreenState extends ConsumerState<PalRequestsScreen> {
  _Box _box = _Box.received;
  final _busy = <String>{};

  Future<void> _act(Person p, PalAction action) async {
    await runPalAction(context, ref, p, action, onStart: () => setState(() => _busy.add(p.id)));
    if (mounted) setState(() => _busy.remove(p.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(palRequestsProvider);
    final data = async.value;
    final list = data == null ? null : (_box == _Box.received ? data.received : data.sent);

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.palRequestsTitle, backLabel: l10n.backLabel),
        children: [
          PsSegmented<_Box>(
            segments: [
              (_Box.received, l10n.palRequestsReceived(data?.received.length ?? 0)),
              (_Box.sent, l10n.palRequestsSent(data?.sent.length ?? 0)),
            ],
            selected: _box,
            onChanged: (b) => setState(() => _box = b),
          ),
          const SizedBox(height: AppSpace.xl),
          if (list == null && async.hasError)
            Column(
              children: [
                Text(l10n.loadFailed, style: AppText.body),
                const SizedBox(height: AppSpace.m),
                PsButton(
                  label: l10n.retryLabel,
                  variant: PsButtonVariant.secondary,
                  compact: true,
                  expand: false,
                  onPressed: () => ref.invalidate(palRequestsProvider),
                ),
              ],
            )
          else if (list == null)
            const PsSkeletonRows(count: 4, trailing: true)
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.l),
              child: Column(
                children: [
                  const PsIconBadge(icon: Icons.group_add_outlined, tone: PsBadgeTone.mint, size: 56),
                  const SizedBox(height: AppSpace.m),
                  Text(
                    _box == _Box.received ? l10n.noReceivedPalRequests : l10n.noSentPalRequests,
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                ],
              ),
            )
          else
            for (final r in list)
              _RequestCard(
                request: r,
                received: _box == _Box.received,
                busy: _busy.contains(r.person.id),
                onOpen: () => context.push('/people/${r.person.id}'),
                onAct: (a) => _act(r.person, a),
              ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.received,
    required this.busy,
    required this.onOpen,
    required this.onAct,
  });

  final PalRequest request;
  final bool received;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<PalAction> onAct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = request.person;
    final details = [
      if (p.username != null) '@${p.username}',
      if (request.mutualPals > 0) l10n.mutualPalsCount(request.mutualPals),
      l10n.sentOn(DateFormat.MMMd(l10n.localeName).format(request.requestedAt)),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.small),
                onTap: onOpen,
                child: Row(
                  children: [
                    PsUserAvatar(name: p.fullName, avatarUrl: p.avatarUrl, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NameWithTick(name: p.fullName, verified: p.verified, style: AppText.headline),
                          const SizedBox(height: 2),
                          Text(details, style: AppText.footnote),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.m),
              if (received)
                Row(
                  children: [
                    Expanded(
                      child: PsButton(
                        label: l10n.ignorePalAction,
                        variant: PsButtonVariant.secondary,
                        compact: true,
                        onPressed: busy ? null : () => onAct(PalAction.ignore),
                      ),
                    ),
                    const SizedBox(width: AppSpace.m),
                    Expanded(
                      child: PsButton(
                        label: l10n.acceptPalAction,
                        icon: Icons.check_rounded,
                        compact: true,
                        loading: busy,
                        onPressed: () => onAct(PalAction.accept),
                      ),
                    ),
                  ],
                )
              else
                PsButton(
                  label: l10n.withdrawAction,
                  variant: PsButtonVariant.secondary,
                  compact: true,
                  loading: busy,
                  onPressed: () => onAct(PalAction.withdraw),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
