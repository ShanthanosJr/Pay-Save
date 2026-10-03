import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import 'social_models.dart';

/// People directory, follows, blocks and 1:1 chat.
class SocialApi {
  SocialApi(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  List<Map<String, dynamic>> _list(Object? data) => [for (final e in data as List<dynamic>) e as Map<String, dynamic>];

  Future<List<Person>> search(String q) => _call(() async {
    final r = await _dio.get<List<dynamic>>('/people/search', queryParameters: {'q': q});
    return _list(r.data).map(Person.fromJson).toList();
  });

  Future<List<Suggestion>> suggestions() => _call(() async {
    final r = await _dio.get<List<dynamic>>('/people/suggestions');
    return _list(r.data).map(Suggestion.fromJson).toList();
  });

  Future<PublicProfile> profile(String id) => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('/people/$id');
    return PublicProfile.fromJson(r.data!);
  });

  Future<List<Person>> followers(String id) => _call(() async {
    final r = await _dio.get<List<dynamic>>('/people/$id/followers');
    return _list(r.data).map(Person.fromJson).toList();
  });

  Future<List<Person>> following(String id) => _call(() async {
    final r = await _dio.get<List<dynamic>>('/people/$id/following');
    return _list(r.data).map(Person.fromJson).toList();
  });

  Future<PublicProfile> setFollowing(String id, bool follow) => _call(() async {
    final r = follow
        ? await _dio.put<Map<String, dynamic>>('/people/$id/follow')
        : await _dio.delete<Map<String, dynamic>>('/people/$id/follow');
    return PublicProfile.fromJson(r.data!);
  });

  Future<void> setBlocked(String id, bool block) => _call(() async {
    if (block) {
      await _dio.put<void>('/people/$id/block');
    } else {
      await _dio.delete<void>('/people/$id/block');
    }
  });

  Future<List<ChatSummary>> inbox() => _call(() async {
    final r = await _dio.get<List<dynamic>>('/chats');
    return _list(r.data).map(ChatSummary.fromJson).toList();
  });

  Future<int> unreadCount() => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('/chats/unread');
    return (r.data!['count'] as num).toInt();
  });

  /// Gets or creates the one conversation with [userId].
  Future<ChatThread> openChat(String userId) => _call(() async {
    final r = await _dio.post<Map<String, dynamic>>('/chats', data: {'userId': userId});
    return ChatThread.fromJson(r.data!);
  });

  Future<ChatThread> thread(String chatId) => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('/chats/$chatId');
    return ChatThread.fromJson(r.data!);
  });

  Future<MessagePage> messages(String chatId, {int? before, int? after}) => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/chats/$chatId/messages',
      queryParameters: {'before': ?before, 'after': ?after},
    );
    return MessagePage.fromJson(r.data!);
  });

  /// [clientMessageId] is generated once per message; a retry must reuse it.
  Future<ChatMessage> send(String chatId, String clientMessageId, String body) => _call(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/chats/$chatId/messages',
      data: {'clientMessageId': clientMessageId, 'body': body},
    );
    return ChatMessage.fromJson(r.data!);
  });

  Future<void> markRead(String chatId) => _call(() async {
    await _dio.post<void>('/chats/$chatId/read');
  });

  /// Profile photo bytes for a server-relative avatar URL; null when absent.
  Future<Uint8List?> avatarBytes(String url) async {
    try {
      final r = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final data = r.data;
      return data == null ? null : Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }
}
