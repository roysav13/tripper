import 'package:drift/drift.dart';

import '../../trips/data/trip_tables.dart';

@DataClassName('PlaceRow')
class Places extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Nullable — a place can exist before it's located on the map (M3b).
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();

  TextColumn get country => text().withDefault(const Constant(''))();
  TextColumn get city => text().withDefault(const Constant(''))();

  /// Index into PlaceStatus enum.
  IntColumn get status => integer()();
  DateTimeColumn get visitedAt => dateTime().nullable()();

  /// Deleting a trip keeps its places (SET NULL — M3 plan decision).
  TextColumn get tripId =>
      text().nullable().references(Trips, #id, onDelete: KeyAction.setNull)();

  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  /// Index into PlaceCategory enum; null = uncategorized (existing rows,
  /// or a place the user hasn't categorized yet).
  IntColumn get category => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
