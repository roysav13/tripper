import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/presentation/journal_location_picker.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_repository.dart';

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder(this.results);

  final List<GeoResult> results;

  @override
  Future<List<GeoResult>> search(String query) async => results;

  @override
  Future<GeoResult?> reverse(double lat, double lon) async => null;

  @override
  Future<GeoResult?> details(String placeId) async => null;
}

const _railay = GeoResult(
  name: 'Railay Beach',
  displayName: 'Railay Beach, Krabi, Thailand',
  lat: 8.0119,
  lon: 98.8378,
  country: 'Thailand',
  city: 'Krabi',
);

Widget _wrap({
  required FakePlaceRepository places,
  required _FakeGeocoder geocoder,
}) =>
    ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(places),
        geocoderProvider.overrideWithValue(geocoder),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        // Network off by default (CLAUDE.md hard rule 5) — the "new named
        // place" flow triggers a background summary fetch.
        placeSummaryFetcherProvider
            .overrideWithValue(const NoopPlaceSummaryFetcher()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        // renderMap: false — Google Maps needs a platform view that widget
        // tests can't create. Constructed directly (not via .open()), same
        // as AddPlaceScreen's own tests.
        home: const JournalLocationPicker(tripId: 'trip-1', renderMap: false),
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
      'picking one of the trip\'s existing, not-yet-visited locations '
      'marks it visited', (tester) async {
    final places = FakePlaceRepository([
      const Place(
        id: 'p1',
        name: 'Railay Beach',
        lat: 8.0119,
        lng: 98.8378,
        tripId: 'trip-1',
      ),
    ]);
    await tester
        .pumpWidget(_wrap(places: places, geocoder: _FakeGeocoder(const [])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final all = await places.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.isVisited, isTrue);
  });

  testWidgets(
      'picking an already-visited trip place does not re-stamp visitedAt',
      (tester) async {
    final originalVisit = DateTime(2020, 1, 1);
    final places = FakePlaceRepository(
      [
        Place(
          id: 'p1',
          name: 'Railay Beach',
          lat: 8.0119,
          lng: 98.8378,
          tripId: 'trip-1',
          status: PlaceStatus.beenThere,
          visitedAt: originalVisit,
        ),
      ],
      clock: DateTime(2026, 7, 19),
    );
    await tester
        .pumpWidget(_wrap(places: places, geocoder: _FakeGeocoder(const [])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final all = await places.watchAll().first;
    expect(all.single.visitedAt, originalVisit);
  });

  testWidgets(
      'picking a brand-new named location via search adds it to the '
      'trip\'s Places as visited', (tester) async {
    final places = FakePlaceRepository([]);
    await tester.pumpWidget(
      _wrap(places: places, geocoder: _FakeGeocoder(const [_railay])),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'railay');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final all = await places.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.name, 'Railay Beach');
    expect(all.single.tripId, 'trip-1');
    expect(all.single.isVisited, isTrue);
  });

  testWidgets(
      're-opening the picker on an entry already linked to a visited '
      'place keeps its placeId on Save even without touching a chip',
      (tester) async {
    final places = FakePlaceRepository(
      [
        Place(
          id: 'p1',
          name: 'Railay Beach',
          lat: 8.0119,
          lng: 98.8378,
          tripId: 'trip-1',
          status: PlaceStatus.beenThere,
          visitedAt: DateTime(2020, 1, 1),
        ),
      ],
      clock: DateTime(2026, 7, 19),
    );

    JournalLocationPick? result;
    // Driven directly via Navigator.push (not JournalLocationPicker.open,
    // which always renders a real GoogleMap) so renderMap:false can be
    // passed while still exercising the real push/pop round trip and
    // capturing the popped value, matching how .open() itself is used in
    // journal_entry_form_sheet.dart.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeRepositoryProvider.overrideWithValue(places),
          geocoderProvider.overrideWithValue(_FakeGeocoder(const [])),
          clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
          placeSummaryFetcherProvider
              .overrideWithValue(const NoopPlaceSummaryFetcher()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context, rootNavigator: true)
                        .push<JournalLocationPick?>(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => const JournalLocationPicker(
                          tripId: 'trip-1',
                          initialLat: 8.0119,
                          initialLng: 98.8378,
                          initialPlaceName: 'Railay Beach',
                          initialPlaceId: 'p1',
                          renderMap: false,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
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

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Save without touching any chip — the location field already shows
    // the initial pick from initialLat/initialLng/initialPlaceName.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.placeId, 'p1');
  });
}
