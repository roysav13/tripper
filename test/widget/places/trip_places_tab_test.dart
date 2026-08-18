import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/location/location_providers.dart';
import 'package:tripper/core/location/location_service.dart';
import 'package:tripper/core/settings/settings_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/filtering/filter_sort_button.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/domain/place_collection.dart';
import 'package:tripper/features/places/presentation/place_collection_providers.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/places/presentation/place_widgets.dart';
import 'package:tripper/features/places/presentation/trip_places_tab.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_location_service.dart';
import '../../helpers/fake_place_collection_repository.dart';
import '../../helpers/fake_place_repository.dart';

const _trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

class _FixedNearbyToggle extends NearbyPlacesEnabledController {
  _FixedNearbyToggle(this._value);
  final bool _value;
  @override
  bool build() => _value;
}

Widget _app(
  FakePlaceRepository repo, {
  LocationFix? locationFix,
  FakePlaceCollectionRepository? collectionRepo,
}) =>
    ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(repo),
        placeCollectionRepositoryProvider.overrideWithValue(
          collectionRepo ?? FakePlaceCollectionRepository([]),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        // See places_screen_test.dart — the real GeolocatorLocationService
        // hits the OS (win32 Location API on desktop) rather than
        // gracefully no-op-ing when unmocked in a widget test.
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            locationFix ??
                const LocationUnavailable(LocationUnavailableReason.error),
          ),
        ),
        // TripPlacesTab now watches nearbyPlacesEnabledProvider; its real
        // controller reads sharedPreferencesProvider synchronously in
        // build(), which throws if unmocked. This helper doesn't expose a
        // toggle (see _appWithNearby below for that) — it's just always
        // off here so every existing test in this file keeps working.
        nearbyPlacesEnabledProvider.overrideWith(
          () => _FixedNearbyToggle(false),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TripPlacesTab(trip: _trip)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

Widget _appWithNearby(
  FakePlaceRepository repo, {
  required bool nearbyEnabled,
}) =>
    ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(repo),
        placeCollectionRepositoryProvider.overrideWithValue(
          FakePlaceCollectionRepository([]),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            const LocationUnavailable(LocationUnavailableReason.error),
          ),
        ),
        nearbyPlacesEnabledProvider
            .overrideWith(() => _FixedNearbyToggle(nearbyEnabled)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TripPlacesTab(trip: _trip)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets(
      'filter/sort button is shown (for Sort) even when no place in this '
      'trip has a category or country to filter by', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
      const Place(id: 'b', name: 'Cafe B', tripId: 't1'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets(
      'filter button shows its coral badge only once a filter is actually '
      'selected', (tester) async {
    final repo = FakePlaceRepository([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        category: PlaceCategory.hotel,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
        tripId: 't1',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    Finder badgeFinder() => find.descendant(
          of: find.byType(FilterSortButton),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
        );

    expect(badgeFinder(), findsNothing);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(badgeFinder(), findsNothing);

    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    expect(badgeFinder(), findsOneWidget);
  });

  testWidgets(
      'sort sheet lists Distance and shows an inline unavailable status '
      "when there's no location fix", (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Distance'), findsOneWidget);
    expect(find.text("Couldn't get your location"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'a place card shows its distance from the current fix once one lands',
      (tester) async {
    // Bangkok fix; Ayutthaya is ~67km away.
    final repo = FakePlaceRepository([
      const Place(
        id: 'a',
        name: 'Ayutthaya',
        tripId: 't1',
        lat: 14.3532,
        lng: 100.5686,
      ),
    ]);
    await tester.pumpWidget(
      _app(
        repo,
        locationFix: const LocationAvailable(13.7563, 100.5018),
      ),
    );
    await tester.pumpAndSettle();

    // MonoText (metadata line) renders its text uppercased.
    expect(find.text('67 KM AWAY'), findsOneWidget);
  });

  testWidgets('category filter narrows this trip\'s visible list',
      (tester) async {
    final repo = FakePlaceRepository([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        category: PlaceCategory.hotel,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
        tripId: 't1',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);
  });

  testWidgets(
      'stale category selection is pruned once its only match is edited '
      'away, so the list recovers without a restart', (tester) async {
    final repo = FakePlaceRepository([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        category: PlaceCategory.hotel,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
        tripId: 't1',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Filter down to Hotel — Cafe B drops out of the list.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);

    // Simulate the underlying data changing so no place in this trip is a
    // Hotel anymore — the Hotel chip disappears, but without the fix the
    // stale selection would keep the list stuck empty forever.
    repo.emit([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        category: PlaceCategory.restaurant,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
        tripId: 't1',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpAndSettle();

    // The now-absent "Hotel" chip is gone, and both places are visible
    // again — the stale selection was pruned, not left stranding the list.
    expect(find.text('Hotel'), findsNothing);
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);
  });

  testWidgets('a stream failure shows the error state with retry',
      (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    repo.emitError(Exception('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'toggling a place\'s visited state gets the same quiet haptic tick '
      'as the top-level Places screen (M4.4 parity)', (tester) async {
    final hapticCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark as visited'));
    await tester.pumpAndSettle();

    expect(hapticCalls, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets(
      'a place row settles into view via RowSettleAnimation, same as the '
      'top-level Places screen (M4.4 parity)', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byType(RowSettleAnimation), findsOneWidget);
  });

  testWidgets('nearby entry button is hidden when the feature is off',
      (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    await tester.pumpWidget(_appWithNearby(repo, nearbyEnabled: false));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Find nearby'), findsNothing);
  });

  testWidgets(
      'nearby entry button opens the anchor sheet when the feature is on',
      (tester) async {
    final repo = FakePlaceRepository([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        lat: 8.0119,
        lng: 98.8378,
      ),
    ]);
    await tester.pumpWidget(_appWithNearby(repo, nearbyEnabled: true));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Find nearby'), findsOneWidget);

    await tester.tap(find.byTooltip('Find nearby'));
    await tester.pumpAndSettle();
    expect(find.text('Near me'), findsOneWidget);
  });

  testWidgets('a place with a plannedDate shows its DAY N chip',
      (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      startDate: DateTime(2026, 7, 15),
      endDate: DateTime(2026, 7, 25),
    );
    final repo = FakePlaceRepository([
      Place(
        id: 'a',
        name: 'Railay viewpoint',
        tripId: 't1',
        plannedDate: DateTime(2026, 7, 17),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeRepositoryProvider.overrideWithValue(repo),
          placeCollectionRepositoryProvider.overrideWithValue(
            FakePlaceCollectionRepository([]),
          ),
          placeCollectionRepositoryProvider.overrideWithValue(
            FakePlaceCollectionRepository([]),
          ),
          clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(
              const LocationUnavailable(LocationUnavailableReason.error),
            ),
          ),
          // Required — see _app's override above: the real controller reads
          // sharedPreferencesProvider synchronously in build(), which
          // throws if unmocked.
          nearbyPlacesEnabledProvider.overrideWith(
            () => _FixedNearbyToggle(false),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: TripPlacesTab(trip: trip)),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 15 Jul is day 1, so 17 Jul is day 3.
    expect(find.textContaining('DAY 3'), findsOneWidget);
  });

  testWidgets(
      'the lists row renders here too, same as the top-level '
      'Places screen', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    final collectionRepo = FakePlaceCollectionRepository([
      PlaceCollection(id: 'c1', name: 'Food', createdAt: DateTime(2026, 1, 1)),
    ]);
    await tester.pumpWidget(_app(repo, collectionRepo: collectionRepo));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('New list'), findsOneWidget);
  });

  testWidgets('lists filter narrows this trip\'s visible list', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
      const Place(id: 'b', name: 'Cafe B', tripId: 't1'),
    ]);
    final collectionRepo = FakePlaceCollectionRepository(
      [PlaceCollection(id: 'c1', name: 'Food', createdAt: DateTime(2026, 1))],
      memberships: {
        'a': {'c1'},
      },
    );
    await tester.pumpWidget(_app(repo, collectionRepo: collectionRepo));
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    // "Food" appears both as a facet chip in the sheet and as a row chip
    // behind it — the sheet's is the topmost/most recently mounted.
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);
  });
}
