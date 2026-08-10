import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/domain/place.dart';

Place _p(
  String name, {
  bool visited = false,
  DateTime? visitedAt,
  String country = '',
}) =>
    Place(
      id: name,
      name: name,
      country: country,
      status: visited ? PlaceStatus.beenThere : PlaceStatus.wantToGo,
      visitedAt: visitedAt,
    );

void main() {
  group('sortForList', () {
    test('wishlist first (alphabetical), visited last (recent first)', () {
      final sorted = sortForList([
        _p('Zoo Negara', visited: true, visitedAt: DateTime(2026, 1, 1)),
        _p('Beach walk'),
        _p('Arun temple', visited: true, visitedAt: DateTime(2026, 6, 1)),
        _p('Aquarium'),
      ]);
      expect(sorted.map((p) => p.name).toList(), [
        'Aquarium',
        'Beach walk',
        'Arun temple',
        'Zoo Negara',
      ]);
    });

    test('visited without a date sorts last among visited', () {
      final sorted = sortForList([
        _p('No date', visited: true),
        _p('Dated', visited: true, visitedAt: DateTime(2026, 1, 1)),
      ]);
      expect(sorted.map((p) => p.name).toList(), ['Dated', 'No date']);
    });
  });

  group('visitedStats', () {
    test('counts distinct countries case-insensitively, visited only', () {
      final stats = visitedStats([
        _p('A', visited: true, country: 'Thailand'),
        _p('B', visited: true, country: 'thailand'),
        _p('C', visited: true, country: 'Israel'),
        _p('D', visited: true),
        _p('E', country: 'Japan'),
      ]);
      expect(stats.countries, 2);
      expect(stats.visited, 4);
    });

    test('empty input gives zeros', () {
      final stats = visitedStats(const []);
      expect(stats.countries, 0);
      expect(stats.visited, 0);
    });
  });

  group('filterPlaces', () {
    final places = [
      const Place(id: 'a', name: 'A', country: 'Thailand', category: PlaceCategory.hotel),
      const Place(id: 'b', name: 'B', country: 'Thailand', category: PlaceCategory.restaurant),
      const Place(id: 'c', name: 'C', country: 'Japan', category: PlaceCategory.hotel),
      const Place(id: 'd', name: 'D', country: 'Japan', category: null),
    ];

    test('no filters returns everything', () {
      expect(filterPlaces(places), hasLength(4));
    });

    test('category filter is OR within the set', () {
      final result = filterPlaces(
        places,
        categories: {PlaceCategory.hotel, PlaceCategory.restaurant},
      );
      expect(result.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('country filter is OR within the set', () {
      final result = filterPlaces(places, countries: {'Japan'});
      expect(result.map((p) => p.id), ['c', 'd']);
    });

    test('category and country filters combine with AND', () {
      final result = filterPlaces(
        places,
        categories: {PlaceCategory.hotel},
        countries: {'Japan'},
      );
      expect(result.map((p) => p.id), ['c']);
    });

    test('an uncategorized place never matches an active category filter',
        () {
      final result = filterPlaces(places, categories: {PlaceCategory.hotel});
      expect(result.any((p) => p.id == 'd'), isFalse);
    });
  });

  group('Place category', () {
    test('copyWith sets and clears category', () {
      const place = Place(id: 'p1', name: 'Test');
      expect(place.category, isNull);

      final categorized =
          place.copyWith(category: () => PlaceCategory.restaurant);
      expect(categorized.category, PlaceCategory.restaurant);

      final cleared = categorized.copyWith(category: () => null);
      expect(cleared.category, isNull);
    });

    test('equality includes category', () {
      const a = Place(id: 'p1', name: 'Test', category: PlaceCategory.hotel);
      const b = Place(id: 'p1', name: 'Test', category: PlaceCategory.hotel);
      const c = Place(id: 'p1', name: 'Test', category: PlaceCategory.trek);
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
