import 'package:flutter/foundation.dart';

/// planned  — no start date yet ("someday: Japan")
/// upcoming — starts in the future
/// active   — started; open-ended trips (no end date) stay active
/// past     — ended
enum TripStatus { active, upcoming, planned, past }

@immutable
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.destinations,
    this.startDate,
    this.endDate,
    this.colorTag = 0,
    this.archived = false,
    this.completionPromptShown = false,
    this.coverPhotoPath,
  }) : assert(
          startDate != null || endDate == null,
          'endDate requires startDate',
        );

  final String id;
  final String name;

  /// Ordered: Krabi -> Ko Pha-ngan -> Bangkok.
  final List<String> destinations;

  /// Both optional (SPEC: planned trips, one-way tickets).
  /// Date-only semantics — time components are ignored everywhere.
  final DateTime? startDate;
  final DateTime? endDate;

  final int colorTag;
  final bool archived;

  /// The one-time "trip over — mark places visited?" prompt was offered.
  final bool completionPromptShown;

  /// Path to a locally-stored cover photo. Null means no photo — render
  /// the generated gradient fallback instead (redesign spec §6).
  final String? coverPhotoPath;

  /// Inclusive length; null when open-ended or unplanned.
  int? get lengthInDays => (startDate == null || endDate == null)
      ? null
      : _dateOnly(endDate!).difference(_dateOnly(startDate!)).inDays + 1;

  /// 1-based day number for [today]; null when no start date.
  int? dayNumber(DateTime today) => startDate == null
      ? null
      : _dateOnly(today).difference(_dateOnly(startDate!)).inDays + 1;

  Trip copyWith({
    String? name,
    List<String>? destinations,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    int? colorTag,
    bool? archived,
    bool? completionPromptShown,
    String? Function()? coverPhotoPath,
  }) {
    return Trip(
      id: id,
      name: name ?? this.name,
      destinations: destinations ?? this.destinations,
      startDate: startDate == null ? this.startDate : startDate(),
      endDate: endDate == null ? this.endDate : endDate(),
      colorTag: colorTag ?? this.colorTag,
      archived: archived ?? this.archived,
      completionPromptShown:
          completionPromptShown ?? this.completionPromptShown,
      coverPhotoPath:
          coverPhotoPath == null ? this.coverPhotoPath : coverPhotoPath(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Trip &&
      other.id == id &&
      other.name == name &&
      listEquals(other.destinations, destinations) &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.colorTag == colorTag &&
      other.archived == archived &&
      other.coverPhotoPath == coverPhotoPath;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        Object.hashAll(destinations),
        startDate,
        endDate,
        colorTag,
        archived,
        coverPhotoPath,
      );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Buckets by calendar date, inclusive on both ends.
TripStatus bucketTrip(Trip trip, DateTime today) {
  final start = trip.startDate;
  if (start == null) return TripStatus.planned;
  final d = _dateOnly(today);
  if (d.isBefore(_dateOnly(start))) return TripStatus.upcoming;
  final end = trip.endDate;
  if (end != null && d.isAfter(_dateOnly(end))) return TripStatus.past;
  return TripStatus.active;
}

/// Days actually travelled across every non-archived trip (M5.6).
///
/// Counts only days that have happened: a past trip contributes its full
/// length, an active one contributes up to and including today, and
/// upcoming/planned trips contribute nothing — a "days travelled" figure
/// that counts a holiday you haven't taken yet isn't a trophy, it's a
/// forecast.
///
/// Overlapping trips are counted once. Two trips sharing a day is a data
/// entry quirk, but double-counting it would inflate the number in a way
/// that's impossible to explain looking at the list.
int daysTraveled(List<Trip> trips, DateTime today) {
  final days = <DateTime>{};
  final todayOnly = _dateOnly(today);
  for (final trip in trips) {
    if (trip.archived) continue;
    final start = trip.startDate;
    if (start == null) continue;
    var day = _dateOnly(start);
    if (day.isAfter(todayOnly)) continue; // hasn't begun
    // Open-ended trips are treated as running until today.
    final end = trip.endDate == null ? todayOnly : _dateOnly(trip.endDate!);
    final last = end.isAfter(todayOnly) ? todayOnly : end;
    while (!day.isAfter(last)) {
      days.add(day);
      day = DateTime(day.year, day.month, day.day + 1);
    }
  }
  return days.length;
}

/// Launch behavior (SPEC §3.1.1): exactly one active trip -> open it.
String? launchRedirectPath(List<Trip> trips, DateTime today) {
  final active = trips
      .where((t) => !t.archived && bucketTrip(t, today) == TripStatus.active)
      .toList();
  if (active.length == 1) return '/trips/${active.single.id}';
  return null;
}
