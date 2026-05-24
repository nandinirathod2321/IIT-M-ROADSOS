import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/home/screens/home_screen.dart';
import 'features/home/screens/countdown_screen.dart';
import 'features/emergency/screens/emergency_screen.dart';
import 'features/medical_id/screens/medical_id_screen.dart';
import 'features/first_aid/screens/first_aid_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'shared/widgets/navigation_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Application router using go_router with a StatefulShellRoute
/// for the bottom navigation tabs.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
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
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final section =
            int.tryParse(state.uri.queryParameters['section'] ?? '0') ?? 0;
        return EmergencyScreen(initialSection: section);
      },
    ),
    GoRoute(
      path: '/countdown',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CountdownScreen(),
    ),
  ],
);
