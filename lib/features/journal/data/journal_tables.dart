import 'package:drift/drift.dart';

import '../../places/data/place_tables.dart';
import '../../trips/data/trip_tables.dart';

@DataClassName('JournalEntryRow')
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// min: 0, not 1 — entries auto-created by markPlaceVisited (a place
  /// marked visited outside the journal) start with an empty summary,
  /// shown as "Not written yet" until the user fills it in. The manual
  /// entry form enforces non-empty at the UI layer for user-typed entries.
  TextColumn get summary => text().withLength(min: 0, max: 4000)();

  /// User-editable log time — never `DateTime.now()`, defaults to
  /// `clockProvider` at creation (domain rule).
  DateTimeColumn get loggedAt => dateTime()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  TextColumn get placeName => text().nullable()();

  /// Links this entry to the Place it corresponds to, if any — set when
  /// the entry's location was picked from (or created as) one of the
  /// trip's Places, or when the entry was auto-created because a Place
  /// was marked visited from the Places tab. SET NULL, not cascade:
  /// deleting the place must never delete the entry (entries are user
  /// content — text, photos — only ever removed by explicit user action).
  TextColumn get placeId =>
      text().nullable().references(Places, #id, onDelete: KeyAction.setNull)();

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
