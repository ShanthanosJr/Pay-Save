import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/error_messages.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/providers/prefs_store.dart';
import '../../core/social/social_models.dart';
import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../core/widgets/ps_search_field.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../core/widgets/ps_skeleton.dart';
import '../../l10n/gen/app_localizations.dart';
import '../pals/pal_requests_row.dart';
import '../people/pal_actions.dart';
import '../people/person_row.dart';
import '../shell/brand_header.dart';

/// Chats tab: find people (search + suggestions) and the conversation list.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  static const inboxPollEvery = Duration(seconds: 15);

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _poll;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(ChatsScreen.inboxPollEvery, (_) => ref.invalidate(inboxProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (!mounted) return;
    ref.invalidate(inboxProvider);
    ref.read(chatUnreadProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PsForestPage(
      header: const BrandHeader(),
      children: [
        PsSectionHeader(title: l10n.chatsTitle, large: true),
        PsSearchField(
          controller: _search,
          hint: l10n.searchPeopleHint,
          clearLabel: l10n.clearSearch,
          onChanged: _onQuery,
        ),
        const SizedBox(height: AppSpace.xl),
        if (_query.isNotEmpty)
          _SearchResults(query: _query, onOpen: _open)
        else ...[
          const PalRequestsRow(),
          const SizedBox(height: AppSpace.l),
          _Suggestions(onOpen: _open),
          _Inbox(onOpen: _open),
        ],
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, required this.onOpen});

  final String query;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(peopleSearchProvider(query))
        .when(
          loading: () => const _Loading(),
          error: (e, _) => _Message(text: messageFor(l10n, e)),
          data: (people) => people.isEmpty
              ? _Message(text: l10n.noPeopleFound(query))
              : Column(
                  children: [for (final p in people) PersonRow(person: p, onTap: () => onOpen('/people/${p.id}'))],
                ),
        );
  }
}

class _Suggestions extends ConsumerStatefulWidget {
  const _Suggestions({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  ConsumerState<_Suggestions> createState() => _SuggestionsState();
}

class _SuggestionsState extends ConsumerState<_Suggestions> {
  /// Local status so a card shows "Pending" instead of vanishing after a request.
  final _status = <String, PalStatus>{};
  final _busy = <String>{};

  Future<void> _pal(Person p, PalStatus current) async {
    final action = primaryPalAction(current);
    final ok = await runPalAction(
      context,
      ref,
      p,
      action,
      keepSuggestions: true,
      onStart: () => setState(() => _busy.add(p.id)),
    );
    if (!mounted) return;
    setState(() {
      _busy.remove(p.id);
      if (ok) _status[p.id] = action == PalAction.request ? PalStatus.outgoing : PalStatus.none;
    });
  }

  String _reason(AppLocalizations l10n, Suggestion s) => switch (s.reason) {
    SuggestionReason.sharedCircle => l10n.reasonSharedCircle,
    SuggestionReason.mutualPals => l10n.mutualPalsCount(s.mutualCount),
    SuggestionReason.followsYou => l10n.reasonFollowsYou,
    SuggestionReason.newMember => l10n.reasonNew,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(suggestionsProvider).value ?? const <Suggestion>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PsSectionHeader(title: l10n.suggestedForYou),
        SizedBox(
          // fits avatar, name, two reason lines and the button at any text size
          height: 156 + MediaQuery.textScalerOf(context).scale(58),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.m),
            itemBuilder: (context, i) {
              final s = list[i];
              final p = s.person;
              final status = _status[p.id] ?? p.palStatus;
              final (label, icon, variant) = palButtonStyle(l10n, status);
              return SizedBox(
                width: 156,
                child: PsCard(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  onTap: () => widget.onOpen('/people/${p.id}'),
                  child: Column(
                    children: [
                      PsUserAvatar(name: p.fullName, avatarUrl: p.avatarUrl, size: 64),
                      const SizedBox(height: AppSpace.s),
                      NameWithTick(name: p.fullName, verified: p.verified, style: AppText.label),
                      const SizedBox(height: 2),
                      Text(
                        _reason(l10n, s),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                      const Spacer(),
                      PsButton(
                        label: label,
                        icon: icon,
                        variant: variant,
                        compact: true,
                        loading: _busy.contains(p.id),
                        onPressed: () => _pal(p, status),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
      ],
    );
  }
}

class _Inbox extends ConsumerStatefulWidget {
  const _Inbox({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  ConsumerState<_Inbox> createState() => _InboxState();
}

class _InboxState extends ConsumerState<_Inbox> {
  bool _favouritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(inboxProvider);
    final all = async.value;
    final hasFavourites = all?.any((c) => c.favourite) ?? false;
    final favouritesOnly = _favouritesOnly && hasFavourites;
    final chats = favouritesOnly ? all!.where((c) => c.favourite).toList() : all;
    final auth = ref.watch(authControllerProvider);
    final me = auth is AuthLoggedIn ? auth.user.id : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chats == null && async.isLoading)
          const _Loading()
        else if (chats == null)
          _Message(
            text: l10n.loadFailed,
            action: PsButton(
              label: l10n.retryLabel,
              variant: PsButtonVariant.secondary,
              compact: true,
              expand: false,
              onPressed: () => ref.invalidate(inboxProvider),
            ),
          )
        else if (chats.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.l),
            child: Column(
              children: [
                const PsIconBadge(icon: Icons.forum_outlined, tone: PsBadgeTone.mint, size: 56),
                const SizedBox(height: AppSpace.m),
                Text(l10n.noChatsTitle, style: AppText.headline),
                const SizedBox(height: AppSpace.xs),
                Text(l10n.noChatsBody, textAlign: TextAlign.center, style: AppText.footnote),
              ],
            ),
          )
        else ...[
          if (hasFavourites)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.m),
              child: PsSegmented<bool>(
                segments: [(false, l10n.chatFilterAll), (true, l10n.chatFilterFavourites)],
                selected: favouritesOnly,
                onChanged: (v) => setState(() => _favouritesOnly = v),
              ),
            ),
          for (final c in chats)
            _ChatRow(
              chat: c,
              me: me,
              onTap: () => widget.onOpen('/chats/${c.id}'),
              onLongPress: () => showChatActionsSheet(context, ref, c),
            ),
        ],
      ],
    );
  }
}

class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.chat, required this.me, required this.onTap, this.onLongPress});

  final VoidCallback? onLongPress;

  final ChatSummary chat;
  final String me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hidden = ref.watch(hideChatPreviewsProvider);
    final unread = chat.unread > 0;
    final at = chat.lastMessage.createdAt;
    final now = DateTime.now();
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    final time = (sameDay ? DateFormat.Hm(l10n.localeName) : DateFormat.MMMd(l10n.localeName)).format(at);
    final last = chat.lastMessage;
    final said = last.deleted
        ? l10n.chatDeleted
        : switch (last.kind) {
            MessageKind.image => last.body.isEmpty ? l10n.chatPhoto : '${l10n.chatPhoto} · ${last.body}',
            MessageKind.video => last.body.isEmpty ? l10n.chatVideo : '${l10n.chatVideo} · ${last.body}',
            MessageKind.text => last.body,
          };
    final preview = hidden ? l10n.chatHiddenPreview : (last.senderId == me ? l10n.youPrefix(said) : said);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: unread ? AppColors.forest500 : AppColors.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                PsUserAvatar(name: chat.peer.fullName, avatarUrl: chat.peer.avatarUrl, size: 50),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.peer.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headline.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview.replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.footnote.copyWith(
                          color: unread ? AppColors.ink : AppColors.inkMuted,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (chat.pinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin_rounded, size: 14, color: AppColors.inkMuted, semanticLabel: l10n.chatPinned),
                        ),
                      if (chat.favourite)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.favorite_rounded, size: 14, color: AppColors.danger, semanticLabel: l10n.chatFavouriteLabel),
                        ),
                      Text(time, style: AppText.caption),
                    ]),
                    if (unread) ...[
                      const SizedBox(height: 6),
                      Semantics(
                        label: l10n.unreadCount(chat.unread),
                        excludeSemantics: true,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.forest700,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            chat.unread > 99 ? '99+' : '${chat.unread}',
                            textAlign: TextAlign.center,
                            style: AppText.caption.copyWith(color: AppColors.onForest, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const PsSkeletonRows(count: 4, trailing: true);
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.l),
    child: Column(
      children: [
        Text(text, textAlign: TextAlign.center, style: AppText.body),
        if (action != null) ...[const SizedBox(height: AppSpace.m), action!],
      ],
    ),
  );
}

/// Pin, favourite or delete a chat. All three affect my inbox only.
void showChatActionsSheet(BuildContext context, WidgetRef ref, ChatSummary chat) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final api = ref.read(socialApiProvider);

  Future<void> run(Future<void> Function() fn, {String? toast}) async {
    try {
      await fn();
      ref.invalidate(inboxProvider);
      ref.read(chatUnreadProvider.notifier).refresh();
      if (toast != null) messenger.showSnackBar(SnackBar(content: Text(toast)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
    }
  }

  showPsSheet<void>(
    context: context,
    title: chat.peer.fullName,
    builder: (ctx) => Column(children: [
      PsListRow(
        icon: chat.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        tone: PsBadgeTone.mint,
        title: chat.pinned ? l10n.chatUnpin : l10n.chatPin,
        subtitle: chat.pinned ? null : l10n.chatPinHint,
        onTap: () {
          Navigator.of(ctx).pop();
          run(() => api.setChatFlags(chat.id, pinned: !chat.pinned));
        },
      ),
      PsListRow(
        icon: chat.favourite ? Icons.favorite_border_rounded : Icons.favorite_rounded,
        tone: PsBadgeTone.mint,
        title: chat.favourite ? l10n.chatUnfavourite : l10n.chatFavourite,
        onTap: () {
          Navigator.of(ctx).pop();
          run(() => api.setChatFlags(chat.id, favourite: !chat.favourite));
        },
      ),
      PsListRow(
        icon: Icons.delete_outline_rounded,
        tone: PsBadgeTone.danger,
        title: l10n.chatDelete,
        subtitle: l10n.chatDeleteBody(chat.peer.fullName),
        titleColor: AppColors.danger,
        onTap: () {
          Navigator.of(ctx).pop();
          run(() => api.clearChat(chat.id), toast: l10n.chatDeletedToast);
        },
      ),
    ]),
  );
}
