import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
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

    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);
  });
}
