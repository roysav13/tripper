import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// Schema-bump rule (testing conventions): every schema bump ships a
/// migration test in the same commit. v16 adds PlaceCollections +
/// PlaceCollectionMemberships (Locations lists feature).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const insertPlace = 'INSERT INTO places (id, name, status, notes, '
      "created_at) VALUES ('p1', 'Railay', 0, '', 0)";

  test(
      'v15 -> v16 creates place_collections and '
      'place_collection_memberships', () async {
    await db.customStatement('DROP TABLE place_collection_memberships');
    await db.customStatement('DROP TABLE place_collections');

    await db.migration.onUpgrade(Migrator(db), 15, 16);

    await db.customSelect('SELECT COUNT(*) FROM place_collections').getSingle();
    await db
        .customSelect('SELECT COUNT(*) FROM place_collection_memberships')
        .getSingle();
  });

  test(
      'v1 -> v16 in one jump does NOT try to create tables it just '
      'created (createTable is idempotent via IF NOT EXISTS, but this '
      'guards the new step runs at all on a from-scratch upgrade)', () async {
    await db.customStatement('DROP TABLE place_collection_memberships');
    await db.customStatement('DROP TABLE place_collections');
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement('DROP TABLE itinerary_items');
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement('DROP TABLE trip_destinations');
    await db.customStatement('DROP TABLE trips');

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 1, 16),
      completes,
    );
    await db.customSelect('SELECT COUNT(*) FROM place_collections').getSingle();
    await db
        .customSelect('SELECT COUNT(*) FROM place_collection_memberships')
        .getSingle();
  });

  test(
      'deleting a place removes its collection memberships, but not the '
      'collection itself (KeyAction.cascade on placeId)', () async {
    await db.customStatement(insertPlace);
    await db.customStatement(
      'INSERT INTO place_collections (id, name, created_at) '
      "VALUES ('c1', 'Food', 0)",
    );
    await db.customStatement(
      'INSERT INTO place_collection_memberships (collection_id, place_id) '
      "VALUES ('c1', 'p1')",
    );

    await db.customStatement("DELETE FROM places WHERE id = 'p1'");

    final memberships = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM place_collection_memberships',
        )
        .getSingle();
    expect(memberships.read<int>('c'), 0);
    final collections = await db
        .customSelect('SELECT COUNT(*) AS c FROM place_collections')
        .getSingle();
    expect(collections.read<int>('c'), 1);
  });

  test(
      'deleting a collection removes its memberships, but not the place '
      '(KeyAction.cascade on collectionId)', () async {
    await db.customStatement(insertPlace);
    await db.customStatement(
      'INSERT INTO place_collections (id, name, created_at) '
      "VALUES ('c1', 'Food', 0)",
    );
    await db.customStatement(
      'INSERT INTO place_collection_memberships (collection_id, place_id) '
      "VALUES ('c1', 'p1')",
    );

    await db.customStatement("DELETE FROM place_collections WHERE id = 'c1'");

    final memberships = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM place_collection_memberships',
        )
        .getSingle();
    expect(memberships.read<int>('c'), 0);
    final places =
        await db.customSelect('SELECT COUNT(*) AS c FROM places').getSingle();
    expect(places.read<int>('c'), 1);
  });

  test('a place can belong to more than one collection at once', () async {
    await db.customStatement(insertPlace);
    await db.customStatement(
      'INSERT INTO place_collections (id, name, created_at) VALUES '
      "('c1', 'Food', 0), ('c2', 'Tokyo day trips', 0)",
    );
    await db.customStatement(
      'INSERT INTO place_collection_memberships (collection_id, place_id) '
      "VALUES ('c1', 'p1'), ('c2', 'p1')",
    );

    final rows = await db
        .customSelect(
          'SELECT collection_id FROM place_collection_memberships '
          "WHERE place_id = 'p1'",
        )
        .get();
    expect(
      rows.map((r) => r.read<String>('collection_id')).toSet(),
      {'c1', 'c2'},
    );
  });
}
