import '../../../core/notifications/notification_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../vault/domain/document.dart';
import '../../vault/domain/expiry_checker.dart';
import 'trip.dart';

/// How many days before a trip starts the countdown nudge fires. Not
/// user-configurable (unlike the document-expiry window) — SPEC's example
/// copy ("starts in 3 days") is this fixed number. There's no passport-
/// validity-style convention to anchor a configurable version to, so it
/// stays fixed until there's a real reason to change that.
const kTripCountdownDays = 3;

/// Pure, clock-injected (CLAUDE.md hard rule 2). One reminder per
/// upcoming, non-archived trip with a start date, fired
/// [kTripCountdownDays] before it starts, naming how many of its linked
/// documents are still risky for it (`ExpiryChecker.isRiskyForTrip` —
/// expiring/expired relative to *this* trip's dates, not just "soon" in
/// general).
List<PendingNotification> tripCountdownNotifications(
  List<Trip> trips,
  Map<String, List<Document>> documentsByTrip,
  DateTime today, {
  required AppLocalizations l10n,
}) {
  final results = <PendingNotification>[];
  for (final trip in trips) {
    if (trip.archived) continue;
    final start = trip.startDate;
    if (start == null) continue; // planned trips have nothing to count down to
    if (bucketTrip(trip, today) != TripStatus.upcoming) continue;

    final startDateOnly = DateTime(start.year, start.month, start.day);
    final idealFireDate =
        startDateOnly.subtract(const Duration(days: kTripCountdownDays));
    // Same reasoning as the document-expiry source: a trip already inside
    // the countdown window when this resyncs (app wasn't opened in time,
    // or the trip was just created close to its start date) still gets a
    // reminder, just an immediate one instead of a silently dropped one.
    // `isBefore`, not `!isAfter` — landing exactly on today is still a
    // valid fire time, not a clamp-to-soon case.
    final fireAt = idealFireDate.isBefore(today) ? _soon(today) : idealFireDate;

    final linkedDocs = documentsByTrip[trip.id] ?? const [];
    final needingAttention =
        linkedDocs.where((d) => ExpiryChecker.isRiskyForTrip(d, trip)).length;

    results.add(
      PendingNotification(
        entityType: 'trip',
        entityId: trip.id,
        triggerType: NotificationTriggerType.tripCountdown,
        title: l10n.tripCountdownNotificationTitle(trip.name),
        body: needingAttention > 0
            ? l10n.tripCountdownNotificationBodyWithIssues(
                kTripCountdownDays,
                needingAttention,
              )
            : l10n.tripCountdownNotificationBodyClear(kTripCountdownDays),
        at: fireAt,
      ),
    );
  }
  return results;
}

DateTime _soon(DateTime today) => today.add(const Duration(minutes: 1));
