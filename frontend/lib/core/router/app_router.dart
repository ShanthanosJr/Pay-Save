import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/register_draft.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_credentials_screen.dart';
import '../../features/auth/screens/register_details_screen.dart';
import '../../features/auth/screens/register_phone_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/circle/circle_screen.dart';
import '../../features/circle/create_circle_screen.dart';
import '../../features/circle/join_circle_screen.dart';
import '../../features/circle/verify_queue_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/member_home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (prev, next) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      const signedInPaths = {'/home', '/circle', '/history', '/profile'};
      final signedInArea = signedInPaths.contains(loc) || loc.startsWith('/circles/');

      if (auth is AuthUnknown) return loc == '/splash' ? null : '/splash';
      if (auth is AuthLoggedIn) return signedInArea ? null : '/home';

      if (signedInArea || loc == '/splash') return '/';
      final draft = ref.read(registerDraftProvider);
      if (loc == '/register/phone' && draft.fullName.isEmpty) return '/register/details';
      if (loc == '/register/credentials' && draft.phoneVerificationToken.isEmpty) {
        return '/register/details';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const _Splash()),
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register/details', builder: (context, state) => const RegisterDetailsScreen()),
      GoRoute(path: '/register/phone', builder: (context, state) => const RegisterPhoneScreen()),
      GoRoute(path: '/register/credentials', builder: (context, state) => const RegisterCredentialsScreen()),
      GoRoute(path: '/circles/new', builder: (context, state) => const CreateCircleScreen()),
      GoRoute(path: '/circles/join', builder: (context, state) => const JoinCircleScreen()),
      GoRoute(
        path: '/circles/:id/verify',
        builder: (context, state) => VerifyQueueScreen(circleId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const MemberHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/circle', builder: (context, state) => const CircleScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.headerGradient),
          child: Center(child: CircularProgressIndicator(color: AppColors.onForest, strokeWidth: 2)),
        ),
      );
}
