// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'packing_dao.dart';

// ignore_for_file: type=lint
mixin _$PackingDaoMixin on DatabaseAccessor<AppDatabase> {
  $PackingTemplatesTable get packingTemplates =>
      attachedDatabase.packingTemplates;
  $PackingTemplateItemsTable get packingTemplateItems =>
      attachedDatabase.packingTemplateItems;
  $TripsTable get trips => attachedDatabase.trips;
  $TripPackingItemsTable get tripPackingItems =>
      attachedDatabase.tripPackingItems;
  PackingDaoManager get managers => PackingDaoManager(this);
}

class PackingDaoManager {
  final _$PackingDaoMixin _db;
  PackingDaoManager(this._db);
  $$PackingTemplatesTableTableManager get packingTemplates =>
      $$PackingTemplatesTableTableManager(
          _db.attachedDatabase, _db.packingTemplates);
  $$PackingTemplateItemsTableTableManager get packingTemplateItems =>
      $$PackingTemplateItemsTableTableManager(
          _db.attachedDatabase, _db.packingTemplateItems);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$TripPackingItemsTableTableManager get tripPackingItems =>
      $$TripPackingItemsTableTableManager(
          _db.attachedDatabase, _db.tripPackingItems);
}
