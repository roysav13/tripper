import 'package:drift/drift.dart';

import '../../trips/data/trip_tables.dart';

@DataClassName('JournalEntryRow')
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get summary => text().withLength(min: 1, max: 4000)();

  /// User-editable log time — never `DateTime.now()`, defaults to
  /// `clockProvider` at creation (domain rule).
  DateTimeColumn get loggedAt => dateTime()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  TextColumn get placeName => text().nullable()();

  /// Immutable audit stamp — never shown or edited.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('JournalPhotoRow')
class JournalPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get entryId =>
      text().references(JournalEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
