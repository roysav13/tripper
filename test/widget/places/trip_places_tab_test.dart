import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/places/presentation/place_widgets.dart';
import 'package:tripper/features/places/presentation/trip_places_tab.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_repository.dart';

const _trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

Widget _app(FakePlaceRepository repo) => ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
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
      'filter button is absent when no place in this trip has a category '
      'or country to filter by', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
      const Place(id: 'b', name: 'Cafe B', tripId: 't1'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.tune), findsNothing);
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
          of: find.byType(PlaceFilterButton),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).shape ==
                    BoxShape.circle,
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
}
