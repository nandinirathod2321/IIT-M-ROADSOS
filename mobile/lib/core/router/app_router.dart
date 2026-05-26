import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/countdown_screen.dart';
import '../../features/emergency/screens/emergency_screen.dart';
import '../../features/medical_id/screens/medical_id_screen.dart';
import '../../features/first_aid/screens/first_aid_screen.dart';
import '../../features/first_aid/ai_chat_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../core/services/auth_service.dart';
import '../../shared/widgets/navigation_shell.dart';
import '../../features/emergency/screens/emergency_history_screen.dart';

/// Centralized application router using go_router.
/// Outfitted with navigatorKeys and neglect options to ensure web back works properly.
abstract final class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  static GoRouter router(String initialLocation) => GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routerNeglect: false,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final bool loggedIn = AuthService.instance.isLoggedIn;
      final matchLoc = state.matchedLocation;

      final isAuthRoute =
          matchLoc == '/login' ||
          matchLoc == '/signup' ||
          matchLoc == '/forgot-password';
      final isOnboarding = matchLoc == '/onboarding';

      if (!loggedIn && !isAuthRoute && !isOnboarding) {
        // If not logged in and not trying to access auth/onboarding, send to login
        return '/login';
      }
      if (loggedIn && isAuthRoute) {
        // If logged in and trying to hit auth, return to Home
        return '/';
      }
      return null;
    },
    routes: [
      // ── Shell with bottom nav ────────────────────────────────────────
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return NavigationShell(
            child: child,
            matchedLocation: state.matchedLocation,
          );
        },
        routes: [
          // Tab 0 — Home
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          // Tab 2 — First Aid
          GoRoute(
            path: '/first-aid',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FirstAidScreen(),
            ),
          ),
          // Tab 3 — Settings
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),

      // ── Standalone routes (outside ShellRoute) ──────────────────────
      GoRoute(
        path: '/medical-id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MedicalIdScreen(),
      ),
      GoRoute(
        path: '/emergency',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final section =
              int.tryParse(state.uri.queryParameters['section'] ?? '0') ?? 0;
          return EmergencyScreen(initialSection: section);
        },
      ),
      GoRoute(
        path: '/first-aid/ai-chat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final q = state.uri.queryParameters['question'];
          return AIChatScreen(initialQuestion: q);
        },
      ),
      GoRoute(
        path: '/countdown',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final trigger = state.uri.queryParameters['trigger'] ?? 'manual';
          return CountdownScreen(triggerType: trigger);
        },
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/history',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EmergencyHistoryScreen(),
      ),
    ],
  );
}
