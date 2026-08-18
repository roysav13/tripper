import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/settings/settings_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/domain/place_collection.dart';
import 'package:tripper/features/places/presentation/place_collection_providers.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/places/presentation/places_screen.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_collection_repository.dart';
import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';

class _FixedNearbyToggle extends NearbyPlacesEnabledController {
  _FixedNearbyToggle(this._value);
  final bool _value;
  @override
  bool build() => _value;
}

Widget _app(
  FakePlaceRepository repo, {
  FakePlaceCollectionRepository? collectionRepo,
}) =>
    ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(repo),
        placeCollectionRepositoryProvider.overrideWithValue(
          collectionRepo ?? FakePlaceCollectionRepository([]),
        ),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        // PlacesScreen now watches nearbyPlacesEnabledProvider; its real
        // controller reads sharedPreferencesProvider synchronously in
        // build(), which throws if unmocked (see places_screen_test.dart).
        nearbyPlacesEnabledProvider.overrideWith(
          () => _FixedNearbyToggle(false),
        ),
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

/// The edit form's Lists section makes the sheet taller than the default
/// 800x600 test surface, pushing Save out of the hit-testable viewport —
/// grow the surface instead of fighting scroll-position pixel geometry.
void _growViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

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
    _growViewport(tester);
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
    _growViewport(tester);
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

  testWidgets('description shows in the actions sheet when set',
      (tester) async {
    final repo = FakePlaceRepository([
      _place.copyWith(notes: 'A lovely lookout'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();

    expect(find.text('A lovely lookout'), findsOneWidget);
    expect(find.byKey(const Key('place-description')), findsOneWidget);
  });

  testWidgets('no description line when notes is empty', (tester) async {
    final repo = FakePlaceRepository([_place]); // _place has no notes
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('place-description')), findsNothing);
  });

  testWidgets('Google Maps action only appears for a located place',
      (tester) async {
    final located = _place.copyWith(lat: () => 8.0119, lng: () => 98.8378);
    final repo = FakePlaceRepository([located]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();

    expect(find.text('Open in Google Maps'), findsOneWidget);
  });

  testWidgets('no Google Maps action for a place with no location',
      (tester) async {
    final repo = FakePlaceRepository([_place]); // _place has no lat/lng
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();

    expect(find.text('Open in Google Maps'), findsNothing);
  });

  testWidgets(
      'editing assigns a place to a list created inline from the edit form',
      (tester) async {
    _growViewport(tester);
    final repo = FakePlaceRepository([_place]);
    final collectionRepo = FakePlaceCollectionRepository([]);
    await tester.pumpWidget(_app(repo, collectionRepo: collectionRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // The Places-tab collections row underneath the sheet has its own
    // "New list" chip — .last is the topmost one, in this edit form.
    await tester.tap(find.text('New list').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Tokyo day trips');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final collections = await collectionRepo.watchAll().first;
    expect(collections.single.name, 'Tokyo day trips');
    final memberships = await collectionRepo.watchMembershipsByPlace().first;
    expect(memberships['p1'], {collections.single.id});
  });

  testWidgets(
      'a place already in a list shows that list pre-selected when editing, '
      'and deselecting it clears the membership on save', (tester) async {
    _growViewport(tester);
    final repo = FakePlaceRepository([_place]);
    final collectionRepo = FakePlaceCollectionRepository(
      [PlaceCollection(id: 'c1', name: 'Food', createdAt: DateTime(2026, 1))],
      memberships: {
        'p1': {'c1'},
      },
    );
    await tester.pumpWidget(_app(repo, collectionRepo: collectionRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Food'))
          .selected,
      isTrue,
    );

    // Deselect it, then save.
    await tester.tap(find.widgetWithText(FilterChip, 'Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final memberships = await collectionRepo.watchMembershipsByPlace().first;
    expect(memberships['p1'] ?? const <String>{}, isEmpty);
  });
}
