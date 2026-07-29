import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/trips/domain/trip.dart';

Trip _trip({DateTime? start, DateTime? end}) => Trip(
      id: 't1',
      name: 'Test',
      destinations: const ['Krabi'],
      startDate: start ?? DateTime(2026, 7, 16),
      endDate: end ?? DateTime(2026, 7, 27),
    );

void main() {
  group('bucketTrip', () {
    test('day before start is upcoming', () {
      expect(
        bucketTrip(_trip(), DateTime(2026, 7, 15)),
        TripStatus.upcoming,
      );
    });

    test('first day is active (inclusive)', () {
      expect(bucketTrip(_trip(), DateTime(2026, 7, 16)), TripStatus.active);
    });

    test('mid trip is active', () {
      expect(bucketTrip(_trip(), DateTime(2026, 7, 20)), TripStatus.active);
    });

    test('last day is active (inclusive)', () {
      expect(bucketTrip(_trip(), DateTime(2026, 7, 27)), TripStatus.active);
    });

    test('day after end is past', () {
      expect(bucketTrip(_trip(), DateTime(2026, 7, 28)), TripStatus.past);
    });

    test('time of day is ignored — 23:59 on last day is still active', () {
      expect(
        bucketTrip(_trip(), DateTime(2026, 7, 27, 23, 59)),
        TripStatus.active,
      );
    });

    test('no dates at all is planned', () {
      const t = Trip(
        id: 'p1',
        name: 'Someday Japan',
        destinations: ['Tokyo'],
      );
      expect(bucketTrip(t, DateTime(2026, 7, 20)), TripStatus.planned);
    });

    test('start-only trip is upcoming before, then active forever', () {
      final t = Trip(
        id: 'o1',
        name: 'One way',
        destinations: const ['Lisbon'],
        startDate: DateTime(2026, 7, 16),
      );
      expect(bucketTrip(t, DateTime(2026, 7, 15)), TripStatus.upcoming);
      expect(bucketTrip(t, DateTime(2026, 7, 16)), TripStatus.active);
      expect(bucketTrip(t, DateTime(2027, 1, 1)), TripStatus.active);
    });

    test('single-day trip is active on that day', () {
      final t = _trip(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 1),
      );
      expect(bucketTrip(t, DateTime(2026, 8, 1)), TripStatus.active);
      expect(bucketTrip(t, DateTime(2026, 7, 31)), TripStatus.upcoming);
      expect(bucketTrip(t, DateTime(2026, 8, 2)), TripStatus.past);
    });
  });

  group('day counting', () {
    test('lengthInDays is inclusive', () {
      expect(_trip().lengthInDays, 12);
    });

    test('dayNumber is 1-based', () {
      expect(_trip().dayNumber(DateTime(2026, 7, 16)), 1);
      expect(_trip().dayNumber(DateTime(2026, 7, 19)), 4);
      expect(_trip().dayNumber(DateTime(2026, 7, 27)), 12);
    });

    test('open-ended trip has day number but no length', () {
      final t = Trip(
        id: 'o1',
        name: 'One way',
        destinations: const ['Lisbon'],
        startDate: DateTime(2026, 7, 16),
      );
      expect(t.lengthInDays, isNull);
      expect(t.dayNumber(DateTime(2026, 7, 19)), 4);
    });

    test('planned trip has neither', () {
      const t = Trip(id: 'p1', name: 'Japan', destinations: ['Tokyo']);
      expect(t.lengthInDays, isNull);
      expect(t.dayNumber(DateTime(2026, 7, 19)), isNull);
    });
  });

  group('launchRedirectPath', () {
    final today = DateTime(2026, 7, 20);

    test('exactly one active trip redirects to it', () {
      expect(launchRedirectPath([_trip()], today), '/trips/t1');
    });

    test('no trips means no redirect', () {
      expect(launchRedirectPath(const [], today), isNull);
    });

    test('only upcoming/past trips means no redirect', () {
      final upcoming = _trip(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
      );
      expect(launchRedirectPath([upcoming], today), isNull);
    });

    test('two active trips fall back to the list', () {
      final other = Trip(
        id: 't2',
        name: 'Other',
        destinations: const ['Rome'],
        startDate: DateTime(2026, 7, 18),
        endDate: DateTime(2026, 7, 22),
      );
      expect(launchRedirectPath([_trip(), other], today), isNull);
    });

    test('archived active trip does not redirect', () {
      final archived = _trip().copyWith(archived: true);
      expect(launchRedirectPath([archived], today), isNull);
    });
  });
}
