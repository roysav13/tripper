import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/nearby_places_cache.dart';
import 'package:tripper/features/places/data/nearby_places_service.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';
import 'package:tripper/features/places/presentation/nearby_places_screen.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/test_preferences.dart';

class _FakeFetcher implements NearbyPlacesFetcher {
  _FakeFetcher(this.results);
  _FakeFetcher.failing() : results = const [], _shouldFail = true;

  List<NearbyPlaceResult> results;
  final bool _shouldFail;

  @override
  Future<List<NearbyPlaceResult>> searchNearby({
    required double lat,
    required double lng,
  }) async {
    if (_shouldFail) throw const GeocodingException('offline');
    return results;
  }
}

const _highRated = NearbyPlaceResult(
  placeId: 'p1',
  name: 'Railay Beach Bar',
  lat: 8.02,
  lng: 98.84,
  rating: 4.6,
  userRatingCount: 512,
  primaryType: 'bar',
);

Future<Widget> _app(NearbyPlacesFetcher fetcher) async => ProviderScope(
      overrides: [
        nearbyPlacesFetcherProvider.overrideWithValue(fetcher),
        nearbyPlacesCacheProvider.overrideWithValue(NearbyPlacesCache()),
        // A cache-miss fetch calls NearbyPlacesService's onRealFetch, which
        // increments nearbyApiCallCountProvider — its controller reads
        // sharedPreferencesProvider synchronously in build(), which throws
        // if unmocked.
        await testPreferencesOverride(),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const NearbyPlacesScreen(anchorLat: 8.0119, anchorLng: 98.8378),
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
  testWidgets('initial state shows only the find button, no list',
      (tester) async {
    await tester.pumpWidget(await _app(_FakeFetcher(const [_highRated])));
    await tester.pumpAndSettle();
    expect(find.text('Find nearby'), findsOneWidget);
    expect(find.text('Railay Beach Bar'), findsNothing);
  });

  testWidgets('tapping find renders results with rating and distance',
      (tester) async {
    await tester.pumpWidget(await _app(_FakeFetcher(const [_highRated])));
    await tester.tap(find.text('Find nearby'));
    await tester.pumpAndSettle();

    expect(find.text('Railay Beach Bar'), findsOneWidget);
    expect(find.textContaining('4.6'), findsOneWidget);
  });

  testWidgets('no results after the rating filter shows the empty state',
      (tester) async {
    await tester.pumpWidget(
      await _app(
        _FakeFetcher(const [
          NearbyPlaceResult(
            placeId: 'low',
            name: 'Low rated place',
            lat: 8.02,
            lng: 98.84,
            rating: 2.0,
            userRatingCount: 50,
          ),
        ]),
      ),
    );
    await tester.tap(find.text('Find nearby'));
    await tester.pumpAndSettle();

    expect(find.text('No highly-rated places found'), findsOneWidget);
  });

  testWidgets('a fetch failure shows the error state with retry',
      (tester) async {
    await tester.pumpWidget(await _app(_FakeFetcher.failing()));
    await tester.tap(find.text('Find nearby'));
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
