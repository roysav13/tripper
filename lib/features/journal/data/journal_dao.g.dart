// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_dao.dart';

// ignore_for_file: type=lint
mixin _$JournalDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $JournalEntriesTable get journalEntries => attachedDatabase.journalEntries;
  $JournalPhotosTable get journalPhotos => attachedDatabase.journalPhotos;
  JournalDaoManager get managers => JournalDaoManager(this);
}

class JournalDaoManager {
  final _$JournalDaoMixin _db;
  JournalDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(
          _db.attachedDatabase, _db.journalEntries);
  $$JournalPhotosTableTableManager get journalPhotos =>
      $$JournalPhotosTableTableManager(_db.attachedDatabase, _db.journalPhotos);
}
