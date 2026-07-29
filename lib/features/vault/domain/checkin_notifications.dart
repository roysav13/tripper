import '../../../core/notifications/notification_service.dart';
import '../../../l10n/app_localizations.dart';
import 'document.dart';

/// Fixed offset before a flight's departure, deliberately not precise.
/// SPEC is explicit: real airlines vary 24-48h; a fake-precise per-airline
/// lookup isn't worth building for v1, and the notification copy itself
/// says so rather than implying certainty it doesn't have.
const kCheckInOffsetHours = 24;

/// Key in `Document.details` — set from the flight document form's
/// departure-time picker (M5.3), an ISO-8601 string. No other Phase-2a
/// feature reads or writes this key.
const kDepartureTimeDetailKey = 'departureTime';

/// Pure, clock-injected (CLAUDE.md hard rule 2). One reminder per flight
/// document with a parsed departure time that hasn't already departed.
/// No-op — not an error — for documents missing or with an unparsable
/// departure time, per SPEC's explicit instruction; most flight documents
/// won't have one until OCR (M5.4) or email parsing (M5.11) exist to fill
/// it in automatically, so this quietly does nothing for those today.
List<PendingNotification> checkInOpensNotifications(
  List<Document> docs,
  DateTime today, {
  required AppLocalizations l10n,
}) {
  final results = <PendingNotification>[];
  for (final doc in docs) {
    if (doc.category != DocumentCategory.flight) continue;
    final raw = doc.details[kDepartureTimeDetailKey];
    if (raw == null) continue;
    final departure = DateTime.tryParse(raw);
    if (departure == null) continue;
    if (!departure.isAfter(today)) continue; // already departed

    final idealFireDate =
        departure.subtract(const Duration(hours: kCheckInOffsetHours));
    // Same reasoning as the other two M5.2 sources: if check-in is
    // already open by the time this resyncs (app opened late, or the
    // flight is under 24h out when the document was saved), fire almost
    // immediately rather than silently dropping a still-useful reminder.
    // `isBefore`, not `!isAfter` — landing exactly on today is still a
    // valid fire time, not a clamp-to-soon case.
    final fireAt = idealFireDate.isBefore(today) ? _soon(today) : idealFireDate;

    results.add(
      PendingNotification(
        entityType: 'document',
        entityId: doc.id,
        triggerType: NotificationTriggerType.checkInOpens,
        title: l10n.checkInNotificationTitle(doc.title),
        body: l10n.checkInNotificationBody,
        at: fireAt,
      ),
    );
  }
  return results;
}

DateTime _soon(DateTime today) => today.add(const Duration(minutes: 1));
