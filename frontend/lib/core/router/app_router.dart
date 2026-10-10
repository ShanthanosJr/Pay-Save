import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/register_draft.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/community/circle_sharing_screen.dart';
import '../../features/community/community_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/change_password_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/statements/statement_screen.dart';
import '../../features/auth/screens/register_credentials_screen.dart';
import '../../features/auth/screens/register_details_screen.dart';
import '../../features/auth/screens/register_phone_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/chats/chat_thread_screen.dart';
import '../../features/chats/chats_screen.dart';
import '../../features/circle/circle_screen.dart';
import '../../features/circle/create_circle_screen.dart';
import '../../features/circle/join_circle_screen.dart';
import '../../features/circle/verify_queue_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/member_home_screen.dart';
import '../../features/circle/invitation_screen.dart';
import '../../features/circle/invite_pals_screen.dart';
import '../../features/pals/pal_requests_screen.dart';
import '../../features/payouts/add_payment_method_screen.dart';
import '../../features/payouts/payment_methods_screen.dart';
import '../../features/people/people_list_screen.dart';
import '../../features/people/person_profile_screen.dart';
import '../../features/profile/change_phone_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../auth/auth_controller.dart';
import '../social/social_providers.dart';
import '../theme/app_colors.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  // Only sign-in status changes re-run redirects; a profile edit must not
  // rebuild the route stack (it raced with pop() on the edit screen).
  ref.listen(authControllerProvider, (prev, next) {
    if (prev.runtimeType != next.runtimeType) refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      const signedInRoots = [
        '/home', '/circle', '/circles', '/circle-invitations', '/history', '/chats', '/profile', '/people', '/pals', '/notifications', '/community', '/settings',
      ];
      final signedInArea = signedInRoots.any((r) => loc == r || loc.startsWith('$r/'));

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
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
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
            GoRoute(path: '/chats', builder: (context, state) => const ChatsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
      // Full-screen pages pushed over the tabs (no bottom navigation).
      GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: '/profile/phone', builder: (context, state) => const ChangePhoneScreen()),
      GoRoute(path: '/profile/password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(
        path: '/circles/:id/reminders',
        builder: (context, state) => RemindersScreen(circleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/circles/:id/statement',
        builder: (context, state) => StatementScreen(circleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/circles/:id/sharing',
        builder: (context, state) => CircleSharingScreen(circleId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/community', builder: (context, state) => const CommunityScreen()),
      GoRoute(
        path: '/community/disputes/:id',
        builder: (context, state) => DisputeEvidenceScreen(disputeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/people/:id',
        builder: (context, state) => PersonProfileScreen(userId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'followers',
            builder: (context, state) =>
                PeopleListScreen(userId: state.pathParameters['id']!, kind: PeopleListKind.followers),
          ),
          GoRoute(
            path: 'following',
            builder: (context, state) =>
                PeopleListScreen(userId: state.pathParameters['id']!, kind: PeopleListKind.following),
          ),
          GoRoute(
            path: 'pals',
            builder: (context, state) => PeopleListScreen(userId: state.pathParameters['id']!, kind: PeopleListKind.pals),
          ),
        ],
      ),
      GoRoute(path: '/pals/requests', builder: (context, state) => const PalRequestsScreen()),
      GoRoute(path: '/profile/payment-methods', builder: (context, state) => const PaymentMethodsScreen()),
      GoRoute(path: '/profile/payment-methods/new', builder: (context, state) => const AddPaymentMethodScreen()),
      GoRoute(
        path: '/circles/:id/invite',
        builder: (context, state) => InvitePalsScreen(circleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/circle-invitations/:id',
        builder: (context, state) => InvitationScreen(invitationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chats/:id',
        builder: (context, state) => ChatThreadScreen(chatId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Sits under the branded loader (`PsSplashGate` in main.dart) while the
/// saved session is checked, so it only needs to match its background.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.headerGradient))),
      );
}
