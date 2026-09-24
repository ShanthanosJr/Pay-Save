import 'package:dio/dio.dart';
import 'package:pay_and_save/core/api/api_exception.dart';
import 'package:pay_and_save/core/auth/auth_api.dart';
import 'package:pay_and_save/core/auth/auth_models.dart';
import 'package:pay_and_save/core/auth/token_store.dart';

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
}
