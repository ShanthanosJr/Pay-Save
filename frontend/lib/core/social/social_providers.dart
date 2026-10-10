import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'social_api.dart';
import 'social_models.dart';

final socialApiProvider = Provider<SocialApi>((ref) => SocialApi(ref.watch(apiClientProvider)));

/// Avatar URLs are versioned, so a URL's bytes never change and stay cached.
final avatarBytesProvider = FutureProvider.family<Uint8List?, String>(
  (ref, url) => ref.watch(socialApiProvider).avatarBytes(url),
);

final publicProfileProvider = FutureProvider.autoDispose.family<PublicProfile, String>(
  (ref, id) => ref.watch(socialApiProvider).profile(id),
);

final suggestionsProvider = FutureProvider.autoDispose<List<Suggestion>>(
  (ref) => ref.watch(socialApiProvider).suggestions(),
);

final inboxProvider = FutureProvider.autoDispose<List<ChatSummary>>((ref) => ref.watch(socialApiProvider).inbox());

final peopleSearchProvider = FutureProvider.autoDispose.family<List<Person>, String>(
  (ref, q) => ref.watch(socialApiProvider).search(q),
);

enum PeopleListKind { followers, following, pals }

final peopleListProvider = FutureProvider.autoDispose.family<List<Person>, (String, PeopleListKind)>((ref, key) {
  final api = ref.watch(socialApiProvider);
  return switch (key.$2) {
    PeopleListKind.followers => api.followers(key.$1),
    PeopleListKind.following => api.following(key.$1),
    PeopleListKind.pals => api.pals(key.$1),
  };
});

/// Unread message count for the nav badge, polled while signed in
/// (there is no push channel yet).
final chatUnreadProvider = NotifierProvider<ChatUnread, int>(ChatUnread.new);

class ChatUnread extends Notifier<int> {
  static const pollEvery = Duration(seconds: 20);

  @override
  int build() {
    final signedIn = ref.watch(authControllerProvider) is AuthLoggedIn;
    if (!signedIn) return 0;
    final timer = Timer.periodic(pollEvery, (_) => refresh());
    ref.onDispose(timer.cancel);
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    try {
      final n = await ref.read(socialApiProvider).unreadCount();
      if (ref.mounted) state = n;
    } catch (_) {
      // keep the last count; the next poll retries
    }
  }
}

final palRequestsProvider = FutureProvider.autoDispose<PalRequests>((ref) => ref.watch(socialApiProvider).palRequests());

/// Pal requests waiting for me, for badges; polled like [chatUnreadProvider].
final palRequestCountProvider = NotifierProvider<PalRequestCount, int>(PalRequestCount.new);

class PalRequestCount extends Notifier<int> {
  @override
  int build() {
    final signedIn = ref.watch(authControllerProvider) is AuthLoggedIn;
    if (!signedIn) return 0;
    final timer = Timer.periodic(ChatUnread.pollEvery, (_) => refresh());
    ref.onDispose(timer.cancel);
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    try {
      final n = await ref.read(socialApiProvider).palRequestCount();
      if (ref.mounted) state = n;
    } catch (_) {
      // keep the last count; the next poll retries
    }
  }
}

/// After any pal action: refresh both profiles, requests, suggestions and badges.
void refreshAfterPalChange(WidgetRef ref, String otherId, {bool keepSuggestions = false}) {
  ref.invalidate(publicProfileProvider(otherId));
  final me = ref.read(authControllerProvider);
  if (me is AuthLoggedIn) ref.invalidate(publicProfileProvider(me.user.id));
  ref.invalidate(palRequestsProvider);
  if (!keepSuggestions) ref.invalidate(suggestionsProvider);
  ref.invalidate(peopleListProvider);
  ref.read(palRequestCountProvider.notifier).refresh();
}

/// Photo bytes for a chat message, fetched once per message.
final chatMediaProvider = FutureProvider.family<Uint8List, String>((ref, url) {
  return ref.watch(socialApiProvider).mediaBytes(url);
});
