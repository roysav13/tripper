import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/sharing/maps_list_scraper.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/presentation/maps_list_import_screen.dart';
import 'package:tripper/features/places/presentation/place_collection_providers.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_collection_repository.dart';
import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';

class _FakeScraper implements MapsListScraper {
  _FakeScraper(this.result, {this.gate});
  final ScrapedMapsList? result;

  /// When set, `scrape` blocks on this instead of returning [result]
  /// immediately -- lets a test hold a scrape open indefinitely (no
  /// real-clock race with widget pumping) to assert the in-flight
  /// "scraping" state. Same pattern as
  /// nearby_place_detail_sheet_test.dart's Completer-gated fake.
  final Completer<ScrapedMapsList?>? gate;
  int callCount = 0;

  @override
  Future<ScrapedMapsList?> scrape(String listUrl) async {
    callCount++;
    if (gate != null) return gate!.future;
    return result;
  }
}

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder(this.hits);
  final Map<String, GeoResult> hits;
  final List<String> queries = [];

  @override
  Future<List<GeoResult>> search(String query) async {
    queries.add(query);
    final hit = hits[query];
    return hit == null ? const [] : [hit];
  }

  @override
  Future<GeoResult?> reverse(double lat, double lon) async => null;

  @override
  Future<GeoResult?> details(String placeId) async => null;
}

const _senso = GeoResult(
  name: 'Sensō-ji',
  displayName: 'Sensō-ji, Tokyo, Japan',
  lat: 35.7148,
  lon: 139.7967,
  country: 'Japan',
  city: 'Tokyo',
);

const _fuji = GeoResult(
  name: 'Mt. Fuji',
  displayName: 'Mt. Fuji, Japan',
  lat: 35.3606,
  lon: 138.7274,
  country: 'Japan',
  city: '',
);

Widget _app({
  required MapsListScraper scraper,
  required Geocoder geocoder,
  FakePlaceRepository? placeRepo,
  FakePlaceCollectionRepository? collectionRepo,
  List<Trip> trips = const [],
  String url = 'https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2!2sX!3e3',
  String? nameGuess,
  // True puts the screen behind a real "open" push (matching
  // MapsListImportScreen.open's fullscreenDialog route) instead of
  // rendering it as MaterialApp.home directly -- needed by any test that
  // depends on AppBar's automatic leading button, which only appears when
  // Navigator.canPop is true (see place_collection_detail_screen_test.dart
  // for the same pattern).
  bool pushed = false,
}) =>
    ProviderScope(
      overrides: [
        mapsListScraperProvider.overrideWithValue(scraper),
        geocoderProvider.overrideWithValue(geocoder),
        placeRepositoryProvider
            .overrideWithValue(placeRepo ?? FakePlaceRepository([])),
        placeCollectionRepositoryProvider.overrideWithValue(
          collectionRepo ?? FakePlaceCollectionRepository([]),
        ),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository(trips)),
        clockProvider.overrideWithValue(() => DateTime(2026, 8, 20)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: pushed
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          fullscreenDialog: true,
                          builder: (context) => MapsListImportScreen(
                            url: url,
                            nameGuess: nameGuess,
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              )
            : MapsListImportScreen(url: url, nameGuess: nameGuess),
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
  testWidgets('scraping state shows progress copy', (tester) async {
    final scraper = _FakeScraper(null, gate: Completer<ScrapedMapsList?>());
    await tester.pumpWidget(
      _app(scraper: scraper, geocoder: _FakeGeocoder(const {})),
    );
    await tester.pump();
    expect(find.text('Reading list…'), findsOneWidget);
  });

  testWidgets('scrape failure shows the failure message', (tester) async {
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(null),
        geocoder: _FakeGeocoder(const {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Couldn't read this list from Google Maps — try sharing individual "
        'places instead',
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty scrape result is treated as failure', (tester) async {
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(title: 'Japan', placeNames: []),
        ),
        geocoder: _FakeGeocoder(const {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Couldn't read this list from Google Maps — try sharing individual places instead",
      ),
      findsOneWidget,
    );
  });

  testWidgets('successful scrape shows the checklist, all checked by default',
      (tester) async {
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Mt. Fuji'],
          ),
        ),
        geocoder: _FakeGeocoder(const {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sensō-ji'), findsOneWidget);
    expect(find.text('Mt. Fuji'), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'List name'), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget); // prefilled title
  });

  testWidgets('unchecking a place updates the selected count and import label',
      (tester) async {
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Mt. Fuji'],
          ),
        ),
        geocoder: _FakeGeocoder(const {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Mt. Fuji'));
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Import 1 places'), findsOneWidget);
  });

  testWidgets(
      'importing geocodes selected names, creates places + a collection, '
      'then closes the screen', (tester) async {
    final geocoder = _FakeGeocoder({
      'Sensō-ji': _senso,
      'Mt. Fuji': _fuji,
    });
    final placeRepo = FakePlaceRepository([]);
    final collectionRepo = FakePlaceCollectionRepository([]);
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Mt. Fuji'],
          ),
        ),
        geocoder: geocoder,
        placeRepo: placeRepo,
        collectionRepo: collectionRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 2 places'));
    await tester.pump();
    // Two unique names geocoded sequentially with a rate-limit delay
    // between calls.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(placeRepo.watchAll(), emits(hasLength(2)));
    final created = await placeRepo.watchAll().first;
    final byName = {for (final p in created) p.name: p};
    expect(byName['Sensō-ji']!.lat, closeTo(35.7148, 0.0001));
    expect(byName['Mt. Fuji']!.city, '');
    final collections = await collectionRepo.watchAll().first;
    expect(collections, hasLength(1));
    expect(collections.single.name, 'Japan');
    final memberships = await collectionRepo.watchMembershipsByPlace().first;
    expect(memberships[byName['Sensō-ji']!.id], {collections.single.id});
    expect(memberships[byName['Mt. Fuji']!.id], {collections.single.id});
    // Screen closed itself.
    expect(find.byType(MapsListImportScreen), findsNothing);
  });

  testWidgets('a name that fails to geocode still imports, name-only',
      (tester) async {
    final placeRepo = FakePlaceRepository([]);
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(title: 'Japan', placeNames: ['Nowhereville']),
        ),
        geocoder: _FakeGeocoder(const {}), // no hits at all
        placeRepo: placeRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 1 places'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    final created = await placeRepo.watchAll().first;
    expect(created.single.name, 'Nowhereville');
    expect(created.single.lat, isNull);
  });

  testWidgets('duplicate names are geocoded only once', (tester) async {
    final geocoder = _FakeGeocoder({'Sensō-ji': _senso});
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Sensō-ji', ' sensō-ji '],
          ),
        ),
        geocoder: geocoder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 3 places'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(geocoder.queries, hasLength(1));
  });

  testWidgets('cancelling during review writes nothing', (tester) async {
    final placeRepo = FakePlaceRepository([]);
    final collectionRepo = FakePlaceCollectionRepository([]);
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(title: 'Japan', placeNames: ['Sensō-ji']),
        ),
        geocoder: _FakeGeocoder(const {}),
        placeRepo: placeRepo,
        collectionRepo: collectionRepo,
        // A real push, not MaterialApp.home: the screen's AppBar only
        // grows an automatic close/back button when Navigator.canPop is
        // true, and pageBack() below needs that button to exist.
        pushed: true,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Not tester.pageBack(): AppBar auto-implies a Close ("X") button, not
    // a Back arrow, for a fullscreenDialog route (see app_bar.dart's
    // `useCloseButton = parentRoute?.fullscreenDialog`) -- pageBack() only
    // looks for a 'Back' tooltip / CupertinoNavigationBarBackButton, so it
    // wouldn't find this screen's real dismiss affordance.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(await placeRepo.watchAll().first, isEmpty);
    expect(await collectionRepo.watchAll().first, isEmpty);
  });

  testWidgets('an available trip can be picked and is applied to every place',
      (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Japan trip',
      destinations: const ['Japan'],
    );
    final placeRepo = FakePlaceRepository([]);
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Mt. Fuji'],
          ),
        ),
        geocoder: _FakeGeocoder({'Sensō-ji': _senso, 'Mt. Fuji': _fuji}),
        placeRepo: placeRepo,
        trips: [trip],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Japan trip'));
    await tester.pump();
    await tester.tap(find.text('Import 2 places'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    final created = await placeRepo.watchAll().first;
    expect(created.every((p) => p.tripId == 't1'), isTrue);
  });
}
