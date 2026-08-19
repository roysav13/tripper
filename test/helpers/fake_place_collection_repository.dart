import 'dart:async';

import 'package:tripper/features/places/data/place_collection_repository.dart';
import 'package:tripper/features/places/domain/place_collection.dart';

/// Fake at the repository boundary (testing rules — no DB in widget tests).
class FakePlaceCollectionRepository implements PlaceCollectionRepository {
  FakePlaceCollectionRepository(
    this._collections, {
    Map<String, Set<String>> memberships = const {},
    DateTime? clock,
  })  : _memberships = {
          for (final entry in memberships.entries) entry.key: {...entry.value},
        },
        _clock = clock ?? DateTime(2026, 7, 19);

  final List<PlaceCollection> _collections;
  final Map<String, Set<String>> _memberships;
  final DateTime _clock;
  final _collectionsController =
      StreamController<List<PlaceCollection>>.broadcast();
  final _membershipsController =
      StreamController<Map<String, Set<String>>>.broadcast();

  void emitCollections(List<PlaceCollection> collections) {
    _collections
      ..clear()
      ..addAll(collections);
    _collectionsController.add(List.of(collections));
  }

  void emitMemberships(Map<String, Set<String>> memberships) {
    _memberships
      ..clear()
      ..addAll({
        for (final entry in memberships.entries) entry.key: {...entry.value},
      });
    _membershipsController.add(_snapshotMemberships());
  }

  Map<String, Set<String>> _snapshotMemberships() => {
        for (final entry in _memberships.entries) entry.key: {...entry.value},
      };

  @override
  Stream<List<PlaceCollection>> watchAll() async* {
    yield List.of(_collections);
    yield* _collectionsController.stream;
  }

  @override
  Stream<Map<String, Set<String>>> watchMembershipsByPlace() async* {
    yield _snapshotMemberships();
    yield* _membershipsController.stream;
  }

  @override
  Future<String> createCollection({required String name}) async {
    final collection = PlaceCollection(
      id: 'fake-collection-${_collections.length}',
      name: name,
      createdAt: _clock,
    );
    emitCollections([..._collections, collection]);
    return collection.id;
  }

  @override
  Future<void> renameCollection(String id, {required String name}) async {
    emitCollections([
      for (final c in _collections)
        if (c.id == id) c.copyWith(name: name) else c,
    ]);
  }

  @override
  Future<void> deleteCollection(String id) async {
    emitCollections([..._collections.where((c) => c.id != id)]);
    emitMemberships({
      for (final entry in _memberships.entries)
        entry.key: entry.value.where((c) => c != id).toSet(),
    });
  }

  @override
  Future<void> setCollectionsForPlace(
    String placeId,
    Set<String> collectionIds,
  ) async {
    emitMemberships({
      ..._memberships,
      placeId: {...collectionIds},
    });
  }
}
