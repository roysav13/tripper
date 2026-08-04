import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// Schema-bump rule (testing conventions): every schema bump ships a
/// migration test in the same commit. v10 added JournalEntries +
/// JournalPhotos (Journal feature). Mirrors expenses_migration_test.dart.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const insertTrip = 'INSERT INTO trips (id, name, color_tag, archived, '
      'completion_prompt_shown, created_at) '
      "VALUES ('t1', 'Thailand', 0, 0, 0, 0)";

  test(
      'v9 -> v10 creates journal_entries and journal_photos, preserves '
      'existing trips', () async {
    // A v9 install: neither journal table exists yet (child first — FK).
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement(insertTrip);

    await db.migration.onUpgrade(Migrator(db), 9, 10);

    await db.customSelect('SELECT COUNT(*) FROM journal_entries').getSingle();
    await db.customSelect('SELECT COUNT(*) FROM journal_photos').getSingle();
    final trips = await db.customSelect('SELECT name FROM trips').get();
    expect(trips.single.read<String>('name'), 'Thailand');
  });

  test('v1 -> v10 in one jump survives', () async {
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement('DROP TABLE itinerary_items');
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement('DROP TABLE trip_destinations');
    await db.customStatement('DROP TABLE trips');

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 1, 10),
      completes,
    );
    await db.customSelect('SELECT COUNT(*) FROM journal_entries').getSingle();
    await db.customSelect('SELECT completion_prompt_shown FROM trips').get();
  });

  test('journal_entries cascades when its trip is deleted', () async {
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);

    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO journal_entries (id, trip_id, summary, logged_at, '
      'created_at) '
      "VALUES ('j1', 't1', 'Arrived', 0, 0)",
    );

    await db.customStatement("DELETE FROM trips WHERE id = 't1'");

    final remaining = await db
        .customSelect('SELECT COUNT(*) AS c FROM journal_entries')
        .getSingle();
    expect(remaining.read<int>('c'), 0);
  });

  test('journal_photos cascades when its entry is deleted', () async {
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO journal_entries (id, trip_id, summary, logged_at, '
      'created_at) '
      "VALUES ('j1', 't1', 'Arrived', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO journal_photos (id, entry_id, file_path, order_index) '
      "VALUES ('p1', 'j1', '/tmp/a.jpg', 0)",
    );

    await db.customStatement("DELETE FROM journal_entries WHERE id = 'j1'");

    final remaining = await db
        .customSelect('SELECT COUNT(*) AS c FROM journal_photos')
        .getSingle();
    expect(remaining.read<int>('c'), 0);
  });
}
