import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// v9 adds ItineraryItems (M5.7). The Plan feature that used this table
/// was withdrawn on 2026-07-26, but the table stays so no device has to
/// run a destructive migration — which makes these tests the only thing
/// standing between a dormant table and a silent schema regression.
///
/// Same approach as the expenses migration test: drive the real
/// `onUpgrade` against a hand-shaped database, including the
/// multi-version jump that caught a real bug at v8 (`createTable` builds
/// the CURRENT definition, so it must never be paired with a later
/// `addColumn` on the same table).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const insertTrip = 'INSERT INTO trips (id, name, color_tag, archived, '
      'completion_prompt_shown, created_at) '
      "VALUES ('t1', 'Thailand', 0, 0, 0, 0)";

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

  test('v8 -> v9 creates the itinerary table and keeps existing data',
      () async {
    await db.customStatement('DROP TABLE itinerary_items');
    await db.customStatement('DROP TABLE places');
    await db.customStatement(createPreCategoryPlaces);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createPreCoverPhotoTrips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(insertTrip);

    await db.migration.onUpgrade(Migrator(db), 8, 9);

    await db.customSelect('SELECT COUNT(*) FROM itinerary_items').getSingle();
    final trips = await db.customSelect('SELECT name FROM trips').get();
    expect(trips.single.read<String>('name'), 'Thailand');
  });

  test(
      'v6 -> v9 in one jump survives (expenses created once, itinerary '
      'created, no duplicate columns)', () async {
    await db.customStatement('DROP TABLE itinerary_items');
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement('DROP TABLE places');
    await db.customStatement(createPreCategoryPlaces);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createPreCoverPhotoTrips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(insertTrip);

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 6, 9),
      completes,
    );
    await db.customSelect('SELECT converted_amount_minor FROM expenses').get();
    await db.customSelect('SELECT COUNT(*) FROM itinerary_items').getSingle();
  });

  test(
      'a v9 row round-trips through raw SQL, so the dormant table is '
      'still usable if the feature returns', () async {
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO itinerary_items (id, trip_id, date, start_minutes, title, '
      'place_id, notes, order_index, created_at) '
      "VALUES ('i1', 't1', 0, 545, 'Ferry', NULL, '', 0, 0)",
    );

    final rows = await db
        .customSelect('SELECT title, start_minutes, order_index '
            'FROM itinerary_items')
        .get();
    expect(rows.single.read<String>('title'), 'Ferry');
    expect(rows.single.read<int>('start_minutes'), 545);
  });

  test('the itinerary FK cascades on trip delete', () async {
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO itinerary_items (id, trip_id, date, start_minutes, title, '
      'place_id, notes, order_index, created_at) '
      "VALUES ('i1', 't1', 0, NULL, 'Ferry', NULL, '', 0, 0)",
    );

    await db.customStatement("DELETE FROM trips WHERE id = 't1'");

    final remaining = await db
        .customSelect('SELECT COUNT(*) AS c FROM itinerary_items')
        .getSingle();
    expect(remaining.read<int>('c'), 0);
  });
}
