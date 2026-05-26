import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/countdown_screen.dart';
import '../../features/emergency/screens/emergency_screen.dart';
import '../../features/medical_id/screens/medical_id_screen.dart';
import '../../features/first_aid/screens/first_aid_screen.dart';
import '../../features/first_aid/screens/ai_chat_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../core/services/auth_service.dart';
import '../../shared/widgets/navigation_shell.dart';
import '../../features/emergency/screens/emergency_history_screen.dart';

/// Centralized application router using go_router.
/// Outfitted with a global navigatorKey to allow sensor events to redirect navigation.
abstract final class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router(String initialLocation) => GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialLocation,
    redirect: (context, state) {
      final bool loggedIn = AuthService.instance.isLoggedIn;
      final matchLoc = state.matchedLocation;

      final isAuthRoute = matchLoc == '/login' || matchLoc == '/signup' || matchLoc == '/forgot-password';
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0 — Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),
          // Tab 1 — Medical ID
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/medical-id',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MedicalIdScreen(),
                ),
              ),
            ],
          ),
          // Tab 2 — First Aid
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/first-aid',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: FirstAidScreen(),
                ),
              ),
            ],
          ),
          // Tab 3 — Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ───────────────────────────
      GoRoute(
        path: '/emergency',
        parentNavigatorKey: navigatorKey,
        builder: (context, state) {
          final section =
              int.tryParse(state.uri.queryParameters['section'] ?? '0') ?? 0;
          return EmergencyScreen(initialSection: section);
        },
      ),
      GoRoute(
        path: '/countdown',
        parentNavigatorKey: navigatorKey,
        builder: (context, state) {
          final trigger = state.uri.queryParameters['trigger'] ?? 'manual';
          return CountdownScreen(triggerType: trigger);
        },
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/history',
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const EmergencyHistoryScreen(),
      ),
      GoRoute(
        path: '/first-aid/ai-chat',
        parentNavigatorKey: navigatorKey,
        builder: (context, state) {
          final question = state.uri.queryParameters['question'];
          return AIChatScreen(initialQuestion: question);
        },
      ),
    ],
  );
}
