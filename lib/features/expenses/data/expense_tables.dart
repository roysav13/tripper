import 'package:drift/drift.dart';

import '../../trips/data/trip_tables.dart';

@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();

  /// Expenses only exist within a trip — deleting the trip deletes them
  /// (CASCADE, unlike Places' SET NULL: a place outlives its trip as a
  /// wishlist entry, a spend record without its trip is meaningless).
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// Minor units (agorot/cents) as an integer — never a float. 12.30 is
  /// 1230, so sums stay exact; binary floating point can't represent
  /// 0.1 and running totals would drift.
  IntColumn get amountMinor => integer()();

  /// ISO-4217, uppercase. v1 is single-currency per trip (SPEC §3.2.1 —
  /// no live conversion), but stored per row so a future multi-currency
  /// pass doesn't need a migration.
  TextColumn get currency => text().withLength(min: 3, max: 3)();

  /// Index into ExpenseCategory enum.
  IntColumn get category => integer()();

  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  /// Conversion into the user's home currency, computed once when rates
  /// are available and then stored forever (M5.5b). All three are null
  /// together — an expense added offline simply stays unconverted until
  /// the next connection backfills it, which is why these are nullable
  /// rather than defaulted: null means "not yet", not "zero".
  ///
  /// Storing the converted figure (rather than converting on the fly)
  /// means the rate is the one that applied around the time of the
  /// spend, and the total keeps working with no network at all.
  IntColumn get convertedAmountMinor => integer().nullable()();
  TextColumn get convertedCurrency => text().nullable()();

  /// When the rate used for [convertedAmountMinor] was fetched — shown
  /// in the UI so an approximate figure can be sanity-checked.
  DateTimeColumn get convertedRateAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
