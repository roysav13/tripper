// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_dao.dart';

// ignore_for_file: type=lint
mixin _$JournalDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $PlacesTable get places => attachedDatabase.places;
  $JournalEntriesTable get journalEntries => attachedDatabase.journalEntries;
  $JournalPhotosTable get journalPhotos => attachedDatabase.journalPhotos;
  JournalDaoManager get managers => JournalDaoManager(this);
}

class JournalDaoManager {
  final _$JournalDaoMixin _db;
  JournalDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db.attachedDatabase, _db.places);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(
          _db.attachedDatabase, _db.journalEntries);
  $$JournalPhotosTableTableManager get journalPhotos =>
      $$JournalPhotosTableTableManager(_db.attachedDatabase, _db.journalPhotos);
}
