import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// Schema-bump rule (testing conventions): every schema bump ships a
/// migration test in the same commit. v10 added JournalEntries +
/// JournalPhotos (Journal feature). v11 added JournalEntries.placeId
/// (Place<->JournalEntry correlation). Mirrors expenses_migration_test.dart.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const insertTrip = 'INSERT INTO trips (id, name, color_tag, archived, '
      'completion_prompt_shown, created_at) '
      "VALUES ('t1', 'Thailand', 0, 0, 0, 0)";

  /// The v10 journal_entries shape — before place_id existed.
  const createV10JournalEntries = '''
CREATE TABLE journal_entries (
  id TEXT NOT NULL PRIMARY KEY,
  trip_id TEXT NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
  summary TEXT NOT NULL,
  logged_at INTEGER NOT NULL,
  lat REAL,
  lng REAL,
  place_name TEXT,
  created_at INTEGER NOT NULL
)''';

  /// The pre-v12 places table — before Places.category existed. A fresh
  /// `AppDatabase` creates places at its CURRENT shape (via `onCreate`),
  /// category column included, so any `onUpgrade` replay with `from` in
  /// [5, 12) below would otherwise make the migration's own (correct)
  /// places.category addColumn step collide with a column this synthetic
  /// setup already has — unrelated to what these tests actually cover.
  const createPreCategoryPlaces = '''
CREATE TABLE places (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  lat REAL,
  lng REAL,
  country TEXT NOT NULL DEFAULT '',
  city TEXT NOT NULL DEFAULT '',
  status INTEGER NOT NULL,
  visited_at INTEGER,
  trip_id TEXT REFERENCES trips (id) ON DELETE SET NULL,
  notes TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
)''';

  /// The pre-v13 trips table — before Trips.coverPhotoPath existed. Same
  /// class of issue as `createPreCategoryPlaces` above: a fresh
  /// `AppDatabase` creates trips at its CURRENT shape (via `onCreate`),
  /// coverPhotoPath included, so any `onUpgrade` replay with `from` < 13
  /// below would otherwise make the migration's own (correct)
  /// trips.coverPhotoPath addColumn step collide with a column this
  /// synthetic setup already has.
  const createPreCoverPhotoTrips = '''
CREATE TABLE trips (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  start_date INTEGER,
  end_date INTEGER,
  color_tag INTEGER NOT NULL DEFAULT 0,
  archived INTEGER NOT NULL DEFAULT 0,
  completion_prompt_shown INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
)''';

  test(
      'v9 -> v10 creates journal_entries and journal_photos, preserves '
      'existing trips', () async {
    // A v9 install: neither journal table exists yet (child first — FK).
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement('DROP TABLE places');
    await db.customStatement(createPreCategoryPlaces);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createPreCoverPhotoTrips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(insertTrip);

    await db.migration.onUpgrade(Migrator(db), 9, 10);

    await db.customSelect('SELECT COUNT(*) FROM journal_entries').getSingle();
    await db.customSelect('SELECT COUNT(*) FROM journal_photos').getSingle();
    final trips = await db.customSelect('SELECT name FROM trips').get();
    expect(trips.single.read<String>('name'), 'Thailand');
  });

  test(
      'v10 -> v11 adds place_id to an existing table, null (unlinked), '
      'keeping existing entries', () async {
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement(createV10JournalEntries);
    await db.customStatement('DROP TABLE places');
    await db.customStatement(createPreCategoryPlaces);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createPreCoverPhotoTrips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO journal_entries (id, trip_id, summary, logged_at, '
      'created_at) '
      "VALUES ('j1', 't1', 'Arrived', 0, 0)",
    );

    await db.migration.onUpgrade(Migrator(db), 10, 11);

    final rows = await db
        .customSelect('SELECT summary, place_id FROM journal_entries')
        .get();
    expect(rows.single.read<String>('summary'), 'Arrived');
    expect(rows.single.read<String?>('place_id'), isNull);
  });

  test(
      'v9 -> v11 in one jump does NOT try to add place_id to a table it '
      'just created (regression: crashed with "duplicate column name" for '
      'anyone skipping a version)', () async {
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement('DROP TABLE places');
    await db.customStatement(createPreCategoryPlaces);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createPreCoverPhotoTrips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(insertTrip);

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 9, 11),
      completes,
    );
    // The freshly created table already has the v11 shape.
    await db.customSelect('SELECT place_id FROM journal_entries').get();
  });

  test('v1 -> v11 in one jump survives', () async {
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement('DROP TABLE itinerary_items');
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement('DROP TABLE trip_destinations');
    await db.customStatement('DROP TABLE trips');

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 1, 11),
      completes,
    );
    await db.customSelect('SELECT COUNT(*) FROM journal_entries').getSingle();
    await db.customSelect('SELECT place_id FROM journal_entries').get();
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

  test(
      'deleting a place unlinks (not deletes) its journal entry '
      '(place_id SET NULL)', () async {
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO places (id, name, status, trip_id, created_at) '
      "VALUES ('p1', 'Krabi', 1, 't1', 0)",
    );
    await db.customStatement(
      'INSERT INTO journal_entries (id, trip_id, summary, logged_at, '
      'place_id, created_at) '
      "VALUES ('j1', 't1', 'Arrived', 0, 'p1', 0)",
    );

    await db.customStatement("DELETE FROM places WHERE id = 'p1'");

    final row = await db
        .customSelect(
          "SELECT place_id FROM journal_entries WHERE id = 'j1'",
        )
        .getSingle();
    expect(row.data['place_id'], isNull);
    final remaining = await db
        .customSelect('SELECT COUNT(*) AS c FROM journal_entries')
        .getSingle();
    expect(remaining.read<int>('c'), 1);
  });
}
