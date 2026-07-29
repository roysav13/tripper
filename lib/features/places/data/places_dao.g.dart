// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'places_dao.dart';

// ignore_for_file: type=lint
mixin _$PlacesDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $PlacesTable get places => attachedDatabase.places;
  PlacesDaoManager get managers => PlacesDaoManager(this);
}

class PlacesDaoManager {
  final _$PlacesDaoMixin _db;
  PlacesDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db.attachedDatabase, _db.places);
}
