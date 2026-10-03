import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_messages.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/social/social_models.dart';
import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';
import 'profile_header.dart';

/// Another member's public profile: follow, message, block.
class PersonProfileScreen extends ConsumerStatefulWidget {
  const PersonProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PersonProfileScreen> createState() => _PersonProfileScreenState();
}

class _PersonProfileScreenState extends ConsumerState<PersonProfileScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFollow(PublicProfile p) => _run(() async {
    await ref.read(socialApiProvider).setFollowing(widget.userId, !p.person.isFollowing);
    ref.invalidate(publicProfileProvider(widget.userId));
    _refreshMine();
    ref.invalidate(suggestionsProvider);
  });

  Future<void> _message() => _run(() async {
    final router = GoRouter.of(context);
    final thread = await ref.read(socialApiProvider).openChat(widget.userId);
    router.push('/chats/${thread.id}');
  });

  Future<void> _setBlocked(bool block) => _run(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(socialApiProvider).setBlocked(widget.userId, block);
    ref.invalidate(publicProfileProvider(widget.userId));
    _refreshMine();
    ref.invalidate(suggestionsProvider);
    ref.invalidate(inboxProvider);
    messenger.showSnackBar(SnackBar(content: Text(block ? l10n.blockedToast : l10n.unblockedToast)));
  });

  /// Following or blocking someone changes my own counts too.
  void _refreshMine() {
    final me = ref.read(authControllerProvider);
    if (me is AuthLoggedIn) ref.invalidate(publicProfileProvider(me.user.id));
  }

  void _moreActions(PublicProfile p) {
    final l10n = AppLocalizations.of(context);
    showPsSheet<void>(
      context: context,
      title: p.person.fullName,
      builder: (ctx) => PsListRow(
        icon: p.blockedByMe ? Icons.lock_open_rounded : Icons.block_rounded,
        tone: p.blockedByMe ? PsBadgeTone.mint : PsBadgeTone.danger,
        title: p.blockedByMe ? l10n.unblockUser : l10n.blockUser,
        titleColor: p.blockedByMe ? null : AppColors.danger,
        onTap: () {
          Navigator.of(ctx).pop();
          if (p.blockedByMe) {
            _setBlocked(false);
          } else {
            _confirmBlock(p);
          }
        },
      ),
    );
  }

  void _confirmBlock(PublicProfile p) {
    final l10n = AppLocalizations.of(context);
    showPsSheet<void>(
      context: context,
      title: l10n.blockConfirmTitle(p.person.fullName),
      subtitle: l10n.blockConfirmBody,
      builder: (ctx) => Row(
        children: [
          Expanded(
            child: PsButton(
              label: l10n.cancelLabel,
              variant: PsButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: PsButton(
              label: l10n.blockUser,
              variant: PsButtonVariant.danger,
              onPressed: () {
                Navigator.of(ctx).pop();
                _setBlocked(true);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(publicProfileProvider(widget.userId));
    final p = async.value;
    final person = p?.person;

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(
          title: person == null ? '' : (person.username == null ? person.fullName : '@${person.username}'),
          backLabel: l10n.backLabel,
          trailing: p == null || p.isMe
              ? null
              : PsGlassIconButton(
                  icon: Icons.more_horiz_rounded,
                  label: l10n.moreActions,
                  onTap: () => _moreActions(p),
                ),
        ),
        children: [
          if (p == null && async.hasError)
            _Problem(
              message: ApiException.from(async.error!).statusCode == 404 ? l10n.personNotFound : l10n.loadFailed,
              onRetry: () => ref.invalidate(publicProfileProvider(widget.userId)),
            )
          else if (p == null)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator(color: AppColors.forest700, strokeWidth: 2)),
            )
          else ...[
            ProfileHeader(
              name: p.person.fullName,
              avatarUrl: p.person.avatarUrl,
              username: p.person.username,
              verified: p.person.verified,
              bio: p.blockedByMe ? null : p.bio,
              city: p.blockedByMe ? null : p.city,
              memberSince: p.memberSince,
              followers: p.followersCount,
              following: p.followingCount,
              sharedCircles: p.sharedCircles,
              isMe: p.isMe,
              onFollowers: p.blockedByMe ? null : () => context.push('/people/${p.person.id}/followers'),
              onFollowing: p.blockedByMe ? null : () => context.push('/people/${p.person.id}/following'),
              badge: p.person.followsYou && !p.isMe
                  ? PsStatusPill(
                      label: l10n.reasonFollowsYou,
                      tone: PsPillTone.neutral,
                      icon: Icons.person_add_alt_1_rounded,
                      filled: false,
                    )
                  : null,
            ),
            const SizedBox(height: AppSpace.l),
            if (p.isMe)
              PsButton(
                label: l10n.editProfile,
                icon: Icons.edit_outlined,
                variant: PsButtonVariant.secondary,
                compact: true,
                onPressed: () => context.push('/profile/edit'),
              )
            else if (p.blockedByMe) ...[
              _Notice(icon: Icons.block_rounded, text: l10n.blockedNotice),
              const SizedBox(height: AppSpace.m),
              PsButton(
                label: l10n.unblockUser,
                variant: PsButtonVariant.secondary,
                compact: true,
                loading: _busy,
                onPressed: () => _setBlocked(false),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: PsButton(
                      label: p.person.isFollowing
                          ? l10n.followingAction
                          : (p.person.followsYou ? l10n.followBackAction : l10n.followAction),
                      icon: p.person.isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                      variant: p.person.isFollowing ? PsButtonVariant.secondary : PsButtonVariant.primary,
                      compact: true,
                      onPressed: _busy ? null : () => _toggleFollow(p),
                    ),
                  ),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: PsButton(
                      label: l10n.messageAction,
                      icon: Icons.chat_bubble_outline_rounded,
                      variant: PsButtonVariant.secondary,
                      compact: true,
                      onPressed: _busy ? null : _message,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpace.xxxl),
            _Notice(icon: Icons.lock_outline_rounded, text: l10n.profilePrivacyNote),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.inkMuted),
      const SizedBox(width: AppSpace.s),
      Expanded(child: Text(text, style: AppText.footnote)),
    ],
  );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 32),
    child: Column(
      children: [
        const PsIconBadge(icon: Icons.person_off_outlined, tone: PsBadgeTone.neutral, size: 56),
        const SizedBox(height: AppSpace.l),
        Text(message, textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: AppSpace.l),
        PsButton(
          label: AppLocalizations.of(context).retryLabel,
          variant: PsButtonVariant.secondary,
          compact: true,
          expand: false,
          onPressed: onRetry,
        ),
      ],
    ),
  );
}
