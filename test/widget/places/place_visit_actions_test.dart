import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/features/journal/presentation/journal_providers.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/places/presentation/place_visit_actions.dart';

import '../../helpers/fake_journal_repository.dart';
import '../../helpers/fake_place_repository.dart';

const _place = Place(
  id: 'p1',
  name: 'Railay Beach',
  lat: 8.0119,
  lng: 98.8378,
  tripId: 'trip-1',
);

const _tripless = Place(id: 'p2', name: 'No trip', lat: 1, lng: 1);

/// Captures the tree's WidgetRef into [onRef] so tests can call the
/// ref-consuming functions under test directly, without any UI to tap.
Widget _wrap({
  required FakePlaceRepository places,
  required FakeJournalRepository journal,
  required void Function(WidgetRef ref) onRef,
}) =>
    ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(places),
        journalRepositoryProvider.overrideWithValue(journal),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            onRef(ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

void main() {
  late FakePlaceRepository places;
  late FakeJournalRepository journal;
  late WidgetRef ref;

  setUp(() {
    places = FakePlaceRepository([_place, _tripless]);
    journal = FakeJournalRepository([]);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(places: places, journal: journal, onRef: (r) => ref = r),
    );
    await tester.pump();
  }

  testWidgets('marking visited creates one linked stub entry', (tester) async {
    await pump(tester);
    await markPlaceVisited(ref, _place, visited: true);

    final all = await places.watchAll().first;
    expect(all.firstWhere((p) => p.id == 'p1').isVisited, isTrue);

    final entries = await journal.watchForTrip('trip-1').first;
    expect(entries, hasLength(1));
    expect(entries.single.placeId, 'p1');
    expect(entries.single.summary, isEmpty);
    expect(entries.single.placeName, 'Railay Beach');
    expect(entries.single.loggedAt, DateTime(2026, 7, 19));
  });

  testWidgets('toggling visited off then on again does not duplicate the entry',
      (tester) async {
    await pump(tester);
    await markPlaceVisited(ref, _place, visited: true);
    await markPlaceVisited(ref, _place, visited: false);
    await markPlaceVisited(ref, _place, visited: true);

    final entries = await journal.watchForTrip('trip-1').first;
    expect(entries, hasLength(1));
  });

  testWidgets('un-visiting never deletes the linked entry', (tester) async {
    await pump(tester);
    await markPlaceVisited(ref, _place, visited: true);
    await markPlaceVisited(ref, _place, visited: false);

    final all = await places.watchAll().first;
    expect(all.firstWhere((p) => p.id == 'p1').isVisited, isFalse);
    final entries = await journal.watchForTrip('trip-1').first;
    expect(entries, hasLength(1));
  });

  testWidgets('a place with no tripId is marked visited but gets no stub entry',
      (tester) async {
    await pump(tester);
    await markPlaceVisited(ref, _tripless, visited: true);

    final all = await places.watchAll().first;
    expect(all.firstWhere((p) => p.id == 'p2').isVisited, isTrue);
    expect(await journal.hasEntryForPlace('p2'), isFalse);
  });

  testWidgets('markPlacesVisited creates one stub entry per place, once each',
      (tester) async {
    await pump(tester);
    const third = Place(id: 'p3', name: 'Ao Nang', lat: 2, lng: 2, tripId: 'trip-1');
    places.emit([_place, _tripless, third]);

    await markPlacesVisited(ref, [_place, third], DateTime(2026, 8, 1));

    final entries = await journal.watchForTrip('trip-1').first;
    expect(entries, hasLength(2));
    expect(entries.map((e) => e.placeId), containsAll(['p1', 'p3']));
    // Re-running with an already-linked place doesn't duplicate.
    await markPlacesVisited(ref, [_place], DateTime(2026, 8, 2));
    final after = await journal.watchForTrip('trip-1').first;
    expect(after, hasLength(2));
  });
}
