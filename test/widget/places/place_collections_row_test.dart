import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place_collection.dart';
import 'package:tripper/features/places/presentation/place_collection_providers.dart';
import 'package:tripper/features/places/presentation/place_collections_row.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_collection_repository.dart';
import '../../helpers/fake_place_repository.dart';

Widget _app(
  List<PlaceCollection> collections,
  FakePlaceCollectionRepository repo,
) =>
    ProviderScope(
      overrides: [
        placeCollectionRepositoryProvider.overrideWithValue(repo),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: PlaceCollectionsRow(collections: collections)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

final _food =
    PlaceCollection(id: 'c1', name: 'Food', createdAt: DateTime(2026, 1, 1));

void main() {
  testWidgets('shows a chip per list plus a trailing New list chip',
      (tester) async {
    await tester.pumpWidget(_app([_food], FakePlaceCollectionRepository([])));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('New list'), findsOneWidget);
  });

  testWidgets('the New list chip is present even with zero lists yet',
      (tester) async {
    await tester.pumpWidget(_app([], FakePlaceCollectionRepository([])));
    await tester.pumpAndSettle();

    expect(find.text('New list'), findsOneWidget);
  });

  testWidgets('New list opens a dialog and creates a collection on confirm',
      (tester) async {
    final repo = FakePlaceCollectionRepository([]);
    await tester.pumpWidget(_app([], repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tokyo day trips');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final created = await repo.watchAll().first;
    expect(created.single.name, 'Tokyo day trips');
  });

  testWidgets(
      'confirming with an empty name shows a validation error and creates '
      'nothing', (tester) async {
    final repo = FakePlaceCollectionRepository([]);
    await tester.pumpWidget(_app([], repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Give the list a name'), findsOneWidget);
    expect(await repo.watchAll().first, isEmpty);
  });

  testWidgets('tapping an existing list chip opens its detail screen',
      (tester) async {
    await tester.pumpWidget(
      _app([_food], FakePlaceCollectionRepository([_food])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    // The (empty) list-detail screen for Food.
    expect(find.text('No places yet'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Food')),
      findsOneWidget,
    );
  });
}
