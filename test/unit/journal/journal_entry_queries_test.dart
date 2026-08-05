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

    test('connects consecutive located entries in chronological order',
        () {
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
}
