import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/social/social_models.dart';
import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../l10n/gen/app_localizations.dart';

enum _Delivery { sent, sending, failed }

class _Item {
  _Item({
    required this.clientId,
    required this.senderId,
    required this.body,
    required this.at,
    this.seq,
    this.delivery = _Delivery.sent,
  });

  factory _Item.fromServer(ChatMessage m) =>
      _Item(clientId: m.clientMessageId, senderId: m.senderId, body: m.body, at: m.createdAt, seq: m.seq);

  final String clientId;
  final String senderId;
  final String body;
  final DateTime at;
  final int? seq;
  final _Delivery delivery;

  _Item copyWith({_Delivery? delivery}) =>
      _Item(clientId: clientId, senderId: senderId, body: body, at: at, seq: seq, delivery: delivery ?? this.delivery);
}

/// One conversation. Polls for new messages (no push channel yet); every
/// message carries a device-generated id so a retry never duplicates it.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.chatId});

  final String chatId;

  static const pollEvery = Duration(seconds: 3);
  static const pageSize = 50;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _composer = TextEditingController();
  final _items = <_Item>[];
  ChatThread? _thread;
  Object? _loadError;
  int _peerReadSeq = 0;
  bool _hasOlder = false;
  bool _loadingOlder = false;
  bool _polling = false;
  Timer? _poll;

  String get _me {
    final a = ref.read(authControllerProvider);
    return a is AuthLoggedIn ? a.user.id : '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(socialApiProvider);
    setState(() => _loadError = null);
    try {
      final thread = await api.thread(widget.chatId);
      final page = await api.messages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _items
          ..clear()
          ..addAll(page.messages.map(_Item.fromServer));
        _peerReadSeq = page.peerLastReadSeq;
        _hasOlder = page.messages.length >= ChatThreadScreen.pageSize;
      });
      _markRead();
      _poll?.cancel();
      _poll = Timer.periodic(ChatThreadScreen.pollEvery, (_) => _fetchNewer());
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  int get _lastSeq => _items.fold(0, (m, i) => (i.seq ?? 0) > m ? i.seq! : m);

  Future<void> _fetchNewer() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final page = await ref.read(socialApiProvider).messages(widget.chatId, after: _lastSeq);
      if (!mounted) return;
      final fromPeer = page.messages.any((m) => m.senderId != _me);
      setState(() {
        _peerReadSeq = page.peerLastReadSeq;
        for (final m in page.messages) {
          _merge(m);
        }
      });
      if (fromPeer) _markRead();
    } catch (_) {
      // offline or transient; the next tick retries
    } finally {
      _polling = false;
    }
  }

  /// Replaces our optimistic copy (matched by client id) or appends.
  void _merge(ChatMessage m) {
    final i = _items.indexWhere((x) => x.senderId == m.senderId && x.clientId == m.clientMessageId);
    if (i >= 0) {
      _items[i] = _Item.fromServer(m);
    } else if (!_items.any((x) => x.seq == m.seq)) {
      _items.add(_Item.fromServer(m));
    }
  }

  Future<void> _loadOlder() async {
    final first = _items.where((i) => i.seq != null).firstOrNull?.seq;
    if (first == null || _loadingOlder) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await ref.read(socialApiProvider).messages(widget.chatId, before: first);
      if (!mounted) return;
      setState(() {
        _items.insertAll(0, page.messages.map(_Item.fromServer));
        _hasOlder = page.messages.length >= ChatThreadScreen.pageSize;
      });
    } catch (_) {
      // leave the button so they can try again
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await ref.read(socialApiProvider).markRead(widget.chatId);
      ref.read(chatUnreadProvider.notifier).refresh();
    } catch (_) {}
  }

  void _send() {
    final body = _composer.text.trim();
    if (body.isEmpty) return;
    final item = _Item(
      clientId: const Uuid().v4(),
      senderId: _me,
      body: body,
      at: DateTime.now(),
      delivery: _Delivery.sending,
    );
    _composer.clear();
    setState(() => _items.add(item));
    _deliver(item);
  }

  Future<void> _deliver(_Item item) async {
    try {
      final m = await ref.read(socialApiProvider).send(widget.chatId, item.clientId, item.body);
      if (mounted) setState(() => _merge(m));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((x) => x.clientId == item.clientId && x.seq == null);
        if (i >= 0) _items[i] = _items[i].copyWith(delivery: _Delivery.failed);
      });
    }
  }

  void _retry(_Item item) {
    final i = _items.indexOf(item);
    if (i < 0) return;
    final again = item.copyWith(delivery: _Delivery.sending);
    setState(() => _items[i] = again);
    _deliver(again); // same clientId: the server returns the original if it did arrive
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final peer = _thread?.peer;

    return Scaffold(
      backgroundColor: AppColors.forest800,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: Row(
                    children: [
                      PsGlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        label: l10n.backLabel,
                        onTap: () => context.canPop() ? context.pop() : context.go('/chats'),
                      ),
                      const SizedBox(width: AppSpace.m),
                      if (peer != null)
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: '${peer.fullName}, ${l10n.viewProfile}',
                            excludeSemantics: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadii.small),
                              onTap: () => context.push('/people/${peer.id}'),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
                                child: Row(
                                  children: [
                                    PsUserAvatar(name: peer.fullName, avatarUrl: peer.avatarUrl, size: 40),
                                    const SizedBox(width: AppSpace.m),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            peer.fullName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppText.headline.copyWith(color: AppColors.onForest),
                                          ),
                                          if (peer.username != null)
                                            Text(
                                              '@${peer.username}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.caption.copyWith(color: AppColors.onForestMuted),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
                  child: ColoredBox(
                    color: AppColors.canvas,
                    child: Column(
                      children: [
                        Expanded(child: _body(l10n)),
                        if (_thread != null) _composerBar(l10n),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_thread == null && _loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.loadFailed, style: AppText.body),
            const SizedBox(height: AppSpace.m),
            PsButton(
              label: l10n.retryLabel,
              variant: PsButtonVariant.secondary,
              compact: true,
              expand: false,
              onPressed: _load,
            ),
          ],
        ),
      );
    }
    if (_thread == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.forest700, strokeWidth: 2));
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PsUserAvatar(name: _thread!.peer.fullName, avatarUrl: _thread!.peer.avatarUrl, size: 80),
              const SizedBox(height: AppSpace.m),
              Text(l10n.chatEmpty(_thread!.peer.fullName), textAlign: TextAlign.center, style: AppText.headline),
            ],
          ),
        ),
      );
    }

    final me = _me;
    final myLast = _items.lastIndexWhere((i) => i.senderId == me);
    final count = _items.length + (_hasOlder ? 1 : 0);
    return ListView.builder(
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: count,
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Center(
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, AppSpace.minTouch)),
              onPressed: _loadingOlder ? null : _loadOlder,
              child: Text(l10n.loadEarlier, style: AppText.label.copyWith(color: AppColors.forest700)),
            ),
          );
        }
        final i = _items.length - 1 - index;
        final item = _items[i];
        final prev = i > 0 ? _items[i - 1] : null;
        final newDay = prev == null || !DateUtils.isSameDay(prev.at, item.at);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                child: Text(
                  DateFormat.yMMMEd(l10n.localeName).format(item.at),
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ),
            _Bubble(
              item: item,
              mine: item.senderId == me,
              peerName: _thread!.peer.fullName,
              status: item.senderId != me
                  ? null
                  : switch (item.delivery) {
                      _Delivery.failed => l10n.notSentRetry,
                      _Delivery.sending when i == myLast => l10n.sendingLabel,
                      _Delivery.sent when i == myLast && (item.seq ?? 0) <= _peerReadSeq => l10n.seenLabel,
                      _ => null,
                    },
              onRetry: item.delivery == _Delivery.failed ? () => _retry(item) : null,
            ),
          ],
        );
      },
    );
  }

  Widget _composerBar(AppLocalizations l10n) {
    if (_thread!.blocked) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Row(
            children: [
              const Icon(Icons.block_rounded, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: AppSpace.s),
              Expanded(child: Text(l10n.chatBlockedNotice, style: AppText.footnote)),
            ],
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppText.bodyStrong,
                  cursorColor: AppColors.forest600,
                  decoration: InputDecoration(
                    hintText: l10n.messageHint,
                    counterText: '',
                    fillColor: AppColors.canvas,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _composer,
                builder: (context, value, _) {
                  final canSend = value.text.trim().isNotEmpty;
                  return Semantics(
                    button: true,
                    enabled: canSend,
                    label: l10n.sendLabel,
                    excludeSemantics: true,
                    child: SizedBox.square(
                      dimension: AppSpace.minTouch,
                      child: Material(
                        color: canSend ? AppColors.forest700 : AppColors.stroke,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: canSend ? _send : null,
                          child: Icon(
                            Icons.send_rounded,
                            size: 22,
                            color: canSend ? AppColors.onForest : AppColors.inkSubtle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.item, required this.mine, required this.peerName, this.status, this.onRetry});

  final _Item item;
  final bool mine;
  final String peerName;
  final String? status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = DateFormat.Hm(l10n.localeName).format(item.at);
    final failed = item.delivery == _Delivery.failed;
    final fg = mine ? AppColors.onForest : AppColors.ink;
    const r = Radius.circular(20);
    const tail = Radius.circular(6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '${mine ? l10n.messageFromYou(item.body) : l10n.messageFromPeer(peerName, item.body)}, $time',
            button: onRetry != null,
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
              child: Material(
                color: mine ? (failed ? AppColors.danger : AppColors.forest700) : AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: r,
                    topRight: r,
                    bottomLeft: mine ? r : tail,
                    bottomRight: mine ? tail : r,
                  ),
                  side: mine ? BorderSide.none : const BorderSide(color: AppColors.stroke),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onRetry,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.body, style: AppText.body.copyWith(color: fg)),
                        const SizedBox(height: 2),
                        Text(
                          time,
                          style: AppText.caption.copyWith(
                            color: mine ? AppColors.onForestMuted : AppColors.inkSubtle,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : (item.delivery == _Delivery.sending ? Icons.schedule_rounded : Icons.done_all_rounded),
                    size: 14,
                    color: failed ? AppColors.danger : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(status!, style: AppText.caption.copyWith(color: failed ? AppColors.danger : AppColors.inkMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
