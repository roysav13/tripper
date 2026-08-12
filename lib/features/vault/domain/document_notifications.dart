import 'package:intl/intl.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../l10n/app_localizations.dart';
import 'document.dart';
import 'expiry_checker.dart';

/// Pure, clock-injected (CLAUDE.md hard rule 2 — no DateTime.now() in
/// domain code). One future-dated reminder per document that: has an
/// expiry date, isn't already expired (an expired document belongs in the
/// vault list's red border, not a "coming up" notice), and falls inside
/// [noticeDays] of today. [noticeDays] comes from the user-configurable
/// `documentExpiryNoticeDaysProvider` setting (M5, 2026-07-23) — 0 means
/// the feature is off, matching that setting's own "off" semantics.
List<PendingNotification> documentExpiryNotifications(
  List<Document> docs,
  DateTime today, {
  required int noticeDays,
  required AppLocalizations l10n,
}) {
  if (noticeDays <= 0) return const [];
  final results = <PendingNotification>[];
  for (final doc in docs) {
    final expiry = doc.expiryDate;
    if (expiry == null) continue;
    if (!ExpiryChecker.isExpiringSoon(doc, today, noticeDays: noticeDays)) {
      continue;
    }
    final idealFireDate = DateTime(expiry.year, expiry.month, expiry.day)
        .subtract(Duration(days: noticeDays));
    // The ideal notice date (expiry minus the full window) can already be
    // in the past — e.g. the setting was just turned up to 90 days on a
    // document that's only 10 days out. Rather than silently dropping the
    // reminder (NotificationService.resyncAll filters anything not in the
    // future), fire it almost immediately instead of not at all. Note:
    // `isBefore`, not `!isAfter` — idealFireDate landing exactly on today
    // is a valid fire time, not a "clamp to soon" case (that boundary bug
    // shipped once already, caught by a test expecting exactly `today`).
    final fireAt = idealFireDate.isBefore(today) ? _soon(today) : idealFireDate;
    results.add(
      PendingNotification(
        entityType: 'document',
        entityId: doc.id,
        triggerType: NotificationTriggerType.documentExpiry,
        title: l10n.docExpiryNotificationTitle(doc.title),
        body: l10n.docExpiryNotificationBody(
          DateFormat('dd MMM yyyy', 'en_US').format(expiry),
        ),
        at: fireAt,
      ),
    );
  }
  return results;
}

DateTime _soon(DateTime today) => today.add(const Duration(minutes: 1));
