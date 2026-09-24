import 'package:dio/dio.dart';
import '../api/api_exception.dart';
import 'auth_models.dart';
import 'token_store.dart';

/// Builds the Dio used by the app: attaches the bearer token and, on a 401,
/// rotates the refresh token once and retries the request.
Dio buildApiClient({
  required String baseUrl,
  required TokenStore tokens,
  required void Function() onSessionExpired,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    contentType: Headers.jsonContentType,
  ));
  final refresher = Dio(BaseOptions(baseUrl: baseUrl, contentType: Headers.jsonContentType));

  Future<AuthTokens?>? inflight;
  Future<AuthTokens?> refresh() async {
    final current = await tokens.read();
    if (current == null) return null;
    try {
      final res = await refresher.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': current.refreshToken},
      );
      final next = AuthTokens.fromJson(res.data!);
      await tokens.save(next);
      return next;
    } catch (_) {
      await tokens.clear();
      return null;
    }
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (!options.path.startsWith('/auth/')) {
        final t = await tokens.read();
        if (t != null) options.headers['Authorization'] = 'Bearer ${t.accessToken}';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      final req = error.requestOptions;
      final isAuthCall = req.path.startsWith('/auth/');
      if (error.response?.statusCode == 401 && !isAuthCall && req.extra['retried'] != true) {
        inflight ??= refresh().whenComplete(() => inflight = null);
        final next = await inflight;
        if (next == null) {
          onSessionExpired();
          return handler.next(error);
        }
        req.extra['retried'] = true;
        req.headers['Authorization'] = 'Bearer ${next.accessToken}';
        try {
          return handler.resolve(await dio.fetch<dynamic>(req));
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
      handler.next(error);
    },
  ));
  return dio;
}

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<OtpChallenge> requestPhoneOtp(String phone) => _call(() async {
        final r = await _dio.post<Map<String, dynamic>>('/auth/otp/request', data: {'phone': phone});
        return OtpChallenge.fromJson(r.data!);
      });

  Future<String> verifyPhoneOtp(String phone, String code) => _call(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/auth/otp/verify',
          data: {'phone': phone, 'code': code},
        );
        return r.data!['phoneVerificationToken'] as String;
      });

  Future<AuthSession> register({
    required String fullName,
    required int age,
    required String nic,
    required String phone,
    required String email,
    required String password,
    required String phoneVerificationToken,
  }) =>
      _call(() async {
        final r = await _dio.post<Map<String, dynamic>>('/auth/register', data: {
          'fullName': fullName,
          'age': age,
          'nic': nic,
          'phone': phone,
          'email': email,
          'password': password,
          'phoneVerificationToken': phoneVerificationToken,
        });
        return AuthSession.fromJson(r.data!);
      });

  Future<AuthSession> login(String identifier, String password) => _call(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'identifier': identifier, 'password': password},
        );
        return AuthSession.fromJson(r.data!);
      });

  Future<void> logout() => _call(() async {
        await _dio.post<void>('/auth/logout');
      });

  Future<UserProfile> me() => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/users/me');
        return UserProfile.fromJson(r.data!);
      });

  Future<OtpChallenge> requestEmailOtp() => _call(() async {
        final r = await _dio.post<Map<String, dynamic>>('/users/me/email/otp');
        return OtpChallenge.fromJson(r.data!);
      });

  Future<void> verifyEmailOtp(String code) => _call(() async {
        await _dio.post<void>('/users/me/email/verify', data: {'code': code});
      });

  Future<void> updateLanguage(String language) => _call(() async {
        await _dio.patch<void>('/users/me', data: {'language': language});
      });
}
