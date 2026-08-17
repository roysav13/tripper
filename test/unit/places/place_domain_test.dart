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

  group('Place summary', () {
    test('hasSummary is false for both "never tried" and "tried, empty"', () {
      const untried = Place(id: 'p1', name: 'Test');
      expect(untried.hasSummary, isFalse);

      final triedEmpty =
          untried.copyWith(summaryFetchedAt: () => DateTime(2026, 8, 17));
      expect(triedEmpty.hasSummary, isFalse);
      expect(triedEmpty.summary, isNull);
      expect(triedEmpty.summaryFetchedAt, isNotNull);
    });

    test('hasSummary is false for a blank/whitespace-only summary', () {
      const place = Place(id: 'p1', name: 'Test', summary: '   ');
      expect(place.hasSummary, isFalse);
    });

    test('hasSummary is true once real text is set', () {
      const place = Place(id: 'p1', name: 'Test', summary: 'A quiet cove.');
      expect(place.hasSummary, isTrue);
    });

    test('copyWith sets and clears summary independently of fetchedAt', () {
      const place = Place(id: 'p1', name: 'Test');
      final withSummary = place.copyWith(
        summary: () => 'A quiet cove.',
        summaryFetchedAt: () => DateTime(2026, 8, 17),
      );
      expect(withSummary.summary, 'A quiet cove.');

      final cleared = withSummary.copyWith(summary: () => null);
      expect(cleared.summary, isNull);
      // fetchedAt untouched — clearing the text alone doesn't erase the
      // fact that a fetch already happened.
      expect(cleared.summaryFetchedAt, DateTime(2026, 8, 17));
    });

    test('equality includes summary and summaryFetchedAt', () {
      final a = Place(
        id: 'p1',
        name: 'Test',
        summary: 'Text',
        summaryFetchedAt: DateTime(2026, 8, 17),
      );
      final b = Place(
        id: 'p1',
        name: 'Test',
        summary: 'Text',
        summaryFetchedAt: DateTime(2026, 8, 17),
      );
      final c = Place(
        id: 'p1',
        name: 'Test',
        summary: 'Different',
        summaryFetchedAt: DateTime(2026, 8, 17),
      );
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
