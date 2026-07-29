import '../../trips/domain/trip.dart';
import 'document.dart';

/// Passport six-month-rule approximation: a document is risky for a trip
/// when it expires before the trip's end plus this buffer.
const kExpiryBufferDays = 90;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Pure, clock-injected expiry logic (SPEC — no DateTime.now() in domain).
abstract final class ExpiryChecker {
  static bool isExpired(Document doc, DateTime today) {
    final expiry = doc.expiryDate;
    if (expiry == null) return false;
    return _dateOnly(expiry).isBefore(_dateOnly(today));
  }

  /// Expires within [noticeDays] from today (but not yet expired). Not
  /// used for the vault list's red border (M5, 2026-07-23 — that's
  /// [isExpired] only now); this feeds the M5.2 expiry-notification
  /// source, where [noticeDays] comes from the user-configurable
  /// `documentExpiryNoticeDaysProvider` setting rather than always being
  /// [kExpiryBufferDays].
  static bool isExpiringSoon(
    Document doc,
    DateTime today, {
    int noticeDays = kExpiryBufferDays,
  }) {
    final expiry = doc.expiryDate;
    if (expiry == null) return false;
    if (isExpired(doc, today)) return false;
    if (noticeDays <= 0) return false;
    // Calendar arithmetic, not Duration — DST transitions make
    // add(Duration(days: n)) land a day off around clock changes.
    final horizon = DateTime(today.year, today.month, today.day + noticeDays);
    return !_dateOnly(expiry).isAfter(horizon);
  }

  static bool needsAttention(
    Document doc,
    DateTime today, {
    int noticeDays = kExpiryBufferDays,
  }) =>
      isExpired(doc, today) ||
      isExpiringSoon(doc, today, noticeDays: noticeDays);

  /// Risky for a trip: expiry lands before trip end + buffer.
  /// Trips without any dates can't be assessed -> never risky.
  static bool isRiskyForTrip(Document doc, Trip trip) {
    final expiry = doc.expiryDate;
    final tripEnd = trip.endDate ?? trip.startDate;
    if (expiry == null || tripEnd == null) return false;
    final required = DateTime(
      tripEnd.year,
      tripEnd.month,
      tripEnd.day + kExpiryBufferDays,
    );
    return _dateOnly(expiry).isBefore(required);
  }
}
