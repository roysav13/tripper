import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/domain/place_collection.dart';
import 'package:tripper/features/places/presentation/add_place_screen.dart';
import 'package:tripper/features/places/presentation/place_collection_providers.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_collection_repository.dart';
import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';

class FakeGeocoder implements Geocoder {
  FakeGeocoder(
    this.results, {
    this.fail = false,
    this.reverseHit,
    this.detailsHit,
  });

  final List<GeoResult> results;
  final bool fail;
  final GeoResult? reverseHit;
  final GeoResult? detailsHit;

  @override
  Future<List<GeoResult>> search(String query) async {
    if (fail) throw const GeocodingException();
    return results;
  }

  @override
  Future<GeoResult?> reverse(double lat, double lon) async {
    if (fail) throw const GeocodingException();
    return reverseHit;
  }

  @override
  Future<GeoResult?> details(String placeId) async {
    if (fail) throw const GeocodingException();
    return detailsHit;
  }
}

const _railay = GeoResult(
  name: 'Railay Beach',
  displayName: 'Railay Beach, Ao Nang, Krabi, Thailand',
  lat: 8.0119,
  lon: 98.8378,
  country: 'Thailand',
  city: 'Ao Nang',
);

class _FixedSummaryFetcher implements PlaceSummaryFetcher {
  _FixedSummaryFetcher(this.result);
  final String? result;

  @override
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async =>
      result;
}

class _CountingSummaryFetcher implements PlaceSummaryFetcher {
  _CountingSummaryFetcher(this.onCalled);
  final VoidCallback onCalled;

  @override
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async {
    onCalled();
    return 'should not be used';
  }
}

Widget _app(
  FakeGeocoder geocoder,
  FakePlaceRepository repo, {
  PlaceSummaryFetcher? summaryFetcher,
  FakePlaceCollectionRepository? collectionRepo,
}) =>
    ProviderScope(
      overrides: [
        geocoderProvider.overrideWithValue(geocoder),
        placeRepositoryProvider.overrideWithValue(repo),
        placeCollectionRepositoryProvider.overrideWithValue(
          collectionRepo ?? FakePlaceCollectionRepository([]),
        ),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        // Always overridden, never left at the real default — unlike the
        // old Google-backed fetcher, Wikipedia needs no key to reach the
        // network, so there's no "unconfigured, quietly no-ops" fallback
        // to lean on here (CLAUDE.md hard rule 5: network off by default).
        placeSummaryFetcherProvider.overrideWithValue(
          summaryFetcher ?? const NoopPlaceSummaryFetcher(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const AddPlaceScreen(renderMap: false),
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
  testWidgets('type -> debounced result -> tap -> prefilled card -> save',
      (tester) async {
    final repo = FakePlaceRepository([]);
    await tester.pumpWidget(_app(FakeGeocoder([_railay]), repo));

    await tester.enterText(find.byType(TextField).first, 'railay');
    // Debounce window passes, search fires.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Railay Beach'), findsOneWidget);
    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();

    // Save card slides up, prefilled.
    expect(find.widgetWithText(TextField, 'Railay Beach'), findsOneWidget);
    expect(find.textContaining('AO NANG · THAILAND'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.watchAll().first;
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Railay Beach');
    expect(saved.single.country, 'Thailand');
    expect(saved.single.city, 'Ao Nang');
    expect(saved.single.lat, closeTo(8.0119, 0.0001));
  });

  testWidgets('offline search offers add-without-location', (tester) async {
    final repo = FakePlaceRepository([]);
    await tester.pumpWidget(_app(FakeGeocoder(const [], fail: true), repo));

    await tester.enterText(find.byType(TextField).first, 'hidden gem cafe');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.textContaining('needs a connection'), findsOneWidget);
    await tester.tap(find.textContaining('without a location'));
    await tester.pumpAndSettle();

    // The query is in the search bar too — assert on the name field itself.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Place name' &&
            w.controller?.text == 'hidden gem cafe',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('NO LOCATION'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.watchAll().first;
    expect(saved.single.name, 'hidden gem cafe');
    expect(saved.single.lat, isNull);
  });

  testWidgets('save without a name shows validation, does not pop',
      (tester) async {
    final repo = FakePlaceRepository([]);
    await tester.pumpWidget(_app(FakeGeocoder([_railay]), repo));

    await tester.enterText(find.byType(TextField).first, 'railay');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();

    // Clear the prefilled name, then try to save.
    await tester.enterText(
      find.widgetWithText(TextField, 'Railay Beach'),
      '',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Give the trip a name'), findsOneWidget);
    expect(await repo.watchAll().first, isEmpty);
  });

  testWidgets('picking a category and typing a description saves both',
      (tester) async {
    final repo = FakePlaceRepository([]);
    await tester.pumpWidget(_app(FakeGeocoder([_railay]), repo));

    await tester.enterText(find.byType(TextField).first, 'railay');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();

    // The AppBar's search field is also a TextField and sorts after the
    // save card's fields in the element tree, so target the description
    // field by its label rather than by `.last`.
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Description',
      ),
      'A description',
    );
    await tester.tap(find.text('Restaurant'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repo.watchAll().first).single;
    expect(saved.category, PlaceCategory.restaurant);
    expect(saved.notes, 'A description');
  });

  testWidgets('save fires a background summary fetch that lands after pop',
      (tester) async {
    final repo = FakePlaceRepository([]);
    await tester.pumpWidget(
      _app(
        FakeGeocoder([_railay]),
        repo,
        summaryFetcher: _FixedSummaryFetcher('A quiet limestone cove.'),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'railay');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    // Save doesn't wait on the summary fetch — it's not a gate on the save
    // flow (CLAUDE.md hard rule 4) — so it lands on a later pump.
    await tester.pumpAndSettle();

    final saved = (await repo.watchAll().first).single;
    expect(saved.summary, 'A quiet limestone cove.');
    expect(saved.summaryFetchedAt, isNotNull);
  });

  testWidgets(
      'assigning an existing list while creating a place persists '
      'the membership', (tester) async {
    final repo = FakePlaceRepository([]);
    final collectionRepo = FakePlaceCollectionRepository([
      PlaceCollection(id: 'c1', name: 'Food', createdAt: DateTime(2026, 1, 1)),
    ]);
    await tester.pumpWidget(
      _app(FakeGeocoder([_railay]), repo, collectionRepo: collectionRepo),
    );

    await tester.enterText(find.byType(TextField).first, 'railay');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Food'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repo.watchAll().first).single;
    final memberships = await collectionRepo.watchMembershipsByPlace().first;
    expect(memberships[saved.id], {'c1'});
  });

  testWidgets(
      'creating a new list inline while adding a place persists '
      'both the list and the membership', (tester) async {
    final repo = FakePlaceRepository([]);
    final collectionRepo = FakePlaceCollectionRepository([]);
    await tester.pumpWidget(
      _app(FakeGeocoder([_railay]), repo, collectionRepo: collectionRepo),
    );

    await tester.enterText(find.byType(TextField).first, 'railay');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Tokyo day trips');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final collections = await collectionRepo.watchAll().first;
    expect(collections.single.name, 'Tokyo day trips');
    final saved = (await repo.watchAll().first).single;
    final memberships = await collectionRepo.watchMembershipsByPlace().first;
    expect(memberships[saved.id], {collections.single.id});
  });

  testWidgets('a pre-resolved summary is stored directly, without re-fetching',
      (tester) async {
    final repo = FakePlaceRepository([]);
    var fetchCalled = false;
    // Built directly with `initialSummary` rather than through the
    // existing `_app()` helper above — that helper's `home:` doesn't take
    // this new param, and this is the one test in this file that needs it.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geocoderProvider.overrideWithValue(FakeGeocoder([_railay])),
          placeRepositoryProvider.overrideWithValue(repo),
          placeCollectionRepositoryProvider
              .overrideWithValue(FakePlaceCollectionRepository([])),
          tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
          clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
          placeSummaryFetcherProvider.overrideWithValue(
            _CountingSummaryFetcher(() => fetchCalled = true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AddPlaceScreen(
            renderMap: false,
            initialName: 'Railay Beach',
            initialSummary: 'A limestone cove.',
          ),
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

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repo.watchAll().first).single;
    expect(saved.summary, 'A limestone cove.');
    expect(fetchCalled, isFalse);
  });
}
