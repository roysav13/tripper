import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/add_place_screen.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

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

Widget _app(FakeGeocoder geocoder, FakePlaceRepository repo) => ProviderScope(
      overrides: [
        geocoderProvider.overrideWithValue(geocoder),
        placeRepositoryProvider.overrideWithValue(repo),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
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
}
