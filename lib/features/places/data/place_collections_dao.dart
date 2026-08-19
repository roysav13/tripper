import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'place_collection_tables.dart';

part 'place_collections_dao.g.dart';

@DriftAccessor(tables: [PlaceCollections, PlaceCollectionMemberships])
class PlaceCollectionsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaceCollectionsDaoMixin {
  PlaceCollectionsDao(super.db);

  Stream<List<PlaceCollectionRow>> watchAll() =>
      (select(placeCollections)..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  /// Every membership row, unfiltered — grouped into a placeId -> collection
  /// ids map by the repository. Reading the whole join once here (rather
  /// than a per-place or per-collection query) keeps the filter facet and
  /// the collections row both driven by one live stream.
  Stream<List<PlaceCollectionMembershipRow>> watchAllMemberships() =>
      select(placeCollectionMemberships).watch();

  Future<void> insertCollection(PlaceCollectionRow row) =>
      into(placeCollections).insert(row);

  Future<void> renameCollection(String id, String name) {
    return (update(placeCollections)..where((c) => c.id.equals(id)))
        .write(PlaceCollectionsCompanion(name: Value(name)));
  }

  /// Memberships cascade via FK.
  Future<void> deleteCollection(String id) =>
      (delete(placeCollections)..where((c) => c.id.equals(id))).go();

  /// Replace-all semantics — mirrors how the edit-place form saves once on
  /// submit rather than per-toggle.
  Future<void> setMembershipsForPlace(
    String placeId,
    List<String> collectionIds,
  ) {
    return transaction(() async {
      await (delete(placeCollectionMemberships)
            ..where((m) => m.placeId.equals(placeId)))
          .go();
      for (final collectionId in collectionIds) {
        await into(placeCollectionMemberships).insert(
          PlaceCollectionMembershipsCompanion.insert(
            collectionId: collectionId,
            placeId: placeId,
          ),
        );
      }
    });
  }
}
