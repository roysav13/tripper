import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/trips/domain/trip_validator.dart';

void main() {
  final start = DateTime(2026, 7, 16);
  final end = DateTime(2026, 7, 27);

  test('valid input has no errors', () {
    expect(
      validateTrip(
        name: 'Thailand',
        destinations: const ['Krabi'],
        startDate: start,
        endDate: end,
      ),
      isEmpty,
    );
  });

  test('empty or whitespace name', () {
    expect(
      validateTrip(
        name: '   ',
        destinations: const ['Krabi'],
        startDate: start,
        endDate: end,
      ),
      contains(TripValidationError.nameRequired),
    );
  });

  test('no destinations, or only blank ones', () {
    expect(
      validateTrip(
        name: 'Trip',
        destinations: const [],
        startDate: start,
        endDate: end,
      ),
      contains(TripValidationError.noDestination),
    );
    expect(
      validateTrip(
        name: 'Trip',
        destinations: const ['  '],
        startDate: start,
        endDate: end,
      ),
      contains(TripValidationError.noDestination),
    );
  });

  test('inverted dates', () {
    expect(
      validateTrip(
        name: 'Trip',
        destinations: const ['Krabi'],
        startDate: end,
        endDate: start,
      ),
      contains(TripValidationError.datesInverted),
    );
  });

  test('same-day trip is valid', () {
    expect(
      validateTrip(
        name: 'Trip',
        destinations: const ['Krabi'],
        startDate: start,
        endDate: start,
      ),
      isEmpty,
    );
  });

  test('no dates at all is valid (planned trip)', () {
    expect(
      validateTrip(
        name: 'Japan someday',
        destinations: const ['Tokyo'],
        startDate: null,
        endDate: null,
      ),
      isEmpty,
    );
  });

  test('start without end is valid (one-way)', () {
    expect(
      validateTrip(
        name: 'One way',
        destinations: const ['Lisbon'],
        startDate: start,
        endDate: null,
      ),
      isEmpty,
    );
  });

  test('end without start is rejected', () {
    expect(
      validateTrip(
        name: 'Trip',
        destinations: const ['Krabi'],
        startDate: null,
        endDate: end,
      ),
      contains(TripValidationError.endWithoutStart),
    );
  });

  test('trip longer than a year is rejected', () {
    expect(
      validateTrip(
        name: 'Trip',
        destinations: const ['Krabi'],
        startDate: start,
        endDate: start.add(const Duration(days: 400)),
      ),
      contains(TripValidationError.tooLong),
    );
  });
}
