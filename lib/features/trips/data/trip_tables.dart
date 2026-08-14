import 'package:drift/drift.dart';

@DataClassName('TripRow')
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get colorTag => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// "Trip over — mark places visited?" is offered exactly once (M3).
  BoolColumn get completionPromptShown =>
      boolean().withDefault(const Constant(false))();

  /// Path to a locally-stored cover photo (redesign spec §6). Null means
  /// no photo — render the generated gradient fallback instead.
  TextColumn get coverPhotoPath => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TripDestinationRow')
class TripDestinations extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
