import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/places/presentation/places_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/trips/domain/trip.dart';
import '../../features/trips/presentation/trip_detail_screen.dart';
import '../../features/trips/presentation/trip_form_screen.dart';
import '../../features/trips/presentation/trip_list_screen.dart';
import '../../features/vault/presentation/vault_screen.dart';
import '../widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/trips',
    routes: [
      // Full-screen, above the tab shell.
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                builder: (context, state) => const TripListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const TripFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => TripDetailScreen(
                      tripId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => TripFormScreen(
                          initial: state.extra as Trip?,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vault',
                builder: (context, state) => const VaultScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/places',
                builder: (context, state) => const PlacesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
