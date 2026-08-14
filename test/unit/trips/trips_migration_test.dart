import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// Schema-bump rule (CLAUDE.md rule 5): every schema bump ships a
/// migration test. v13 adds Trips.coverPhotoPath.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The v12 trips table — before coverPhotoPath existed.
  const createV12Trips = '''
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
      'v12 -> v13 adds coverPhotoPath to an existing trips table, null '
      '(= no photo, render the generated gradient), keeping existing rows',
      () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createV12Trips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(
      'INSERT INTO trips (id, name, color_tag, archived, '
      "completion_prompt_shown, created_at) "
      "VALUES ('t1', 'Thailand', 0, 0, 0, 0)",
    );

    await db.migration.onUpgrade(Migrator(db), 12, 13);

    final rows = await db
        .customSelect('SELECT name, cover_photo_path FROM trips')
        .get();
    expect(rows.single.read<String>('name'), 'Thailand');
    expect(rows.single.read<String?>('cover_photo_path'), isNull);
  });

  test(
      'v1 -> v13 (trips did not exist yet) creates the table at its '
      'current shape and does not also try to add coverPhotoPath a second '
      'time (same duplicate-column regression class the places v4->v12 '
      'migration test guards against)', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement('PRAGMA foreign_keys = ON');

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 1, 13),
      completes,
    );
    await db.customSelect('SELECT cover_photo_path FROM trips').get();
  });
}
