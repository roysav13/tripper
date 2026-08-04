import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/presentation/journal_location_picker.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
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
      'picking one of the trip\'s existing locations does not '
      'create a duplicate Place', (tester) async {
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
}
