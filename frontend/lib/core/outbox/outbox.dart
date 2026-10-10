import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../auth/auth_controller.dart';
import '../circles/circle_models.dart';
import '../circles/circles_providers.dart';
import 'outbox_open_stub.dart' if (dart.library.io) 'outbox_open_native.dart';
import 'outbox_store.dart';

export 'outbox_store.dart';

final outboxStoreProvider = Provider<OutboxStore>((ref) => openOutboxStore());

final outboxProvider = NotifierProvider<OutboxController, List<PendingContribution>>(OutboxController.new);

/// Records payments, keeping them on the phone when there is no signal and
/// sending them again until the server answers (NFR-03).
class OutboxController extends Notifier<List<PendingContribution>> {
  static const _firstRetry = Duration(seconds: 5);
  static const _maxRetry = Duration(minutes: 1);

  Timer? _timer;
  Duration _delay = _firstRetry;
  bool _syncing = false;
  String? _userId;

  @override
  List<PendingContribution> build() {
    final auth = ref.watch(authControllerProvider);
    _userId = auth is AuthLoggedIn ? auth.user.id : null;
    ref.onDispose(() => _timer?.cancel());
    if (_userId != null) Future.microtask(_load);
    return const [];
  }

  OutboxStore get _store => ref.read(outboxStoreProvider);

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) return;
    state = await _store.all(userId);
    if (state.any((p) => p.failure == null)) unawaited(sync());
  }

  /// The server's entry, or null when it was saved on this phone instead.
  /// Anything the server refuses is thrown as usual.
  Future<LedgerEntry?> record(PendingContribution p) async {
    try {
      return await _send(p);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await _store.put(p);
      state = [...state.where((x) => x.clientEntryId != p.clientEntryId), p];
      _schedule();
      return null;
    }
  }

  Future<LedgerEntry> _send(PendingContribution p) => ref.read(circlesApiProvider).recordContribution(
        p.circleId,
        cycleNumber: p.cycleNumber,
        method: p.method,
        clientEntryId: p.clientEntryId,
        provider: p.provider,
        receiptReference: p.receiptReference,
        subjectUserId: p.subjectUserId,
        deviceCreatedAt: p.deviceCreatedAt,
      );

  /// Sends everything still waiting. Safe to call at any time.
  Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    _timer?.cancel();
    var offline = false;
    try {
      for (final p in state.where((p) => p.failure == null).toList()) {
        try {
          await _send(p);
          await _drop(p);
        } on ApiException catch (e) {
          if (e.isNetwork) {
            offline = true;
            break;
          }
          // The server answered and will not take it; keep it visible so the
          // member knows this payment is NOT on the record.
          final failed = p.failed(e.code);
          await _store.put(failed);
          state = [for (final x in state) x.clientEntryId == p.clientEntryId ? failed : x];
          _refresh(p.circleId);
        }
      }
    } finally {
      _syncing = false;
    }
    if (offline) {
      _schedule();
    } else {
      _delay = _firstRetry;
    }
  }

  Future<void> discard(String clientEntryId) async {
    await _store.remove(clientEntryId);
    state = state.where((p) => p.clientEntryId != clientEntryId).toList();
  }

  Future<void> _drop(PendingContribution p) async {
    await _store.remove(p.clientEntryId);
    state = state.where((x) => x.clientEntryId != p.clientEntryId).toList();
    _refresh(p.circleId);
  }

  void _refresh(String circleId) {
    ref.invalidate(myCirclesProvider);
    ref.invalidate(circleDetailProvider(circleId));
    ref.invalidate(ledgerProvider((circleId: circleId, all: false)));
    ref.invalidate(ledgerProvider((circleId: circleId, all: true)));
    ref.invalidate(verifyQueueProvider(circleId));
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_delay, sync);
    final next = _delay * 2;
    _delay = next > _maxRetry ? _maxRetry : next;
  }
}
