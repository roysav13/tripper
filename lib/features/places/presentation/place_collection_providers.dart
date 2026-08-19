import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/place_collection_repository.dart';
import '../data/place_collections_dao.dart';
import '../domain/place_collection.dart';

final placeCollectionsDaoProvider = Provider<PlaceCollectionsDao>(
  (ref) => ref.watch(databaseProvider).placeCollectionsDao,
);

final placeCollectionRepositoryProvider = Provider<PlaceCollectionRepository>(
  (ref) => DriftPlaceCollectionRepository(
    ref.watch(placeCollectionsDaoProvider),
    ref.watch(clockProvider),
  ),
);

final placeCollectionsProvider = StreamProvider<List<PlaceCollection>>(
  (ref) => ref.watch(placeCollectionRepositoryProvider).watchAll(),
);

/// placeId -> the set of collection ids that place belongs to.
final placeCollectionMembershipsProvider =
    StreamProvider<Map<String, Set<String>>>(
  (ref) =>
      ref.watch(placeCollectionRepositoryProvider).watchMembershipsByPlace(),
);
