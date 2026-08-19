import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/place_collection.dart';
import 'place_collections_dao.dart';

/// Widget tests mock at this boundary.
abstract interface class PlaceCollectionRepository {
  Stream<List<PlaceCollection>> watchAll();

  /// placeId -> the set of collection ids that place belongs to. Every
  /// place is present with an empty set if it belongs to none.
  Stream<Map<String, Set<String>>> watchMembershipsByPlace();

  Future<String> createCollection({required String name});
  Future<void> renameCollection(String id, {required String name});

  /// Removing a collection never deletes the places in it — only the
  /// membership rows (FK cascade).
  Future<void> deleteCollection(String id);

  /// Replace-all semantics: [collectionIds] becomes the complete set of
  /// collections this place belongs to.
  Future<void> setCollectionsForPlace(
    String placeId,
    Set<String> collectionIds,
  );
}

class DriftPlaceCollectionRepository implements PlaceCollectionRepository {
  DriftPlaceCollectionRepository(this._dao, this._clock);

  final PlaceCollectionsDao _dao;
  final DateTime Function() _clock;
  final _uuid = const Uuid();

  @override
  Stream<List<PlaceCollection>> watchAll() => _dao.watchAll().map(
        (rows) => [
          for (final row in rows)
            PlaceCollection(
              id: row.id,
              name: row.name,
              createdAt: row.createdAt,
            ),
        ],
      );

  @override
  Stream<Map<String, Set<String>>> watchMembershipsByPlace() {
    return _dao.watchAllMemberships().map((rows) {
      final byPlace = <String, Set<String>>{};
      for (final row in rows) {
        (byPlace[row.placeId] ??= {}).add(row.collectionId);
      }
      return byPlace;
    });
  }

  @override
  Future<String> createCollection({required String name}) async {
    final id = _uuid.v4();
    await _dao.insertCollection(
      PlaceCollectionRow(id: id, name: name.trim(), createdAt: _clock()),
    );
    return id;
  }

  @override
  Future<void> renameCollection(String id, {required String name}) =>
      _dao.renameCollection(id, name.trim());

  @override
  Future<void> deleteCollection(String id) => _dao.deleteCollection(id);

  @override
  Future<void> setCollectionsForPlace(
    String placeId,
    Set<String> collectionIds,
  ) =>
      _dao.setMembershipsForPlace(placeId, collectionIds.toList());
}
