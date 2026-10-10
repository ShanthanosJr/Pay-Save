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

  Future<List<Person>> pals(String id) => _call(() async {
    final r = await _dio.get<List<dynamic>>('/people/$id/pals');
    return _list(r.data).map(Person.fromJson).toList();
  });

  /// Sends a pal request; if they already asked me, we become pals at once.
  Future<PublicProfile> requestPal(String id) => _call(() async {
    final r = await _dio.put<Map<String, dynamic>>('/people/$id/pal');
    return PublicProfile.fromJson(r.data!);
  });

  /// Withdraws my pending request, or removes an existing pal.
  Future<PublicProfile> endPal(String id) => _call(() async {
    final r = await _dio.delete<Map<String, dynamic>>('/people/$id/pal');
    return PublicProfile.fromJson(r.data!);
  });

  Future<PublicProfile> acceptPal(String id) => _call(() async {
    final r = await _dio.post<Map<String, dynamic>>('/people/$id/pal/accept');
    return PublicProfile.fromJson(r.data!);
  });

  /// Declines quietly: the sender is not told.
  Future<PublicProfile> ignorePal(String id) => _call(() async {
    final r = await _dio.post<Map<String, dynamic>>('/people/$id/pal/ignore');
    return PublicProfile.fromJson(r.data!);
  });

  Future<PalRequests> palRequests() => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('/people/pal-requests');
    return PalRequests.fromJson(r.data!);
  });

  Future<int> palRequestCount() => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('/people/pal-requests/count');
    return (r.data!['received'] as num).toInt();
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

  /// A photo or short video. [clientMessageId] makes a retry safe.
  Future<ChatMessage> sendMedia(
    String chatId,
    String clientMessageId,
    Uint8List bytes,
    String filename, {
    String caption = '',
  }) => _call(() async {
    final form = FormData.fromMap({
      'clientMessageId': clientMessageId,
      if (caption.isNotEmpty) 'caption': caption,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final r = await _dio.post<Map<String, dynamic>>(
      '/chats/$chatId/media',
      data: form,
      options: Options(sendTimeout: const Duration(minutes: 2), receiveTimeout: const Duration(minutes: 2)),
    );
    return ChatMessage.fromJson(r.data!);
  });

  /// Photo or video bytes for a message; participants only.
  Future<Uint8List> mediaBytes(String url) => _call(() async {
    final r = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 2)),
    );
    return Uint8List.fromList(r.data!);
  });

  /// Takes my own message back for both of us.
  Future<void> deleteMessage(String chatId, String messageId) => _call(() async {
    await _dio.delete<void>('/chats/$chatId/messages/$messageId');
  });

  /// [emoji] null removes my reaction.
  Future<ChatMessage> react(String chatId, String messageId, String? emoji) => _call(() async {
    final r = await _dio.put<Map<String, dynamic>>(
      '/chats/$chatId/messages/$messageId/reaction',
      data: {'emoji': emoji},
    );
    return ChatMessage.fromJson(r.data!);
  });

  Future<ChatMessage> star(String chatId, String messageId, bool starred) => _call(() async {
    final r = await _dio.put<Map<String, dynamic>>(
      '/chats/$chatId/messages/$messageId/star',
      data: {'starred': starred},
    );
    return ChatMessage.fromJson(r.data!);
  });

  /// Pin or favourite a chat in my own inbox.
  Future<void> setChatFlags(String chatId, {bool? pinned, bool? favourite}) => _call(() async {
    await _dio.patch<void>('/chats/$chatId', data: {'pinned': ?pinned, 'favourite': ?favourite});
  });

  /// Removes the chat and its history from my inbox only.
  Future<void> clearChat(String chatId) => _call(() async {
    await _dio.delete<void>('/chats/$chatId');
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
