import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// Schema-bump rule: every schema bump ships a migration test. v17 adds
/// PackingTemplates + PackingTemplateItems + TripPackingItems.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Matches the working insertTrip in expenses_migration_test.dart —
  // trips has no `destinations` column (that's the separate
  // TripDestinations table) and `created_at` is NOT NULL with no
  // default, so it must be supplied.
  const insertTrip = 'INSERT INTO trips (id, name, color_tag, archived, '
      'completion_prompt_shown, created_at) '
      "VALUES ('t1', 'Thailand', 0, 0, 0, 0)";

  test(
      'v16 -> v17 creates packing_templates, packing_template_items and '
      'trip_packing_items', () async {
    await db.customStatement('DROP TABLE trip_packing_items');
    await db.customStatement('DROP TABLE packing_template_items');
    await db.customStatement('DROP TABLE packing_templates');

    await db.migration.onUpgrade(Migrator(db), 16, 17);

    await db.customSelect('SELECT COUNT(*) FROM packing_templates').getSingle();
    await db
        .customSelect('SELECT COUNT(*) FROM packing_template_items')
        .getSingle();
    await db
        .customSelect('SELECT COUNT(*) FROM trip_packing_items')
        .getSingle();
  });

  test(
      'v1 -> v17 in one jump does not skip the new step on a from-scratch '
      'upgrade', () async {
    await db.customStatement('DROP TABLE trip_packing_items');
    await db.customStatement('DROP TABLE packing_template_items');
    await db.customStatement('DROP TABLE packing_templates');
    await db.customStatement('DROP TABLE place_collection_memberships');
    await db.customStatement('DROP TABLE place_collections');
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement('DROP TABLE itinerary_items');
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement('DROP TABLE trip_destinations');
    await db.customStatement('DROP TABLE trips');

    await expectLater(db.migration.onUpgrade(Migrator(db), 1, 17), completes);
    await db
        .customSelect('SELECT COUNT(*) FROM trip_packing_items')
        .getSingle();
  });

  test('deleting a trip cascades to its trip_packing_items', () async {
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO trip_packing_items (id, trip_id, category, label, '
      "status, sort_order) VALUES ('i1', 't1', 0, 'Black shirt', 0, 0)",
    );

    await db.customStatement("DELETE FROM trips WHERE id = 't1'");

    final rows = await db
        .customSelect('SELECT COUNT(*) AS c FROM trip_packing_items')
        .getSingle();
    expect(rows.read<int>('c'), 0);
  });

  test(
      'deleting a template cascades to its own items but never touches '
      'trip_packing_items (no link is kept after a copy)', () async {
    await db.customStatement(insertTrip);
    await db.customStatement(
      "INSERT INTO packing_templates (id, name) VALUES ('tpl1', 'Beach')",
    );
    await db.customStatement(
      'INSERT INTO packing_template_items (id, template_id, category, '
      "label, sort_order) VALUES ('ti1', 'tpl1', 0, 'Swimsuit', 0)",
    );
    await db.customStatement(
      'INSERT INTO trip_packing_items (id, trip_id, category, label, '
      "status, sort_order) VALUES ('i1', 't1', 0, 'Swimsuit', 0, 0)",
    );

    await db.customStatement("DELETE FROM packing_templates WHERE id = 'tpl1'");

    final templateItems = await db
        .customSelect('SELECT COUNT(*) AS c FROM packing_template_items')
        .getSingle();
    expect(templateItems.read<int>('c'), 0);
    final tripItems = await db
        .customSelect('SELECT COUNT(*) AS c FROM trip_packing_items')
        .getSingle();
    expect(tripItems.read<int>('c'), 1);
  });
}
