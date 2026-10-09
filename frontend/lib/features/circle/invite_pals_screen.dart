import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/circles/circle_models.dart';
import '../../core/circles/circles_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_search_field.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';

/// Organizer picks pals to invite. Only pals are listed; selection stops at
/// the seats left so nobody is invited into a full circle.
class InvitePalsScreen extends ConsumerStatefulWidget {
  const InvitePalsScreen({super.key, required this.circleId});

  final String circleId;

  @override
  ConsumerState<InvitePalsScreen> createState() => _InvitePalsScreenState();
}

class _InvitePalsScreenState extends ConsumerState<InvitePalsScreen> {
  final _search = TextEditingController();
  final _message = TextEditingController();
  final _picked = <String>{};
  String _query = '';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = _message.text.trim();
      await ref.read(circlesApiProvider).invite(widget.circleId, _picked.toList(), message: msg.isEmpty ? null : msg);
      refreshCircle(ref, widget.circleId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.invitationsSentToast)));
      router.pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(invitablePalsProvider(widget.circleId));
    final data = async.value;
    final seats = data?.$1 ?? 0;
    final left = seats - _picked.length;
    final pals = (data?.$2 ?? const <InvitablePal>[])
        .where(
          (p) =>
              _query.isEmpty ||
              p.person.fullName.toLowerCase().contains(_query) ||
              (p.person.username ?? '').contains(_query),
        )
        .toList();

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.invitePals, backLabel: l10n.backLabel),
        bottom: data == null || data.$2.isEmpty
            ? null
            : _SendBar(
                label: _picked.isEmpty ? l10n.invitePals : l10n.sendInvitations(_picked.length),
                busy: _busy,
                onPressed: _picked.isEmpty ? null : _send,
              ),
        children: [
          Row(
            children: [
              const PsIconBadge(icon: Icons.event_seat_rounded, tone: PsBadgeTone.mint, size: 40),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(l10n.seatsLeft(left < 0 ? 0 : left), style: AppText.section),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s),
          Text(l10n.inviteOnlyPalsNote, style: AppText.footnote),
          const SizedBox(height: AppSpace.l),
          if (data == null && async.hasError)
            Text(messageFor(l10n, async.error!), style: AppText.body)
          else if (data == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.forest700, strokeWidth: 2)),
            )
          else if (data.$2.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.l),
              child: Column(
                children: [
                  const PsIconBadge(icon: Icons.handshake_outlined, tone: PsBadgeTone.mint, size: 64),
                  const SizedBox(height: AppSpace.m),
                  Text(l10n.noPalsToInvite, style: AppText.headline),
                  const SizedBox(height: AppSpace.xs),
                  Text(l10n.noPalsToInviteBody, textAlign: TextAlign.center, style: AppText.footnote),
                  const SizedBox(height: AppSpace.l),
                  PsButton(
                    label: l10n.findPeople,
                    icon: Icons.search_rounded,
                    expand: false,
                    onPressed: () => context.go('/chats'),
                  ),
                ],
              ),
            )
          else ...[
            if (data.$2.length > 6) ...[
              PsSearchField(
                controller: _search,
                hint: l10n.searchPeopleHint,
                clearLabel: l10n.clearSearch,
                onChanged: (q) => setState(() => _query = q.trim().toLowerCase()),
              ),
              const SizedBox(height: AppSpace.l),
            ],
            for (final p in pals)
              _PalTile(
                pal: p,
                selected: _picked.contains(p.person.id),
                enabled: p.state == InvitableState.available && (left > 0 || _picked.contains(p.person.id)) && !_busy,
                onTap: () => setState(() {
                  if (!_picked.remove(p.person.id)) _picked.add(p.person.id);
                }),
              ),
            const SizedBox(height: AppSpace.l),
            PsTextField(
              label: l10n.inviteMessageLabel,
              hint: l10n.inviteMessageHint,
              controller: _message,
              maxLength: 200,
              maxLines: 3,
              showCounter: true,
              textInputAction: TextInputAction.newline,
            ),
            if (_error != null) ...[const SizedBox(height: AppSpace.l), ErrorBanner(_error!)],
          ],
        ],
      ),
    );
  }
}

class _PalTile extends StatelessWidget {
  const _PalTile({required this.pal, required this.selected, required this.enabled, required this.onTap});

  final InvitablePal pal;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = pal.person;
    final status = switch (pal.state) {
      InvitableState.member => (l10n.alreadyInCircle, Icons.check_circle_rounded, PsPillTone.success),
      InvitableState.invited => (l10n.invitedPill, Icons.mail_outline_rounded, PsPillTone.warning),
      InvitableState.available => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        checked: status == null ? selected : null,
        enabled: enabled || status != null,
        label: status == null ? l10n.selectPal(p.fullName) : '${p.fullName}, ${status.$1}',
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.mintSoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: selected ? AppColors.forest600 : AppColors.stroke, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 68),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Opacity(
                  opacity: enabled || selected || status != null ? 1 : 0.45,
                  child: Row(
                    children: [
                      PsUserAvatar(name: p.fullName, avatarUrl: p.avatarUrl, size: 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.fullName, style: AppText.headline),
                            if (p.username != null) Text('@${p.username}', style: AppText.footnote),
                          ],
                        ),
                      ),
                      if (status != null)
                        PsStatusPill(label: status.$1, icon: status.$2, tone: status.$3, filled: false)
                      else
                        Icon(
                          selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: selected ? AppColors.forest600 : AppColors.strokeStrong,
                          size: 28,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendBar extends StatelessWidget {
  const _SendBar({required this.label, required this.busy, required this.onPressed});

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.stroke)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: PsButton(label: label, icon: Icons.send_rounded, loading: busy, onPressed: onPressed),
      ),
    ),
  );
}
