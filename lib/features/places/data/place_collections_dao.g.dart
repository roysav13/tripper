// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_collections_dao.dart';

// ignore_for_file: type=lint
mixin _$PlaceCollectionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlaceCollectionsTable get placeCollections =>
      attachedDatabase.placeCollections;
  $TripsTable get trips => attachedDatabase.trips;
  $PlacesTable get places => attachedDatabase.places;
  $PlaceCollectionMembershipsTable get placeCollectionMemberships =>
      attachedDatabase.placeCollectionMemberships;
  PlaceCollectionsDaoManager get managers => PlaceCollectionsDaoManager(this);
}

class PlaceCollectionsDaoManager {
  final _$PlaceCollectionsDaoMixin _db;
  PlaceCollectionsDaoManager(this._db);
  $$PlaceCollectionsTableTableManager get placeCollections =>
      $$PlaceCollectionsTableTableManager(
          _db.attachedDatabase, _db.placeCollections);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db.attachedDatabase, _db.places);
  $$PlaceCollectionMembershipsTableTableManager
      get placeCollectionMemberships =>
          $$PlaceCollectionMembershipsTableTableManager(
              _db.attachedDatabase, _db.placeCollectionMemberships);
}
