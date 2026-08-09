import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/domain/journal_entry_queries.dart';

JournalEntry _e(
  String id,
  DateTime loggedAt, {
  double? lat,
  double? lng,
}) =>
    JournalEntry(
      id: id,
      tripId: 't1',
      summary: id,
      loggedAt: loggedAt,
      createdAt: loggedAt,
      lat: lat,
      lng: lng,
    );

void main() {
  group('latestLocatedEntry', () {
    test('returns null for an empty list', () {
      expect(latestLocatedEntry([]), isNull);
    });

    test('returns null when no entry has a location', () {
      final entries = [_e('a', DateTime(2026, 1, 1))];
      expect(latestLocatedEntry(entries), isNull);
    });

    test('returns the located entry with the latest loggedAt', () {
      final entries = [
        _e('early', DateTime(2026, 1, 1), lat: 1, lng: 1),
        _e('unlocated', DateTime(2026, 1, 5)),
        _e('late', DateTime(2026, 1, 10), lat: 2, lng: 2),
      ];
      expect(latestLocatedEntry(entries)!.id, 'late');
    });
  });

  group('journeyConnections', () {
    test('empty for fewer than two located entries', () {
      expect(journeyConnections([]), isEmpty);
      expect(
        journeyConnections([_e('a', DateTime(2026, 1, 1), lat: 1, lng: 1)]),
        isEmpty,
      );
    });

    test('connects consecutive located entries in chronological order', () {
      final entries = [
        _e('c', DateTime(2026, 1, 3), lat: 3, lng: 3),
        _e('a', DateTime(2026, 1, 1), lat: 1, lng: 1),
        _e('unlocated', DateTime(2026, 1, 2)),
        _e('b', DateTime(2026, 1, 2, 12), lat: 2, lng: 2),
      ];
      final pairs = journeyConnections(entries);
      expect(pairs, hasLength(2));
      expect(pairs[0].$1.id, 'a');
      expect(pairs[0].$2.id, 'b');
      expect(pairs[1].$1.id, 'b');
      expect(pairs[1].$2.id, 'c');
    });
  });

  group('groupEntriesByDay', () {
    test('empty list produces no groups', () {
      expect(groupEntriesByDay([]), isEmpty);
    });

    test('groups same-day entries together, preserving order, sorted by day',
        () {
      final entries = [
        _e('day2-first', DateTime(2026, 1, 2, 9)),
        _e('day1-only', DateTime(2026, 1, 1, 14)),
        _e('day2-second', DateTime(2026, 1, 2, 18)),
      ];
      final groups = groupEntriesByDay(entries);
      expect(groups, hasLength(2));
      expect(groups[0].map((e) => e.id).toList(), ['day1-only']);
      expect(
        groups[1].map((e) => e.id).toList(),
        ['day2-first', 'day2-second'],
      );
    });
  });

  group('groupEntriesByProximity', () {
    test('returns empty list for empty input', () {
      expect(groupEntriesByProximity([], 0), isEmpty);
    });

    test('a single located entry is its own cluster', () {
      final entries = [_e('a', DateTime(2026, 1, 1), lat: 40.0, lng: -74.0)];
      final clusters = groupEntriesByProximity(entries, 0);
      expect(clusters, hasLength(1));
      expect(clusters.single.map((e) => e.id), ['a']);
    });

    test('unlocated entries are excluded from every cluster', () {
      final entries = [
        _e('a', DateTime(2026, 1, 1), lat: 40.0, lng: -74.0),
        _e('unlocated', DateTime(2026, 1, 2)),
      ];
      final clusters = groupEntriesByProximity(entries, 0);
      expect(clusters, hasLength(1));
      expect(clusters.single.map((e) => e.id), ['a']);
    });

    test('entries far apart never cluster regardless of zoom', () {
      final entries = [
        _e('nyc', DateTime(2026, 1, 1), lat: 40.7, lng: -74.0),
        _e('tokyo', DateTime(2026, 1, 2), lat: 35.7, lng: 139.7),
      ];
      // zoom: -1 gives the largest possible threshold (100km) — even then,
      // two points on opposite sides of the planet must not cluster.
      final clusters = groupEntriesByProximity(entries, -1);
      expect(clusters, hasLength(2));
    });

    test('entries within threshold at low zoom cluster, and split apart '
        'once zoom shrinks the threshold below their distance', () {
      // ~15km apart (0.135 degrees latitude at this longitude).
      final entries = [
        _e('a', DateTime(2026, 1, 1), lat: 40.000, lng: -74.000),
        _e('b', DateTime(2026, 1, 2), lat: 40.135, lng: -74.000),
      ];
      // zoom 0: threshold 50km — within range, one cluster.
      final atRest = groupEntriesByProximity(entries, 0);
      expect(atRest, hasLength(1));
      expect(atRest.single, hasLength(2));

      // zoom 3: threshold 6.25km — 15km apart exceeds it, two clusters.
      final zoomedIn = groupEntriesByProximity(entries, 3);
      expect(zoomedIn, hasLength(2));
    });

    test('transitive chaining: A-C exceeds the threshold directly but '
        'both are within threshold of B, so all three cluster together',
        () {
      // Collinear along longitude, ~15km between consecutive points
      // (0.135 degrees latitude each step), ~30km between the ends.
      final entries = [
        _e('a', DateTime(2026, 1, 3), lat: 40.000, lng: -74.000),
        _e('b', DateTime(2026, 1, 1), lat: 40.135, lng: -74.000),
        _e('c', DateTime(2026, 1, 2), lat: 40.270, lng: -74.000),
      ];
      // zoom 1: threshold 25km. a-b ~15km (in range), b-c ~15km (in
      // range), a-c ~30km (out of range directly) — must still merge
      // into one cluster via b.
      final clusters = groupEntriesByProximity(entries, 1);
      expect(clusters, hasLength(1));
      expect(clusters.single, hasLength(3));
    });

    test('each cluster is sorted ascending by loggedAt regardless of '
        'input order', () {
      final entries = [
        _e('later', DateTime(2026, 1, 10), lat: 40.0, lng: -74.0),
        _e('earlier', DateTime(2026, 1, 1), lat: 40.001, lng: -74.001),
      ];
      final clusters = groupEntriesByProximity(entries, 0);
      expect(clusters, hasLength(1));
      expect(clusters.single.map((e) => e.id), ['earlier', 'later']);
    });
  });
}
