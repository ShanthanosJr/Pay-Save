import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../auth/auth_controller.dart';

/// One inbox row. The server sends a `kind` and its numbers; the words are
/// chosen here in the reader's language.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.read,
    required this.payload,
    this.circleId,
    this.circleName,
  });

  final String id;
  final String kind;
  final DateTime createdAt;
  final bool read;
  final Map<String, dynamic> payload;
  final String? circleId;
  final String? circleName;

  int? intOf(String key) => (payload[key] as num?)?.toInt();
  String? textOf(String key) => payload[key] as String?;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        kind: j['kind'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        read: j['read'] as bool? ?? false,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        circleId: j['circleId'] as String?,
        circleName: j['circleName'] as String?,
      );
}

class Inbox {
  const Inbox({required this.items, required this.unread});
  final List<AppNotification> items;
  final int unread;
}

class NotificationsApi {
  NotificationsApi(this._dio);

  final Dio _dio;

  Future<Inbox> list() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/notifications');
      return Inbox(
        items: [for (final i in r.data!['items'] as List) AppNotification.fromJson(i as Map<String, dynamic>)],
        unread: (r.data!['unread'] as num).toInt(),
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Marks everything read when [ids] is omitted.
  Future<void> markRead({List<String>? ids}) async {
    try {
      await _dio.post<void>('/notifications/read', data: {'ids': ?ids});
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final notificationsApiProvider = Provider<NotificationsApi>((ref) => NotificationsApi(ref.watch(apiClientProvider)));

/// Polled with the other badges so the bell stays current.
final inboxProvider = FutureProvider<Inbox>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthLoggedIn) return const Inbox(items: [], unread: 0);
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(notificationsApiProvider).list();
});
