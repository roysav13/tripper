import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/notifications/notification_service.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/domain/trip_notifications.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final today = DateTime(2026, 7, 23);

  Document doc({DateTime? expiry, String id = 'd1'}) => Document(
        id: id,
        title: 'Passport',
        category: DocumentCategory.passportId,
        expiryDate: expiry,
      );

  Trip trip({
    String id = 't1',
    String name = 'Thailand',
    DateTime? startDate,
    DateTime? endDate,
    bool archived = false,
  }) =>
      Trip(
        id: id,
        name: name,
        destinations: const ['Krabi'],
        startDate: startDate,
        endDate: endDate,
        archived: archived,
      );

  test('archived trip is skipped', () {
    final t = trip(
      startDate: today.add(const Duration(days: kTripCountdownDays)),
      archived: true,
    );
    expect(
      tripCountdownNotifications([t], const {}, today, l10n: l10n),
      isEmpty,
    );
  });

  test('planned trip with no start date is skipped', () {
    final t = trip();
    expect(
      tripCountdownNotifications([t], const {}, today, l10n: l10n),
      isEmpty,
    );
  });

  test(
      'trip already active (started) is skipped — countdown is pre-trip '
      'only', () {
    final t = trip(startDate: today.subtract(const Duration(days: 1)));
    expect(
      tripCountdownNotifications([t], const {}, today, l10n: l10n),
      isEmpty,
    );
  });

  test('past trip is skipped', () {
    final t = trip(
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 1, 10),
    );
    expect(
      tripCountdownNotifications([t], const {}, today, l10n: l10n),
      isEmpty,
    );
  });

  test('upcoming trip with no risky documents gets the "clear" body', () {
    // today = 23 Jul 2026 -> start = 12 Aug 2026, fires 3 days before.
    final start = today.add(const Duration(days: 20));
    final t =
        trip(startDate: start, endDate: start.add(const Duration(days: 5)));
    final result = tripCountdownNotifications([t], const {}, today, l10n: l10n);
    expect(result, hasLength(1));
    final n = result.single;
    expect(n.entityType, 'trip');
    expect(n.entityId, 't1');
    expect(n.triggerType, NotificationTriggerType.tripCountdown);
    expect(n.title, 'Thailand starts soon');
    expect(n.body, "Starts in 3 days — everything's in order.");
    expect(n.at, DateTime(2026, 8, 9));
  });

  test('upcoming trip with risky documents names the count (singular)', () {
    final start = today.add(const Duration(days: 20));
    final end = start.add(const Duration(days: 5));
    final t = trip(startDate: start, endDate: end);
    // Expires well before end + 90-day buffer -> risky.
    final risky = doc(id: 'r1', expiry: end.add(const Duration(days: 10)));
    final result = tripCountdownNotifications(
      [t],
      {
        't1': [risky],
      },
      today,
      l10n: l10n,
    );
    expect(
      result.single.body,
      'Starts in 3 days — 1 document needs attention.',
    );
  });

  test('upcoming trip with multiple risky documents uses the plural', () {
    final start = today.add(const Duration(days: 20));
    final end = start.add(const Duration(days: 5));
    final t = trip(startDate: start, endDate: end);
    final risky1 = doc(id: 'r1', expiry: end.add(const Duration(days: 10)));
    final risky2 = doc(id: 'r2', expiry: end.add(const Duration(days: 20)));
    final safe = doc(id: 's1', expiry: end.add(const Duration(days: 200)));
    final result = tripCountdownNotifications(
      [t],
      {
        't1': [risky1, risky2, safe],
      },
      today,
      l10n: l10n,
    );
    expect(
      result.single.body,
      'Starts in 3 days — 2 documents need attention.',
    );
  });

  test('documents linked to a different trip are not counted', () {
    final start = today.add(const Duration(days: 20));
    final end = start.add(const Duration(days: 5));
    final t = trip(startDate: start, endDate: end);
    final riskyForOtherTrip =
        doc(id: 'r1', expiry: end.add(const Duration(days: 10)));
    final result = tripCountdownNotifications(
      [t],
      {
        'some-other-trip': [riskyForOtherTrip],
      },
      today,
      l10n: l10n,
    );
    expect(result.single.body, "Starts in 3 days — everything's in order.");
  });

  test(
      'when the ideal fire date has already passed (trip created close to '
      'its start), fires almost immediately instead of being dropped', () {
    // Starts in 1 day — inside the 3-day countdown window already.
    final start = today.add(const Duration(days: 1));
    final t = trip(startDate: start);
    final result = tripCountdownNotifications([t], const {}, today, l10n: l10n);
    expect(result, hasLength(1));
    expect(result.single.at.isAfter(today), isTrue);
    expect(
      result.single.at.difference(today),
      lessThan(const Duration(hours: 1)),
    );
  });
}
