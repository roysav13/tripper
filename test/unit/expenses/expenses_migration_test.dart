import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// Schema-bump rule (testing conventions): every schema bump ships a
/// migration test in the same commit. v7 added Expenses (M5.5), v8 its
/// conversion columns (M5.5b).
///
/// Drift's `drift_dev schema` snapshot tooling isn't set up in this repo,
/// so these drive the real `MigrationStrategy.onUpgrade` against a
/// hand-built old-shaped database. That's more faithful than it sounds:
/// the bug these tests caught (see the multi-version case below) only
/// appears when `createTable` and `addColumn` both run for one table.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const insertTrip = 'INSERT INTO trips (id, name, color_tag, archived, '
      'completion_prompt_shown, created_at) '
      "VALUES ('t1', 'Thailand', 0, 0, 0, 0)";

  /// The v7 expenses table — before the conversion columns existed.
  const createV7Expenses = '''
CREATE TABLE expenses (
  id TEXT NOT NULL PRIMARY KEY,
  trip_id TEXT NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
  amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  category INTEGER NOT NULL,
  date INTEGER NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
)''';

  test('v6 -> v7 creates the expenses table and preserves existing data',
      () async {
    // A v6 install: no expenses table at all.
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement(insertTrip);

    await db.migration.onUpgrade(Migrator(db), 6, 7);

    await db.customSelect('SELECT COUNT(*) FROM expenses').getSingle();
    final trips = await db.customSelect('SELECT name FROM trips').get();
    expect(trips.single.read<String>('name'), 'Thailand');
  });

  test(
      'v7 -> v8 adds the conversion columns to an existing table, null '
      '(= not yet converted), keeping the rows', () async {
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement(createV7Expenses);
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO expenses (id, trip_id, amount_minor, currency, category, '
      'date, notes, created_at) '
      "VALUES ('e1', 't1', 1230, 'ILS', 2, 0, '', 0)",
    );

    await db.migration.onUpgrade(Migrator(db), 7, 8);

    final rows = await db
        .customSelect(
          'SELECT amount_minor, converted_amount_minor, converted_currency, '
          'converted_rate_at FROM expenses',
        )
        .get();
    expect(rows.single.read<int>('amount_minor'), 1230);
    expect(rows.single.read<int?>('converted_amount_minor'), isNull);
    expect(rows.single.read<String?>('converted_currency'), isNull);
    expect(rows.single.read<DateTime?>('converted_rate_at'), isNull);
  });

  test(
      'v6 -> v8 in one jump does NOT try to add columns to a table it '
      'just created (regression: crashed with "duplicate column name" '
      'for anyone skipping a version)', () async {
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement(insertTrip);

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 6, 8),
      completes,
    );
    // The freshly created table already has the v8 shape.
    await db.customSelect('SELECT converted_amount_minor FROM expenses').get();
  });

  test(
      'v1 -> v8 in one jump also survives — same createTable/addColumn '
      'overlap existed on trips.completion_prompt_shown', () async {
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement('DROP TABLE trip_destinations');
    await db.customStatement('DROP TABLE trips');

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 1, 8),
      completes,
    );
    await db.customSelect('SELECT completion_prompt_shown FROM trips').get();
  });

  test('the expenses FK cascades on trip delete at the SQL level', () async {
    // `beforeOpen` enables this in the app; assert rather than assume,
    // since the cascade result would otherwise be ambiguous.
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);

    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO expenses (id, trip_id, amount_minor, currency, category, '
      'date, notes, created_at) '
      "VALUES ('e1', 't1', 500, 'ILS', 0, 0, '', 0)",
    );

    await db.customStatement("DELETE FROM trips WHERE id = 't1'");

    final remaining =
        await db.customSelect('SELECT COUNT(*) AS c FROM expenses').getSingle();
    expect(remaining.read<int>('c'), 0);
  });
}
