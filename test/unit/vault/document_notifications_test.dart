import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/notifications/notification_service.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/domain/document_notifications.dart';
import 'package:tripper/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final today = DateTime(2026, 7, 23);

  Document doc({
    DateTime? expiry,
    String id = 'd1',
    String title = 'Passport',
  }) =>
      Document(
        id: id,
        title: title,
        category: DocumentCategory.passportId,
        expiryDate: expiry,
      );

  test('noticeDays <= 0 returns nothing, regardless of expiry', () {
    final result = documentExpiryNotifications(
      [doc(expiry: today.add(const Duration(days: 5)))],
      today,
      noticeDays: 0,
      l10n: l10n,
    );
    expect(result, isEmpty);
  });

  test('document without an expiry date is skipped', () {
    final result = documentExpiryNotifications(
      [doc()],
      today,
      noticeDays: 90,
      l10n: l10n,
    );
    expect(result, isEmpty);
  });

  test(
      'already-expired document is skipped (that\'s the border, not a '
      'notice)', () {
    final result = documentExpiryNotifications(
      [doc(expiry: DateTime(2026, 1, 1))],
      today,
      noticeDays: 90,
      l10n: l10n,
    );
    expect(result, isEmpty);
  });

  test('document outside the notice window is skipped', () {
    final result = documentExpiryNotifications(
      [doc(expiry: today.add(const Duration(days: 100)))],
      today,
      noticeDays: 30,
      l10n: l10n,
    );
    expect(result, isEmpty);
  });

  test('document inside the window produces a correctly-timed reminder', () {
    final expiry = DateTime(2026, 10, 21); // 90 days out from today
    final result = documentExpiryNotifications(
      [doc(expiry: expiry, id: 'd1', title: 'Passport')],
      today,
      noticeDays: 90,
      l10n: l10n,
    );
    expect(result, hasLength(1));
    final n = result.single;
    expect(n.entityType, 'document');
    expect(n.entityId, 'd1');
    expect(n.triggerType, NotificationTriggerType.documentExpiry);
    expect(n.title, 'Passport expires soon');
    expect(n.body, 'Expires 21 Oct 2026.');
    // idealFireDate = expiry - 90 days = today.
    expect(n.at, DateTime(2026, 7, 23));
  });

  test(
      'when the ideal notice date has already passed, fires almost '
      'immediately instead of being dropped', () {
    // Only 10 days out, but noticeDays is 90 — the "ideal" fire date
    // (expiry - 90d) is 80 days in the past.
    final expiry = today.add(const Duration(days: 10));
    final result = documentExpiryNotifications(
      [doc(expiry: expiry)],
      today,
      noticeDays: 90,
      l10n: l10n,
    );
    expect(result, hasLength(1));
    expect(result.single.at.isAfter(today), isTrue);
    // "Almost immediately" — not pushed out anywhere near the real window.
    expect(
      result.single.at.difference(today),
      lessThan(const Duration(hours: 1)),
    );
  });

  test('multiple documents each produce their own reminder', () {
    final result = documentExpiryNotifications(
      [
        doc(
          id: 'a',
          title: 'Passport',
          expiry: today.add(const Duration(days: 5)),
        ),
        doc(
          id: 'b',
          title: 'Visa',
          expiry: today.add(const Duration(days: 10)),
        ),
      ],
      today,
      noticeDays: 30,
      l10n: l10n,
    );
    expect(result.map((n) => n.entityId), containsAll(['a', 'b']));
  });
}
