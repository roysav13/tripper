import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/notifications/notification_service.dart';
import 'package:tripper/features/vault/domain/checkin_notifications.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final today = DateTime(2026, 7, 23, 9);

  Document flightDoc({
    String id = 'f1',
    String title = 'BKK -> LHR',
    Map<String, String> details = const {},
  }) =>
      Document(
        id: id,
        title: title,
        category: DocumentCategory.flight,
        createdAt: today,
        details: details,
      );

  test('no-op for a flight document with no departure time set', () {
    final result = checkInOpensNotifications([flightDoc()], today, l10n: l10n);
    expect(result, isEmpty);
  });

  test('no-op for a non-flight document, even with a departureTime key', () {
    final doc = Document(
      id: 'x',
      title: 'Hotel booking',
      category: DocumentCategory.stay,
      createdAt: today,
      details: {
        kDepartureTimeDetailKey: DateTime(2026, 8, 1).toIso8601String(),
      },
    );
    expect(checkInOpensNotifications([doc], today, l10n: l10n), isEmpty);
  });

  test('no-op for an unparsable departure time — never throws', () {
    final doc = flightDoc(details: {kDepartureTimeDetailKey: 'not a date'});
    expect(checkInOpensNotifications([doc], today, l10n: l10n), isEmpty);
  });

  test('no-op once the flight has already departed', () {
    final doc = flightDoc(
      details: {
        kDepartureTimeDetailKey:
            today.subtract(const Duration(hours: 2)).toIso8601String(),
      },
    );
    expect(checkInOpensNotifications([doc], today, l10n: l10n), isEmpty);
  });

  test('fires exactly 24h before a future departure', () {
    final departure = DateTime(2026, 8, 1, 14, 30);
    final doc = flightDoc(
      details: {
        kDepartureTimeDetailKey: departure.toIso8601String(),
      },
    );
    final result = checkInOpensNotifications([doc], today, l10n: l10n);
    expect(result, hasLength(1));
    final n = result.single;
    expect(n.entityType, 'document');
    expect(n.entityId, 'f1');
    expect(n.triggerType, NotificationTriggerType.checkInOpens);
    expect(n.title, 'Check-in opens for BKK -> LHR');
    expect(
      n.body,
      'Check-in usually opens 24 hours before departure. Airlines vary '
      'this 24–48h, so double-check with yours.',
    );
    expect(n.at, DateTime(2026, 7, 31, 14, 30));
  });

  test(
      'when check-in is already open (departure < 24h out but still '
      'future), fires almost immediately instead of being dropped', () {
    final departure = today.add(const Duration(hours: 5));
    final doc = flightDoc(
      details: {
        kDepartureTimeDetailKey: departure.toIso8601String(),
      },
    );
    final result = checkInOpensNotifications([doc], today, l10n: l10n);
    expect(result, hasLength(1));
    expect(result.single.at.isAfter(today), isTrue);
    expect(
      result.single.at.difference(today),
      lessThan(const Duration(hours: 1)),
    );
  });
}
