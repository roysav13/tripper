import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/glass_chrome.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/places/presentation/place_widgets.dart';
import 'package:tripper/features/places/presentation/places_screen.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';

final _today = DateTime(2026, 7, 19);

Place _p(
  String name, {
  bool visited = false,
  DateTime? visitedAt,
  String country = '',
  String city = '',
}) =>
    Place(
      id: name,
      name: name,
      country: country,
      city: city,
      status: visited ? PlaceStatus.beenThere : PlaceStatus.wantToGo,
      visitedAt: visitedAt,
    );

Widget _app(List<Place> places) => ProviderScope(
      overrides: [
        placeRepositoryProvider
            .overrideWithValue(FakePlaceRepository([...places])),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
        clockProvider.overrideWithValue(() => _today),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PlacesScreen(),
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
  testWidgets('empty state invites the first place', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Where to next?'), findsOneWidget);
  });

  testWidgets('sections split wishlist and visited', (tester) async {
    await tester.pumpWidget(
      _app([
        _p('Railay viewpoint', city: 'Krabi', country: 'Thailand'),
        _p(
          'Phi Phi lagoon',
          visited: true,
          visitedAt: DateTime(2026, 7, 18),
          country: 'Thailand',
        ),
        _p(
          'Ein Gedi waterfall',
          visited: true,
          visitedAt: DateTime(2026, 4, 2),
          country: 'Israel',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('WANT TO GO · 1'), findsOneWidget);
    expect(find.text('BEEN THERE · 2'), findsOneWidget);
    expect(find.textContaining('VISITED 18 JUL 2026'), findsOneWidget);
  });

  testWidgets('check tap moves a place from wishlist to visited',
      (tester) async {
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

    await tester.pumpWidget(_app([_p('Railay viewpoint')]));
    await tester.pumpAndSettle();
    expect(find.text('WANT TO GO · 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark as visited'));
    await tester.pumpAndSettle();

    expect(find.text('WANT TO GO · 1'), findsNothing);
    expect(find.text('BEEN THERE · 1'), findsOneWidget);
    expect(find.textContaining('VISITED 19 JUL 2026'), findsOneWidget);
    // M4.4 — mark-visited gets a quiet haptic tick.
    expect(hapticCalls, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('500+ places render without overflow or exceptions (M4.2)',
      (tester) async {
    final many = [
      for (var i = 0; i < 520; i++)
        _p(
          'Place number $i with a fairly long name for wrapping',
          visited: i.isEven,
          visitedAt: i.isEven ? DateTime(2026, 1, 1) : null,
          country: 'Country ${i % 12}',
          city: 'City ${i % 40}',
        ),
    ];
    await tester.pumpWidget(_app(many));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'row settle + icon cross-fade animations run without throwing '
      'mid-flight (M4.4)', (tester) async {
    await tester.pumpWidget(_app([_p('Railay viewpoint')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark as visited'));
    // Pump mid-transition (well under the 250ms duration) instead of
    // settling straight away — this is what would surface a tween/curve
    // mistake that only shows up while the animation is actually running.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.text('BEEN THERE · 1'), findsOneWidget);
  });

  testWidgets('category filter narrows the visible list', (tester) async {
    await tester.pumpWidget(
      _app([
        const Place(id: 'a', name: 'Hotel A', category: PlaceCategory.hotel),
        const Place(
          id: 'b',
          name: 'Cafe B',
          category: PlaceCategory.coffeeShop,
        ),
      ]),
    );
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
      'filter button is absent when no place has a category or country to '
      'filter by', (tester) async {
    await tester.pumpWidget(
      _app([
        const Place(id: 'a', name: 'Hotel A'),
        const Place(id: 'b', name: 'Cafe B'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.tune), findsNothing);
  });

  testWidgets(
      'filter button shows its coral badge only once a filter is actually '
      'selected', (tester) async {
    await tester.pumpWidget(
      _app([
        const Place(id: 'a', name: 'Hotel A', category: PlaceCategory.hotel),
        const Place(
          id: 'b',
          name: 'Cafe B',
          category: PlaceCategory.coffeeShop,
        ),
      ]),
    );
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

    // No filter selected yet — no badge.
    expect(badgeFinder(), findsNothing);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    // Still no badge while the sheet is open but nothing picked.
    expect(badgeFinder(), findsNothing);

    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    // Selecting a category surfaces the badge on the underlying button.
    expect(badgeFinder(), findsOneWidget);
  });

  testWidgets(
      'stale category selection is pruned once its only match is edited '
      'away, so the list recovers without a restart', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', category: PlaceCategory.hotel),
      const Place(
        id: 'b',
        name: 'Cafe B',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeRepositoryProvider.overrideWithValue(repo),
          tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
          clockProvider.overrideWithValue(() => _today),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PlacesScreen(),
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

    // Filter down to Hotel — Cafe B drops out of the list.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);

    // Simulate the underlying data changing so no place is a Hotel
    // anymore — the Hotel chip disappears, but without the fix the stale
    // selection would keep the list stuck empty forever. The sheet is
    // still open here (never dismissed) — it must reflect this live, not
    // just the snapshot it opened with.
    repo.emit([
      const Place(
        id: 'a',
        name: 'Hotel A',
        category: PlaceCategory.restaurant,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
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

  testWidgets('country filter narrows the visible list', (tester) async {
    await tester.pumpWidget(
      _app([
        _p('Thai spot', country: 'Thailand'),
        _p('Japan spot', country: 'Japan'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japan'));
    await tester.pumpAndSettle();

    expect(find.text('Thai spot'), findsNothing);
    expect(find.text('Japan spot'), findsOneWidget);
  });

  testWidgets(
      'filtering to a combination that matches nothing shows the '
      'filter-empty state, and its CTA clears the filters', (tester) async {
    await tester.pumpWidget(
      _app([
        const Place(
          id: 'a',
          name: 'Hotel A',
          category: PlaceCategory.hotel,
          country: 'Thailand',
        ),
        const Place(
          id: 'b',
          name: 'Cafe B',
          category: PlaceCategory.coffeeShop,
          country: 'Japan',
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);

    // Hotel + Japan: no place is both, so the combination matches nothing.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japan'));
    await tester.pumpAndSettle();

    // Dismiss the sheet (tap the barrier, away from its content) so the
    // underlying CTA can be tapped.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Hotel A'), findsNothing);
    expect(find.text('Cafe B'), findsNothing);
    expect(find.text('No places match'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);
  });

  testWidgets(
      'filter sheet renders many categories and countries without '
      'overflow', (tester) async {
    final many = [
      for (var i = 0; i < 40; i++)
        Place(
          id: 'p$i',
          name: 'Place $i',
          country: 'Country $i',
          category: PlaceCategory.values[i % PlaceCategory.values.length],
        ),
    ];
    await tester.pumpWidget(_app(many));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Confirm the sheet actually opened before locating its scroll view —
    // makes the intent explicit instead of relying on a positional `.last`
    // find to happen to land on the right widget. SectionLabel renders its
    // text upper-cased, so the sheet's "Filters" title reads "FILTERS".
    expect(find.text('FILTERS'), findsOneWidget);

    await tester.fling(
      find.descendant(
        of: find.byType(GlassChrome),
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(0, -2000),
      3000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'active-filter strip shows a removable pill per selection, and '
      'removing one pill updates the list without reopening the sheet',
      (tester) async {
    await tester.pumpWidget(
      _app([
        const Place(
          id: 'a',
          name: 'Hotel A',
          category: PlaceCategory.hotel,
          country: 'Thailand',
        ),
        const Place(
          id: 'b',
          name: 'Restaurant B',
          category: PlaceCategory.restaurant,
          country: 'Thailand',
        ),
        const Place(
          id: 'c',
          name: 'Hotel C',
          category: PlaceCategory.hotel,
          country: 'Japan',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thailand'));
    await tester.pumpAndSettle();
    // Dismiss the sheet to see the strip above the (now filtered) list.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveFilterStrip), findsOneWidget);
    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('Thailand'), findsOneWidget);
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Restaurant B'), findsNothing);
    expect(find.text('Hotel C'), findsNothing);

    // Tapping the "Hotel" pill removes just that filter.
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel'), findsNothing);
    expect(find.text('Thailand'), findsOneWidget);
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Restaurant B'), findsOneWidget);
    expect(find.text('Hotel C'), findsNothing);
  });

  testWidgets(
      "the active-filter strip's Clear-filters button removes every "
      'active filter at once', (tester) async {
    await tester.pumpWidget(
      _app([
        const Place(
          id: 'a',
          name: 'Hotel A',
          category: PlaceCategory.hotel,
          country: 'Thailand',
        ),
        const Place(
          id: 'c',
          name: 'Hotel C',
          category: PlaceCategory.hotel,
          country: 'Japan',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thailand'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveFilterStrip), findsOneWidget);
    // Two active filters — the strip's own "Clear filters" convenience
    // button appears (a single pill can just be tapped to remove itself).
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveFilterStrip), findsNothing);
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Hotel C'), findsOneWidget);
  });

  testWidgets(
      'country checklist shows a search box once there are enough '
      'countries, and typing narrows the visible rows', (tester) async {
    const names = [
      'Argentina',
      'Brazil',
      'Canada',
      'Denmark',
      'Egypt',
      'France',
      'Germany',
    ];
    await tester.pumpWidget(
      _app([
        for (final name in names) _p('Spot in $name', country: name),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    for (final name in names) {
      expect(find.text(name), findsOneWidget);
    }

    await tester.enterText(find.byType(TextField), 'arg');
    await tester.pumpAndSettle();

    expect(find.text('Argentina'), findsOneWidget);
    for (final name in names.where((n) => n != 'Argentina')) {
      expect(find.text(name), findsNothing);
    }

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    // MonoText renders uppercase, like the sheet's "FILTERS" title above.
    expect(find.text('NO COUNTRIES MATCH'), findsOneWidget);
  });

  testWidgets(
      'country checklist has no search box when there are only a few '
      'countries', (tester) async {
    await tester.pumpWidget(
      _app([
        _p('Thai spot', country: 'Thailand'),
        _p('Japan spot', country: 'Japan'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      "the sheet's Show-results button reflects the live selection and "
      'closes the sheet on tap', (tester) async {
    await tester.pumpWidget(
      _app([
        const Place(id: 'a', name: 'Hotel A', category: PlaceCategory.hotel),
        const Place(
          id: 'b',
          name: 'Cafe B',
          category: PlaceCategory.coffeeShop,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Show 2 places'), findsOneWidget);

    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Show 1 place'), findsOneWidget);

    await tester.tap(find.text('Show 1 place'));
    await tester.pumpAndSettle();

    expect(find.byType(GlassChrome), findsNothing);
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);
  });
}
