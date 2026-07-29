import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/trips/domain/trip.dart';

final _today = DateTime(2026, 7, 23);

Trip _trip({
  String id = 't1',
  DateTime? start,
  DateTime? end,
  bool archived = false,
}) =>
    Trip(
      id: id,
      name: 'Trip $id',
      destinations: const ['Krabi'],
      startDate: start,
      endDate: end,
      archived: archived,
    );

void main() {
  test('no trips means no days', () {
    expect(daysTraveled(const [], _today), 0);
  });

  test('a finished trip counts its full length, inclusive of both ends', () {
    final trip = _trip(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 10),
    );
    expect(daysTraveled([trip], _today), 10);
  });

  test('a single-day trip counts as one day, not zero', () {
    final trip = _trip(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 1),
    );
    expect(daysTraveled([trip], _today), 1);
  });

  test('an in-progress trip counts only up to today, not its full length', () {
    // Started 20 Jul, ends 31 Jul, today is 23 Jul -> 4 days so far.
    final trip = _trip(
      start: DateTime(2026, 7, 20),
      end: DateTime(2026, 7, 31),
    );
    expect(daysTraveled([trip], _today), 4);
  });

  test('a trip starting today counts as one day', () {
    expect(daysTraveled([_trip(start: _today, end: _today)], _today), 1);
  });

  test(
      'an upcoming trip contributes nothing — this is a record of travel, '
      'not a forecast', () {
    final trip = _trip(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 14),
    );
    expect(daysTraveled([trip], _today), 0);
  });

  test('a planned trip with no dates contributes nothing', () {
    expect(daysTraveled([_trip()], _today), 0);
  });

  test('an open-ended trip counts from its start up to today', () {
    final trip = _trip(start: DateTime(2026, 7, 20));
    expect(daysTraveled([trip], _today), 4);
  });

  test('archived trips are excluded', () {
    final trip = _trip(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 10),
      archived: true,
    );
    expect(daysTraveled([trip], _today), 0);
  });

  test('separate trips add up', () {
    final trips = [
      _trip(id: 'a', start: DateTime(2026, 6, 1), end: DateTime(2026, 6, 5)),
      _trip(id: 'b', start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 3)),
    ];
    expect(daysTraveled(trips, _today), 8);
  });

  test('overlapping trips count a shared day once, not twice', () {
    final trips = [
      _trip(id: 'a', start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 5)),
      // Overlaps on 4 and 5 Jul.
      _trip(id: 'b', start: DateTime(2026, 7, 4), end: DateTime(2026, 7, 8)),
    ];
    // 1-8 Jul inclusive = 8 distinct days (naive sum would say 10).
    expect(daysTraveled(trips, _today), 8);
  });

  test('spans a month boundary correctly', () {
    final trip = _trip(
      start: DateTime(2026, 6, 28),
      end: DateTime(2026, 7, 2),
    );
    expect(daysTraveled([trip], _today), 5);
  });

  test('spans a leap day', () {
    final trip = _trip(
      start: DateTime(2024, 2, 28),
      end: DateTime(2024, 3, 1),
    );
    // 28 Feb, 29 Feb, 1 Mar.
    expect(daysTraveled([trip], DateTime(2024, 6, 1)), 3);
  });

  test('time-of-day on the clock does not change the count', () {
    final trip = _trip(
      start: DateTime(2026, 7, 20, 23, 30),
      end: DateTime(2026, 7, 22, 1, 15),
    );
    expect(daysTraveled([trip], DateTime(2026, 7, 23, 18, 45)), 3);
  });
}
