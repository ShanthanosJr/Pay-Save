import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'circle_models.dart';
import 'circles_api.dart';

final circlesApiProvider = Provider<CirclesApi>((ref) => CirclesApi(ref.watch(apiClientProvider)));

/// Everything here is keyed to the signed-in user, so it resets on logout.
final myCirclesProvider = FutureProvider<List<CircleSummary>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthLoggedIn) return const [];
  final circles = await ref.watch(circlesApiProvider).list();
  const rank = {CircleStatus.active: 0, CircleStatus.draft: 1, CircleStatus.completed: 2};
  return [...circles]..sort((a, b) => rank[a.status]!.compareTo(rank[b.status]!));
});

class SelectedCircleNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authControllerProvider);
    return null;
  }

  void select(String id) => state = id;
}

final selectedCircleIdProvider = NotifierProvider<SelectedCircleNotifier, String?>(SelectedCircleNotifier.new);

/// The circle the app is focused on: the explicit choice, else the first
/// active (then draft) circle.
final activeCircleProvider = Provider<AsyncValue<CircleSummary?>>((ref) {
  final picked = ref.watch(selectedCircleIdProvider);
  return ref.watch(myCirclesProvider).whenData((circles) {
    if (circles.isEmpty) return null;
    return circles.where((c) => c.id == picked).firstOrNull ?? circles.first;
  });
});

final circleDetailProvider = FutureProvider.family<CircleDetail, String>((ref, id) async {
  ref.watch(authControllerProvider);
  return ref.watch(circlesApiProvider).detail(id);
});

final ledgerProvider = FutureProvider.family<List<LedgerEntry>, ({String circleId, bool all})>((ref, key) async {
  ref.watch(authControllerProvider);
  return ref.watch(circlesApiProvider).ledger(key.circleId, all: key.all);
});

final verifyQueueProvider = FutureProvider.family<List<VerifyItem>, String>((ref, id) async {
  ref.watch(authControllerProvider);
  return ref.watch(circlesApiProvider).verifyQueue(id);
});

/// Invitations waiting for me; polled with the other badges.
final myInvitationsProvider = FutureProvider<List<MyInvitation>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthLoggedIn) return const [];
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(circlesApiProvider).myInvitations();
});

final payToProvider = FutureProvider.autoDispose.family<PayTo, String>((ref, circleId) async {
  ref.watch(authControllerProvider);
  return ref.watch(circlesApiProvider).payTo(circleId);
});

final invitablePalsProvider = FutureProvider.autoDispose.family<(int, List<InvitablePal>), String>((ref, circleId) {
  return ref.watch(circlesApiProvider).invitablePals(circleId);
});

/// Refreshes every view of one circle after a write.
void refreshCircle(WidgetRef ref, String circleId) {
  ref.invalidate(myCirclesProvider);
  ref.invalidate(circleDetailProvider(circleId));
  ref.invalidate(ledgerProvider((circleId: circleId, all: false)));
  ref.invalidate(ledgerProvider((circleId: circleId, all: true)));
  ref.invalidate(verifyQueueProvider(circleId));
  ref.invalidate(payToProvider(circleId));
  ref.invalidate(invitablePalsProvider(circleId));
}
