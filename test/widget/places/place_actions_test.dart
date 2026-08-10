import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/places/presentation/places_screen.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';

Widget _app(FakePlaceRepository repo) => ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(repo),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
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

const _place = Place(
  id: 'p1',
  name: 'Railay viewpoint',
  country: 'Thailand',
  city: 'Krabi',
);

void main() {
  testWidgets('tapping a row opens actions; delete removes after confirm',
      (tester) async {
    final repo = FakePlaceRepository([_place]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this place?'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(await repo.watchAll().first, isEmpty);
  });

  testWidgets('edit sheet renames the place', (tester) async {
    final repo = FakePlaceRepository([_place]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Railay viewpoint'),
      'Railay East viewpoint',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final places = await repo.watchAll().first;
    expect(places.single.name, 'Railay East viewpoint');
    expect(places.single.country, 'Thailand');
  });

  testWidgets('editing sets a category and a description', (tester) async {
    final repo = FakePlaceRepository([_place]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attraction'));
    await tester.enterText(find.byType(TextField).last, 'Great sunset spot');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repo.watchAll().first).single;
    expect(saved.category, PlaceCategory.attraction);
    expect(saved.notes, 'Great sunset spot');
  });
}
