import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// Schema-bump rule (testing conventions): every schema bump ships a
/// migration test in the same commit. v12 adds Places.category.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const insertTrip = 'INSERT INTO trips (id, name, color_tag, archived, '
      'completion_prompt_shown, created_at) '
      "VALUES ('t1', 'Thailand', 0, 0, 0, 0)";

  /// The v11 places table — before the category column existed.
  const createV11Places = '''
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

  /// The v4-shaped trips table — before Trips.completionPromptShown
  /// existed (arrived v6). Needed only for the v4 -> v12 jump below: a
  /// fresh `AppDatabase` creates trips at its CURRENT shape (via
  /// `onCreate`), which already has completionPromptShown, so replaying
  /// `onUpgrade` from a genuine `from: 4` would otherwise make the
  /// migration's own (correct) `trips.completionPromptShown` addColumn
  /// step collide with a column this synthetic setup already has —
  /// exactly the class of test-setup trap the multi-jump test below is
  /// trying to isolate on the places side, not exercise on the trips side.
  const createV4Trips = '''
CREATE TABLE trips (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  start_date INTEGER,
  end_date INTEGER,
  color_tag INTEGER NOT NULL DEFAULT 0,
  archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
)''';

  const insertV4Trip = 'INSERT INTO trips (id, name, color_tag, archived, '
      "created_at) VALUES ('t1', 'Thailand', 0, 0, 0)";

  /// The pre-v13 trips table — before Trips.coverPhotoPath existed.
  /// Needed here for the same reason `createV4Trips` is needed below: a
  /// fresh `AppDatabase` creates trips at its CURRENT shape (via
  /// `onCreate`), coverPhotoPath included, so replaying `onUpgrade` from
  /// `from: 11` would otherwise make the migration's own (correct)
  /// trips.coverPhotoPath addColumn step collide with a column this
  /// synthetic setup already has — unrelated to what this test covers.
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
      'v11 -> v12 adds the category column to an existing table, null '
      '(= uncategorized), keeping existing rows', () async {
    await db.customStatement('DROP TABLE places');
    await db.customStatement(createV11Places);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createPreCoverPhotoTrips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO places (id, name, country, city, status, notes, '
      "created_at) VALUES ('p1', 'Railay', 'Thailand', 'Krabi', 0, '', 0)",
    );

    await db.migration.onUpgrade(Migrator(db), 11, 12);

    final rows =
        await db.customSelect('SELECT name, category FROM places').get();
    expect(rows.single.read<String>('name'), 'Railay');
    expect(rows.single.read<int?>('category'), isNull);
  });

  test(
      'v4 -> v12 in one jump does NOT try to add a column to a table it '
      'just created (regression: crashed with "duplicate column name" for '
      'anyone skipping a version — same class of bug expenses v6->v8 '
      'guards against)', () async {
    await db.customStatement('DROP TABLE places');
    // Reshape trips to its genuine v4 state too — otherwise the fresh,
    // current-shape trips table this db started with (already carrying
    // completionPromptShown) would make the migration's own trips step
    // collide, for a reason that has nothing to do with places.category.
    // FK checks are toggled off for the drop itself: SQLite's DROP TABLE,
    // with foreign_keys ON, tries to validate the (already-dropped)
    // places table that references trips and errors "no such table".
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createV4Trips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(insertV4Trip);

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 4, 12),
      completes,
    );
    // The freshly created table already has the v12 shape.
    await db.customSelect('SELECT category FROM places').get();
    // ...and the trips step correctly backfilled the column it lacked.
    await db.customSelect('SELECT completion_prompt_shown FROM trips').get();
    // ...and the same is true of the v13 coverPhotoPath step: it also
    // runs unconditionally off `from` (not gated by `to`), so it fires
    // here too even though this test only migrates up to 12.
    final coverPhotoRows =
        await db.customSelect('SELECT cover_photo_path FROM trips').get();
    expect(coverPhotoRows.single.read<String?>('cover_photo_path'), isNull);
  });
}
