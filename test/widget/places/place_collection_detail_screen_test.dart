import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/domain/place_collection.dart';
import 'package:tripper/features/places/presentation/place_collection_detail_screen.dart';
import 'package:tripper/features/places/presentation/place_collection_providers.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_collection_repository.dart';
import '../../helpers/fake_place_repository.dart';

final _food =
    PlaceCollection(id: 'c1', name: 'Food', createdAt: DateTime(2026, 1, 1));

Widget _app({
  required List<Place> places,
  required Map<String, Set<String>> memberships,
  required String collectionId,
}) =>
    ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository(places)),
        placeCollectionRepositoryProvider.overrideWithValue(
          FakePlaceCollectionRepository([_food], memberships: memberships),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: PlaceCollectionDetailScreen(collectionId: collectionId),
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
  testWidgets('shows only the places that belong to this list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        places: const [
          Place(id: 'p1', name: 'Ramen shop'),
          Place(id: 'p2', name: 'Not in the list'),
          Place(id: 'p3', name: 'Sushi bar'),
        ],
        memberships: const {
          'p1': {'c1'},
          'p3': {'c1'},
        },
        collectionId: 'c1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ramen shop'), findsOneWidget);
    expect(find.text('Sushi bar'), findsOneWidget);
    expect(find.text('Not in the list'), findsNothing);
  });

  testWidgets('empty list shows the empty state', (tester) async {
    await tester.pumpWidget(
      _app(places: const [], memberships: const {}, collectionId: 'c1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('No places yet'), findsOneWidget);
  });

  testWidgets('renaming updates the app bar title live', (tester) async {
    await tester.pumpWidget(
      _app(places: const [], memberships: const {}, collectionId: 'c1'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename list'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Food'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tokyo food');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Tokyo food'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('deleting the list pops back after confirmation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeRepositoryProvider
              .overrideWithValue(FakePlaceRepository(const [])),
          placeCollectionRepositoryProvider.overrideWithValue(
            FakePlaceCollectionRepository([_food]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const PlaceCollectionDetailScreen(
                        collectionId: 'c1',
                      ),
                    ),
                  ),
                  child: const Text('open'),
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

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Food')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete list'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this list?'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
  });
}
