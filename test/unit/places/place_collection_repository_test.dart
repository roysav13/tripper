import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';
import 'package:tripper/features/places/data/place_collection_repository.dart';
import 'package:tripper/features/places/data/place_repository.dart';

void main() {
  late AppDatabase db;
  late DriftPlaceCollectionRepository repo;
  late DriftPlaceRepository placeRepo;
  final today = DateTime(2026, 7, 19);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPlaceCollectionRepository(db.placeCollectionsDao, () => today);
    placeRepo = DriftPlaceRepository(db.placesDao, () => today);
  });

  tearDown(() async => db.close());

  test('createCollection stamps the clock and is immediately visible',
      () async {
    final id = await repo.createCollection(name: 'Food');
    final collections = await repo.watchAll().first;
    expect(collections.single.id, id);
    expect(collections.single.name, 'Food');
    expect(collections.single.createdAt, today);
  });

  test('renameCollection updates the name, keeps the id and createdAt',
      () async {
    final id = await repo.createCollection(name: 'Food');
    await repo.renameCollection(id, name: 'Tokyo food');
    final collection = (await repo.watchAll().first).single;
    expect(collection.id, id);
    expect(collection.name, 'Tokyo food');
  });

  test('deleteCollection removes it, and its memberships, but not the place',
      () async {
    final placeId = await placeRepo.createPlace(name: 'Railay');
    final collectionId = await repo.createCollection(name: 'Food');
    await repo.setCollectionsForPlace(placeId, {collectionId});

    await repo.deleteCollection(collectionId);

    expect(await repo.watchAll().first, isEmpty);
    final memberships = await repo.watchMembershipsByPlace().first;
    expect(memberships[placeId] ?? const {}, isEmpty);
    expect(await placeRepo.watchAll().first, hasLength(1));
  });

  test('a place can belong to more than one collection', () async {
    final placeId = await placeRepo.createPlace(name: 'Railay');
    final food = await repo.createCollection(name: 'Food');
    final tokyo = await repo.createCollection(name: 'Tokyo day trips');

    await repo.setCollectionsForPlace(placeId, {food, tokyo});

    final memberships = await repo.watchMembershipsByPlace().first;
    expect(memberships[placeId], {food, tokyo});
  });

  test('setCollectionsForPlace replaces the full membership set', () async {
    final placeId = await placeRepo.createPlace(name: 'Railay');
    final food = await repo.createCollection(name: 'Food');
    final tokyo = await repo.createCollection(name: 'Tokyo day trips');
    await repo.setCollectionsForPlace(placeId, {food, tokyo});

    await repo.setCollectionsForPlace(placeId, {tokyo});

    final memberships = await repo.watchMembershipsByPlace().first;
    expect(memberships[placeId], {tokyo});
  });

  test('setCollectionsForPlace with an empty set clears all memberships',
      () async {
    final placeId = await placeRepo.createPlace(name: 'Railay');
    final food = await repo.createCollection(name: 'Food');
    await repo.setCollectionsForPlace(placeId, {food});

    await repo.setCollectionsForPlace(placeId, {});

    final memberships = await repo.watchMembershipsByPlace().first;
    expect(memberships[placeId] ?? const {}, isEmpty);
  });

  test(
      'deleting a place drops it from the membership map without deleting '
      'the collection', () async {
    final placeId = await placeRepo.createPlace(name: 'Railay');
    final food = await repo.createCollection(name: 'Food');
    await repo.setCollectionsForPlace(placeId, {food});

    await placeRepo.deletePlace(placeId);

    final memberships = await repo.watchMembershipsByPlace().first;
    expect(memberships.containsKey(placeId), isFalse);
    expect(await repo.watchAll().first, hasLength(1));
  });
}
