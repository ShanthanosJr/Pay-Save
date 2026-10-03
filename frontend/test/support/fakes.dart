import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pay_and_save/core/api/api_exception.dart';
import 'package:pay_and_save/core/auth/auth_api.dart';
import 'package:pay_and_save/core/auth/auth_models.dart';
import 'package:pay_and_save/core/auth/token_store.dart';
import 'package:pay_and_save/core/social/social_api.dart';
import 'package:pay_and_save/core/social/social_models.dart';

class MemoryTokenStore implements TokenStore {
  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> save(AuthTokens t) async => tokens = t;

  @override
  Future<void> clear() async => tokens = null;
}

const testUser = UserProfile(
  id: 'u1',
  fullName: 'Nadeeshi Perera',
  age: 29,
  email: 'nadeeshi@example.com',
  emailVerified: false,
  phoneMasked: '+9477*****21',
  phoneVerified: true,
  nicMasked: '*********V',
  language: 'en',
);

const testTokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

class FakeAuthApi extends AuthApi {
  FakeAuthApi() : super(Dio());

  final calls = <String>[];
  String? lastLoginIdentifier;
  Map<String, dynamic>? lastRegister;
  bool loginFails = false;
  bool emailVerified = false;

  @override
  Future<OtpChallenge> requestPhoneOtp(String phone) async {
    calls.add('otp:$phone');
    return const OtpChallenge(resendAfterSeconds: 30, devCode: '123456');
  }

  @override
  Future<String> verifyPhoneOtp(String phone, String code) async {
    calls.add('verify:$code');
    if (code != '123456') throw ApiException(code: 'INVALID_CODE', statusCode: 400);
    return 'phone-token';
  }

  @override
  Future<AuthSession> register({
    required String fullName,
    required int age,
    required String nic,
    required String phone,
    required String email,
    required String password,
    required String phoneVerificationToken,
  }) async {
    lastRegister = {
      'fullName': fullName,
      'age': age,
      'nic': nic,
      'phone': phone,
      'email': email,
      'password': password,
      'token': phoneVerificationToken,
    };
    return const AuthSession(user: testUser, tokens: testTokens);
  }

  @override
  Future<AuthSession> login(String identifier, String password) async {
    lastLoginIdentifier = identifier;
    if (loginFails) throw ApiException(code: 'INVALID_CREDENTIALS', statusCode: 401);
    return const AuthSession(user: testUser, tokens: testTokens);
  }

  @override
  Future<UserProfile> me() async => testUser;

  @override
  Future<OtpChallenge> requestEmailOtp() async =>
      const OtpChallenge(resendAfterSeconds: 30, devCode: '654321');

  @override
  Future<void> verifyEmailOtp(String code) async {
    if (code != '654321') throw ApiException(code: 'INVALID_CODE', statusCode: 400);
    emailVerified = true;
  }

  @override
  Future<void> logout() async {}

  UserProfile current = testUser;
  Map<String, Object?>? lastProfilePatch;
  Uint8List? uploadedAvatar;

  @override
  Future<UserProfile> updateProfile({String? fullName, int? age, String? username, String? bio, String? city}) async {
    lastProfilePatch = {'fullName': ?fullName, 'age': ?age, 'username': ?username, 'bio': ?bio, 'city': ?city};
    if (username == 'taken') throw ApiException(code: 'USERNAME_TAKEN', statusCode: 409);
    current = UserProfile(
      id: current.id,
      fullName: fullName ?? current.fullName,
      age: age ?? current.age,
      email: current.email,
      emailVerified: current.emailVerified,
      phoneMasked: current.phoneMasked,
      phoneVerified: current.phoneVerified,
      nicMasked: current.nicMasked,
      language: current.language,
      username: username == null ? current.username : (username.isEmpty ? null : username),
      bio: bio == null ? current.bio : (bio.isEmpty ? null : bio),
      city: city == null ? current.city : (city.isEmpty ? null : city),
      avatarUrl: current.avatarUrl,
    );
    return current;
  }

  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes, String filename) async {
    uploadedAvatar = bytes;
    return current = UserProfile(
      id: current.id,
      fullName: current.fullName,
      age: current.age,
      email: current.email,
      emailVerified: current.emailVerified,
      phoneMasked: current.phoneMasked,
      phoneVerified: current.phoneVerified,
      nicMasked: current.nicMasked,
      language: current.language,
      username: current.username,
      avatarUrl: '/users/u1/avatar?v=1',
    );
  }
}

final kamala = PublicProfile(
  person: const Person(id: 'u2', fullName: 'Kamala Silva', username: 'kamala', verified: true, followsYou: true),
  bio: 'Saving for my daughter\'s school fees',
  city: 'Galle',
  memberSince: DateTime(2026, 3, 1),
  followersCount: 4,
  followingCount: 2,
  sharedCircles: 1,
);

/// In-memory people + chat backend.
class FakeSocialApi extends SocialApi {
  FakeSocialApi() : super(Dio());

  final followCalls = <(String, bool)>[];
  final sentIds = <String>[];
  final searches = <String>[];
  bool failNextSend = false;
  int unread = 0;
  int _seq = 10;
  final messagesByChat = <String, List<ChatMessage>>{
    'c1': [
      ChatMessage(seq: 1, senderId: 'u2', clientMessageId: 'x1', body: 'Did you pay this month?', createdAt: DateTime(2026, 9, 20, 9, 30)),
    ],
  };

  PublicProfile profileOf(String id) => id == 'u1'
      ? PublicProfile(
          person: const Person(id: 'u1', fullName: 'Nadeeshi Perera', verified: true),
          memberSince: DateTime(2026, 1, 5),
          followersCount: 12,
          followingCount: 7,
          sharedCircles: 1,
          isMe: true,
        )
      : kamala;

  @override
  Future<List<Person>> search(String q) async {
    searches.add(q);
    return q.toLowerCase().contains('kam') ? [kamala.person] : [];
  }

  @override
  Future<List<Suggestion>> suggestions() async => [
        const Suggestion(
          person: Person(id: 'u3', fullName: 'Ruwan Jayasuriya'),
          reason: SuggestionReason.sharedCircle,
          sharedCircles: 1,
        ),
      ];

  @override
  Future<PublicProfile> profile(String id) async => profileOf(id);

  @override
  Future<List<Person>> followers(String id) async => [kamala.person];

  @override
  Future<List<Person>> following(String id) async => [];

  @override
  Future<PublicProfile> setFollowing(String id, bool follow) async {
    followCalls.add((id, follow));
    return profileOf(id);
  }

  @override
  Future<void> setBlocked(String id, bool block) async {}

  @override
  Future<List<ChatSummary>> inbox() async => [
        for (final e in messagesByChat.entries)
          ChatSummary(id: e.key, peer: kamala.person, lastMessage: e.value.last, unread: unread),
      ];

  @override
  Future<int> unreadCount() async => unread;

  @override
  Future<ChatThread> openChat(String userId) async => ChatThread(id: 'c1', peer: kamala.person);

  @override
  Future<ChatThread> thread(String chatId) async => ChatThread(id: chatId, peer: kamala.person);

  @override
  Future<MessagePage> messages(String chatId, {int? before, int? after}) async {
    final all = messagesByChat[chatId] ?? [];
    final page = after == null ? all : all.where((m) => m.seq > after).toList();
    return MessagePage(messages: page, peerLastReadSeq: 0);
  }

  @override
  Future<ChatMessage> send(String chatId, String clientMessageId, String body) async {
    sentIds.add(clientMessageId);
    if (failNextSend) {
      failNextSend = false;
      throw ApiException(code: 'NETWORK');
    }
    final list = messagesByChat.putIfAbsent(chatId, () => []);
    final existing = list.where((m) => m.clientMessageId == clientMessageId).firstOrNull;
    if (existing != null) return existing;
    final m = ChatMessage(seq: ++_seq, senderId: 'u1', clientMessageId: clientMessageId, body: body, createdAt: DateTime.now());
    list.add(m);
    return m;
  }

  @override
  Future<void> markRead(String chatId) async => unread = 0;

  @override
  Future<Uint8List?> avatarBytes(String url) async => null;
}

class FakeImagePicker extends ImagePicker {
  @override
  bool supportsImageSource(ImageSource source) => true;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      XFile.fromData(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]), name: 'me.jpg');
}
