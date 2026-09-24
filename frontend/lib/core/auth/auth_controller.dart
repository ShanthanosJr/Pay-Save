import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_config.dart';
import '../api/api_exception.dart';
import 'auth_api.dart';
import 'auth_models.dart';
import 'token_store.dart';

sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

class AuthLoggedIn extends AuthState {
  const AuthLoggedIn(this.user);
  final UserProfile user;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = buildApiClient(
    baseUrl: apiBaseUrl,
    tokens: ref.watch(tokenStoreProvider),
    onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired(),
  );
  return AuthApi(dio);
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthUnknown();
  }

  TokenStore get _tokens => ref.read(tokenStoreProvider);
  AuthApi get _api => ref.read(authApiProvider);

  Future<void> _restore() async {
    final tokens = await _tokens.read();
    if (tokens == null) {
      state = const AuthLoggedOut();
      return;
    }
    try {
      state = AuthLoggedIn(await _api.me());
    } on ApiException catch (e) {
      if (e.isNetwork && tokens.accessToken.isNotEmpty) {
        state = const AuthLoggedOut();
      } else {
        await _tokens.clear();
        state = const AuthLoggedOut();
      }
    }
  }

  Future<void> login(String identifier, String password) async {
    final session = await _api.login(identifier, password);
    await _tokens.save(session.tokens);
    state = AuthLoggedIn(session.user);
  }

  Future<void> completeRegistration(AuthSession session) async {
    await _tokens.save(session.tokens);
    state = AuthLoggedIn(session.user);
  }

  Future<void> refreshProfile() async {
    if (state is! AuthLoggedIn) return;
    state = AuthLoggedIn(await _api.me());
  }

  void markEmailVerified() {
    final s = state;
    if (s is AuthLoggedIn) state = AuthLoggedIn(s.user.copyWith(emailVerified: true));
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (e) {
      debugPrint('logout request failed: $e');
    }
    await _tokens.clear();
    state = const AuthLoggedOut();
  }

  void sessionExpired() {
    state = const AuthLoggedOut();
  }
}
