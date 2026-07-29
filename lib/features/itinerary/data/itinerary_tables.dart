import 'package:drift/drift.dart';

import '../../places/data/place_tables.dart';
import '../../trips/data/trip_tables.dart';

/// Dormant table — the only surviving piece of the withdrawn Plan
/// feature (see `docs/adr/ADR-001-itinerary-redesign.md`). Nothing reads
/// or writes it; it stays registered so schema v9 remains valid for
/// devices already on it, and so stored plans survive a revival. Every
/// other file under `lib/features/itinerary/` was deleted on 2026-07-26.
@DataClassName('ItineraryItemRow')
class ItineraryItems extends Table {
  TextColumn get id => text()();

  /// An itinerary only means anything inside its trip — CASCADE, same
  /// reasoning as Expenses.
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// Date-only semantics (time lives in [startTime]) — matches how Trip
  /// dates are handled everywhere else.
  DateTimeColumn get date => dateTime()();

  /// Minutes from midnight, nullable — plenty of plans are "sometime on
  /// Tuesday". Stored as an int rather than a DateTime so it can't drift
  /// away from [date] or carry a bogus timezone.
  IntColumn get startMinutes => integer().nullable()();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  /// Optional link to a saved place (M3). SET NULL, not CASCADE:
  /// deleting a wishlist place shouldn't silently delete the plan that
  /// referenced it.
  TextColumn get placeId =>
      text().nullable().references(Places, #id, onDelete: KeyAction.setNull)();

  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Position within its day. Only meaningful relative to siblings on the
  /// same date; gaps are fine and expected after deletes.
  IntColumn get orderIndex => integer()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
