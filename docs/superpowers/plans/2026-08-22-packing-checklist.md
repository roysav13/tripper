# Packing Checklist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a packing checklist feature to Tripper — reusable templates plus a per-trip packing list, with clothing items tracked through a 5-state lifecycle (To pack / Packed / Worn / In wash / Clean) instead of a plain checkbox.

**Architecture:** New `lib/features/packing/{data,domain,presentation}` module, following the existing `expenses`/`journal` feature shape exactly (Drift tables → DAO → repository interface + Drift impl → Riverpod providers → a trip-detail tab). Templates and trip lists are two independent table sets; applying a template copies its items into the trip's list (no live link).

**Tech Stack:** Flutter, Riverpod, Drift/SQLite (existing stack — no new dependencies).

**Spec:** `docs/superpowers/specs/2026-08-22-packing-checklist-design.md`

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`; one accent (coral) only; amber reserved for expiry/danger warnings. Use existing `AppColors`/`PillChip`/`PaperCard`/`SectionLabel` — no new tokens or chrome needed for this feature.
- No `DateTime.now()` in domain code — this feature has no timestamp fields, so this doesn't come up, but don't introduce one.
- Every user-facing string goes through ARB (`lib/l10n/app_en.arb`), English only, RTL-safe layout (`EdgeInsetsDirectional`, start/end — never `left`/`right` or plain `EdgeInsets` for horizontal spacing).
- Every Drift schema bump ships a migration test in the same commit. Widget tests mock at the repository boundary (a `Fake*Repository`, never a real `AppDatabase`).
- This feature is fully local/offline — no network path exists anywhere in it, so the "network never gates access" rule is automatically satisfied; no offline-fallback testing is needed.
- Follow existing feature-first structure: `lib/features/packing/{data,domain,presentation}`, tests mirrored under `test/{unit,widget}/packing/`.

---

## Task 1: Domain models

**Files:**
- Create: `lib/features/packing/domain/packing_category.dart`
- Create: `lib/features/packing/domain/packing_item_status.dart`
- Create: `lib/features/packing/domain/packing_template.dart`
- Create: `lib/features/packing/domain/trip_packing_item.dart`
- Test: `test/unit/packing/packing_domain_test.dart`

**Interfaces:**
- Produces: `enum PackingCategory { clothing, documents, electronics, toiletries, other }`; `enum PackingItemStatus { toPack, packed, worn, inWash, clean }`; `class PackingTemplate { id, name }`; `class PackingTemplateItem { id, templateId, category, label, sortOrder }`; `class TripPackingItem { id, tripId, category, label, status, sortOrder }` — all `@immutable` with `copyWith`, `==`, `hashCode`, following `lib/features/expenses/domain/expense.dart`'s shape exactly.

- [ ] **Step 1: Write the failing domain test**

```dart
// test/unit/packing/packing_domain_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/domain/packing_item_status.dart';
import 'package:tripper/features/packing/domain/trip_packing_item.dart';

void main() {
  const item = TripPackingItem(
    id: 'i1',
    tripId: 't1',
    category: PackingCategory.clothing,
    label: 'Black shirt',
    status: PackingItemStatus.toPack,
    sortOrder: 0,
  );

  test('two items with identical fields are equal', () {
    const other = TripPackingItem(
      id: 'i1',
      tripId: 't1',
      category: PackingCategory.clothing,
      label: 'Black shirt',
      status: PackingItemStatus.toPack,
      sortOrder: 0,
    );
    expect(item, other);
    expect(item.hashCode, other.hashCode);
  });

  test('copyWith changes only the given fields', () {
    final updated = item.copyWith(status: PackingItemStatus.worn);
    expect(updated.status, PackingItemStatus.worn);
    expect(updated.label, item.label);
    expect(updated.id, item.id);
  });

  test('copyWith with no arguments returns an equal item', () {
    expect(item.copyWith(), item);
  });

  test('status can jump non-adjacent states via copyWith, e.g. worn to clean',
      () {
    final clean = item
        .copyWith(status: PackingItemStatus.worn)
        .copyWith(status: PackingItemStatus.clean);
    expect(clean.status, PackingItemStatus.clean);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/packing/packing_domain_test.dart`
Expected: FAIL — `package:tripper/features/packing/...` files don't exist yet.

- [ ] **Step 3: Implement the domain files**

```dart
// lib/features/packing/domain/packing_category.dart

/// Order is stable — stored as an index in the DB. Append only.
enum PackingCategory { clothing, documents, electronics, toiletries, other }
```

```dart
// lib/features/packing/domain/packing_item_status.dart

/// Order is stable — stored as an index in the DB. Append only.
///
/// Only [TripPackingItem]s in [PackingCategory.clothing] ever use values
/// beyond [packed] — every other category is a plain to-pack/packed
/// checkbox (see the design spec, "Clothing lifecycle").
enum PackingItemStatus { toPack, packed, worn, inWash, clean }
```

```dart
// lib/features/packing/domain/packing_template.dart
import 'package:flutter/foundation.dart';

import 'packing_category.dart';

@immutable
class PackingTemplate {
  const PackingTemplate({required this.id, required this.name});

  final String id;
  final String name;

  PackingTemplate copyWith({String? name}) =>
      PackingTemplate(id: id, name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      other is PackingTemplate && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

@immutable
class PackingTemplateItem {
  const PackingTemplateItem({
    required this.id,
    required this.templateId,
    required this.category,
    required this.label,
    required this.sortOrder,
  });

  final String id;
  final String templateId;
  final PackingCategory category;
  final String label;

  /// Position within this item's category section. Assigned on insert by
  /// the repository (append-to-end); not user-reorderable in this round.
  final int sortOrder;

  PackingTemplateItem copyWith({PackingCategory? category, String? label}) =>
      PackingTemplateItem(
        id: id,
        templateId: templateId,
        category: category ?? this.category,
        label: label ?? this.label,
        sortOrder: sortOrder,
      );

  @override
  bool operator ==(Object other) =>
      other is PackingTemplateItem &&
      other.id == id &&
      other.templateId == templateId &&
      other.category == category &&
      other.label == label &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, templateId, category, label, sortOrder);
}
```

```dart
// lib/features/packing/domain/trip_packing_item.dart
import 'package:flutter/foundation.dart';

import 'packing_category.dart';
import 'packing_item_status.dart';

@immutable
class TripPackingItem {
  const TripPackingItem({
    required this.id,
    required this.tripId,
    required this.category,
    required this.label,
    required this.status,
    required this.sortOrder,
  });

  final String id;
  final String tripId;
  final PackingCategory category;
  final String label;
  final PackingItemStatus status;
  final int sortOrder;

  TripPackingItem copyWith({String? label, PackingItemStatus? status}) =>
      TripPackingItem(
        id: id,
        tripId: tripId,
        category: category,
        label: label ?? this.label,
        status: status ?? this.status,
        sortOrder: sortOrder,
      );

  @override
  bool operator ==(Object other) =>
      other is TripPackingItem &&
      other.id == id &&
      other.tripId == tripId &&
      other.category == category &&
      other.label == label &&
      other.status == status &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(id, tripId, category, label, status, sortOrder);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/packing/packing_domain_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/packing/domain test/unit/packing/packing_domain_test.dart
git commit -m "feat(packing): add domain models for packing checklist"
```

---

## Task 2: Drift schema, DAO, and migration

**Files:**
- Create: `lib/features/packing/data/packing_tables.dart`
- Create: `lib/features/packing/data/packing_dao.dart` (generates `packing_dao.g.dart` via build_runner)
- Modify: `lib/core/database/app_database.dart`
- Test: `test/unit/packing/packing_migration_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1 (tables store enum values as raw `int`, not the domain enums).
- Produces: Drift tables `PackingTemplates`, `PackingTemplateItems`, `TripPackingItems` (data classes `PackingTemplateRow`, `PackingTemplateItemRow`, `TripPackingItemRow`); `PackingDao` with `watchTemplates()`, `getTemplateById(String)`, `insertTemplate(PackingTemplateRow)`, `updateTemplate(PackingTemplateRow)`, `deleteTemplate(String)`, `watchTemplateItems(String templateId)`, `getTemplateItems(String templateId)`, `getTemplateItemById(String)`, `insertTemplateItem(PackingTemplateItemRow)`, `updateTemplateItem(PackingTemplateItemRow)`, `deleteTemplateItem(String)`, `watchTripItems(String tripId)`, `getTripItems(String tripId)`, `getTripItemById(String)`, `insertTripItem(TripPackingItemRow)`, `updateTripItem(TripPackingItemRow)`, `deleteTripItem(String)`; `AppDatabase.packingDao` getter; `AppDatabase.schemaVersion == 17`.

- [ ] **Step 1: Write the failing migration test**

```dart
// test/unit/packing/packing_migration_test.dart
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
    await db.customSelect('SELECT COUNT(*) FROM trip_packing_items').getSingle();
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/packing/packing_migration_test.dart`
Expected: FAIL — schema is still at v16, tables don't exist.

- [ ] **Step 3: Create the tables**

```dart
// lib/features/packing/data/packing_tables.dart
import 'package:drift/drift.dart';

import '../../trips/data/trip_tables.dart';

@DataClassName('PackingTemplateRow')
class PackingTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PackingTemplateItemRow')
class PackingTemplateItems extends Table {
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(PackingTemplates, #id, onDelete: KeyAction.cascade)();

  /// Index into the PackingCategory enum (domain layer).
  IntColumn get category => integer()();
  TextColumn get label => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TripPackingItemRow')
class TripPackingItems extends Table {
  TextColumn get id => text()();

  /// Cascade, unlike Places (SET NULL): a packing list without its trip
  /// is meaningless — same reasoning as Expenses.tripId.
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// Index into the PackingCategory enum (domain layer).
  IntColumn get category => integer()();
  TextColumn get label => text()();

  /// Index into the PackingItemStatus enum (domain layer). Non-clothing
  /// items only ever hold toPack(0)/packed(1); clothing items use all 5.
  IntColumn get status => integer()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

- [ ] **Step 4: Create the DAO**

```dart
// lib/features/packing/data/packing_dao.dart
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'packing_tables.dart';

part 'packing_dao.g.dart';

@DriftAccessor(
  tables: [PackingTemplates, PackingTemplateItems, TripPackingItems],
)
class PackingDao extends DatabaseAccessor<AppDatabase> with _$PackingDaoMixin {
  PackingDao(super.db);

  Stream<List<PackingTemplateRow>> watchTemplates() {
    return (select(packingTemplates)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<PackingTemplateRow?> getTemplateById(String id) =>
      (select(packingTemplates)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> insertTemplate(PackingTemplateRow row) =>
      into(packingTemplates).insert(row);

  Future<void> updateTemplate(PackingTemplateRow row) =>
      update(packingTemplates).replace(row);

  Future<void> deleteTemplate(String id) =>
      (delete(packingTemplates)..where((t) => t.id.equals(id))).go();

  Stream<List<PackingTemplateItemRow>> watchTemplateItems(String templateId) {
    return (select(packingTemplateItems)
          ..where((i) => i.templateId.equals(templateId))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .watch();
  }

  Future<List<PackingTemplateItemRow>> getTemplateItems(String templateId) =>
      (select(packingTemplateItems)
            ..where((i) => i.templateId.equals(templateId)))
          .get();

  Future<PackingTemplateItemRow?> getTemplateItemById(String id) =>
      (select(packingTemplateItems)..where((i) => i.id.equals(id)))
          .getSingleOrNull();

  Future<void> insertTemplateItem(PackingTemplateItemRow row) =>
      into(packingTemplateItems).insert(row);

  Future<void> updateTemplateItem(PackingTemplateItemRow row) =>
      update(packingTemplateItems).replace(row);

  Future<void> deleteTemplateItem(String id) =>
      (delete(packingTemplateItems)..where((i) => i.id.equals(id))).go();

  Stream<List<TripPackingItemRow>> watchTripItems(String tripId) {
    return (select(tripPackingItems)
          ..where((i) => i.tripId.equals(tripId))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .watch();
  }

  Future<List<TripPackingItemRow>> getTripItems(String tripId) =>
      (select(tripPackingItems)..where((i) => i.tripId.equals(tripId))).get();

  Future<TripPackingItemRow?> getTripItemById(String id) =>
      (select(tripPackingItems)..where((i) => i.id.equals(id)))
          .getSingleOrNull();

  Future<void> insertTripItem(TripPackingItemRow row) =>
      into(tripPackingItems).insert(row);

  Future<void> updateTripItem(TripPackingItemRow row) =>
      update(tripPackingItems).replace(row);

  Future<void> deleteTripItem(String id) =>
      (delete(tripPackingItems)..where((i) => i.id.equals(id))).go();
}
```

- [ ] **Step 5: Wire into `app_database.dart`**

Add imports:

```dart
import '../../features/packing/data/packing_dao.dart';
import '../../features/packing/data/packing_tables.dart';
```

Add to the `tables:` list: `PackingTemplates, PackingTemplateItems, TripPackingItems,`
Add to the `daos:` list: `PackingDao,`

Add a schema-history line after the existing v16 line:

```dart
///   v17 — PackingTemplates + PackingTemplateItems + TripPackingItems
///         (Packing checklist feature — see
///         docs/superpowers/specs/2026-08-22-packing-checklist-design.md)
```

Bump the version and add the migration step:

```dart
  @override
  int get schemaVersion => 17;
```

```dart
          if (from < 16) {
            await m.createTable(placeCollections);
            await m.createTable(placeCollectionMemberships);
          }
          if (from < 17) {
            await m.createTable(packingTemplates);
            await m.createTable(packingTemplateItems);
            await m.createTable(tripPackingItems);
          }
```

- [ ] **Step 6: Run build_runner to generate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates/updates `app_database.g.dart` and `packing_dao.g.dart` with no errors.

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/unit/packing/packing_migration_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 8: Commit**

```bash
git add lib/features/packing/data/packing_tables.dart lib/features/packing/data/packing_dao.dart lib/features/packing/data/packing_dao.g.dart lib/core/database/app_database.dart lib/core/database/app_database.g.dart test/unit/packing/packing_migration_test.dart
git commit -m "feat(packing): add Drift schema, DAO, and v17 migration"
```

---

## Task 3: PackingRepository

**Files:**
- Create: `lib/features/packing/data/packing_repository.dart`
- Test: `test/unit/packing/packing_repository_test.dart`

**Interfaces:**
- Consumes: `PackingDao` and its methods (Task 2); `PackingCategory`, `PackingItemStatus`, `PackingTemplate`, `PackingTemplateItem`, `TripPackingItem` (Task 1).
- Produces: `abstract interface class PackingRepository` with `watchTemplates()`, `createTemplate({required name})`, `renameTemplate(id, name)`, `deleteTemplate(id)`, `watchTemplateItems(templateId)`, `addTemplateItem({required templateId, required category, required label})`, `updateTemplateItem(PackingTemplateItem)`, `deleteTemplateItem(id)`, `watchTripItems(tripId)`, `addTripItem({required tripId, required category, required label})`, `updateTripItemLabel(id, label)`, `updateTripItemStatus(id, status)`, `deleteTripItem(id)`, `applyTemplate({required tripId, required templateId})`; and `class DriftPackingRepository implements PackingRepository`, constructed as `DriftPackingRepository(PackingDao dao, String Function() idGen)`.

- [ ] **Step 1: Write the failing repository test**

```dart
// test/unit/packing/packing_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';
import 'package:tripper/features/packing/data/packing_repository.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/domain/packing_item_status.dart';
import 'package:tripper/features/trips/data/trip_repository.dart';

void main() {
  late AppDatabase db;
  late DriftPackingRepository repo;
  late DriftTripRepository tripRepo;
  var idCounter = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    idCounter = 0;
    repo = DriftPackingRepository(db.packingDao, () => 'id-${idCounter++}');
    tripRepo = DriftTripRepository(db.tripsDao, () => DateTime(2026, 8, 22));
  });

  tearDown(() => db.close());

  Future<String> createTrip() => tripRepo.createTrip(
        name: 'Thailand',
        destinations: ['Krabi'],
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 14),
        colorTag: 0,
      );

  test('creating a template makes it appear in watchTemplates', () async {
    await repo.createTemplate(name: 'Beach trip');
    final templates = await repo.watchTemplates().first;
    expect(templates.single.name, 'Beach trip');
  });

  test('renaming a template updates it in place', () async {
    final id = await repo.createTemplate(name: 'Beach trip');
    await repo.renameTemplate(id, 'Summer beach trip');
    final templates = await repo.watchTemplates().first;
    expect(templates.single.name, 'Summer beach trip');
  });

  test('deleting a template removes it', () async {
    final id = await repo.createTemplate(name: 'Beach trip');
    await repo.deleteTemplate(id);
    expect(await repo.watchTemplates().first, isEmpty);
  });

  test('template items are returned for their own template only', () async {
    final tplA = await repo.createTemplate(name: 'A');
    final tplB = await repo.createTemplate(name: 'B');
    await repo.addTemplateItem(
      templateId: tplA,
      category: PackingCategory.clothing,
      label: 'Shirt',
    );
    await repo.addTemplateItem(
      templateId: tplB,
      category: PackingCategory.documents,
      label: 'Passport',
    );

    final itemsA = await repo.watchTemplateItems(tplA).first;
    expect(itemsA, hasLength(1));
    expect(itemsA.single.label, 'Shirt');
  });

  test('a trip item defaults to toPack status', () async {
    final tripId = await createTrip();
    await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.clothing,
      label: 'Black shirt',
    );
    final items = await repo.watchTripItems(tripId).first;
    expect(items.single.status, PackingItemStatus.toPack);
  });

  test('a status update can jump directly from worn to clean', () async {
    final tripId = await createTrip();
    final id = await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.clothing,
      label: 'Black shirt',
    );
    await repo.updateTripItemStatus(id, PackingItemStatus.worn);
    await repo.updateTripItemStatus(id, PackingItemStatus.clean);

    final items = await repo.watchTripItems(tripId).first;
    expect(items.single.status, PackingItemStatus.clean);
  });

  test(
      'applyTemplate copies every item into the trip list, each starting '
      'at toPack', () async {
    final tripId = await createTrip();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.documents,
      label: 'Passport',
    );

    await repo.applyTemplate(tripId: tripId, templateId: templateId);

    final tripItems = await repo.watchTripItems(tripId).first;
    expect(tripItems, hasLength(2));
    expect(tripItems.map((i) => i.label), containsAll(['Swimsuit', 'Passport']));
    expect(tripItems.every((i) => i.status == PackingItemStatus.toPack), isTrue);
  });

  test(
      'the trip list is independent of the template afterward — editing '
      'the template item does not change the already-copied trip item',
      () async {
    final tripId = await createTrip();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    final templateItemId = await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await repo.applyTemplate(tripId: tripId, templateId: templateId);

    final templateItems = await repo.watchTemplateItems(templateId).first;
    await repo.updateTemplateItem(
      templateItems.single.copyWith(label: 'Two swimsuits'),
    );

    final tripItems = await repo.watchTripItems(tripId).first;
    expect(tripItems.single.label, 'Swimsuit'); // unchanged
    expect(templateItemId, isNotEmpty); // sanity: id was actually used
  });

  test('applying the same template twice duplicates its items (append, '
      'not replace)', () async {
    final tripId = await createTrip();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );

    await repo.applyTemplate(tripId: tripId, templateId: templateId);
    await repo.applyTemplate(tripId: tripId, templateId: templateId);

    final tripItems = await repo.watchTripItems(tripId).first;
    expect(tripItems, hasLength(2));
  });

  test('deleting a trip cascades its packing items', () async {
    final tripId = await createTrip();
    await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.other,
      label: 'Charger',
    );
    await tripRepo.deleteTrip(tripId);
    expect(await repo.watchTripItems(tripId).first, isEmpty);
  });

  test('deleting a trip item removes it', () async {
    final tripId = await createTrip();
    final id = await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.other,
      label: 'Charger',
    );
    await repo.deleteTripItem(id);
    expect(await repo.watchTripItems(tripId).first, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/packing/packing_repository_test.dart`
Expected: FAIL — `packing_repository.dart` doesn't exist yet.

- [ ] **Step 3: Implement the repository**

```dart
// lib/features/packing/data/packing_repository.dart
import 'packing_dao.dart';
import 'packing_tables.dart';
import '../domain/packing_category.dart';
import '../domain/packing_item_status.dart';
import '../domain/packing_template.dart';
import '../domain/trip_packing_item.dart';

/// Widget tests mock at this boundary (testing rules).
abstract interface class PackingRepository {
  Stream<List<PackingTemplate>> watchTemplates();
  Future<String> createTemplate({required String name});
  Future<void> renameTemplate(String id, String name);
  Future<void> deleteTemplate(String id);

  Stream<List<PackingTemplateItem>> watchTemplateItems(String templateId);
  Future<String> addTemplateItem({
    required String templateId,
    required PackingCategory category,
    required String label,
  });
  Future<void> updateTemplateItem(PackingTemplateItem item);
  Future<void> deleteTemplateItem(String id);

  Stream<List<TripPackingItem>> watchTripItems(String tripId);
  Future<String> addTripItem({
    required String tripId,
    required PackingCategory category,
    required String label,
  });
  Future<void> updateTripItemLabel(String id, String label);
  Future<void> updateTripItemStatus(String id, PackingItemStatus status);
  Future<void> deleteTripItem(String id);

  /// Copies every item from [templateId] into [tripId]'s list, each
  /// starting at [PackingItemStatus.toPack]. Appends — never replaces —
  /// and keeps no link back to the template afterward (see design spec,
  /// "Apply semantics").
  Future<void> applyTemplate({
    required String tripId,
    required String templateId,
  });
}

class DriftPackingRepository implements PackingRepository {
  DriftPackingRepository(this._dao, this._idGen);

  final PackingDao _dao;
  final String Function() _idGen;

  @override
  Stream<List<PackingTemplate>> watchTemplates() =>
      _dao.watchTemplates().map((rows) => rows.map(_templateToDomain).toList());

  @override
  Future<String> createTemplate({required String name}) async {
    final id = _idGen();
    await _dao.insertTemplate(PackingTemplateRow(id: id, name: name.trim()));
    return id;
  }

  @override
  Future<void> renameTemplate(String id, String name) async {
    final existing = await _dao.getTemplateById(id);
    if (existing == null) return;
    await _dao.updateTemplate(existing.copyWith(name: name.trim()));
  }

  @override
  Future<void> deleteTemplate(String id) => _dao.deleteTemplate(id);

  @override
  Stream<List<PackingTemplateItem>> watchTemplateItems(String templateId) =>
      _dao
          .watchTemplateItems(templateId)
          .map((rows) => rows.map(_templateItemToDomain).toList());

  @override
  Future<String> addTemplateItem({
    required String templateId,
    required PackingCategory category,
    required String label,
  }) async {
    final id = _idGen();
    final sortOrder = await _nextSortOrder(
      await _dao.getTemplateItems(templateId),
      category,
    );
    await _dao.insertTemplateItem(
      PackingTemplateItemRow(
        id: id,
        templateId: templateId,
        category: category.index,
        label: label.trim(),
        sortOrder: sortOrder,
      ),
    );
    return id;
  }

  @override
  Future<void> updateTemplateItem(PackingTemplateItem item) =>
      _dao.updateTemplateItem(
        PackingTemplateItemRow(
          id: item.id,
          templateId: item.templateId,
          category: item.category.index,
          label: item.label.trim(),
          sortOrder: item.sortOrder,
        ),
      );

  @override
  Future<void> deleteTemplateItem(String id) => _dao.deleteTemplateItem(id);

  @override
  Stream<List<TripPackingItem>> watchTripItems(String tripId) => _dao
      .watchTripItems(tripId)
      .map((rows) => rows.map(_tripItemToDomain).toList());

  @override
  Future<String> addTripItem({
    required String tripId,
    required PackingCategory category,
    required String label,
  }) async {
    final id = _idGen();
    final sortOrder =
        await _nextSortOrder(await _dao.getTripItems(tripId), category);
    await _dao.insertTripItem(
      TripPackingItemRow(
        id: id,
        tripId: tripId,
        category: category.index,
        label: label.trim(),
        status: PackingItemStatus.toPack.index,
        sortOrder: sortOrder,
      ),
    );
    return id;
  }

  @override
  Future<void> updateTripItemLabel(String id, String label) async {
    final existing = await _dao.getTripItemById(id);
    if (existing == null) return;
    await _dao.updateTripItem(existing.copyWith(label: label.trim()));
  }

  @override
  Future<void> updateTripItemStatus(
    String id,
    PackingItemStatus status,
  ) async {
    final existing = await _dao.getTripItemById(id);
    if (existing == null) return;
    await _dao.updateTripItem(existing.copyWith(status: status.index));
  }

  @override
  Future<void> deleteTripItem(String id) => _dao.deleteTripItem(id);

  @override
  Future<void> applyTemplate({
    required String tripId,
    required String templateId,
  }) async {
    final templateItems = await _dao.getTemplateItems(templateId);
    final existingTripItems = await _dao.getTripItems(tripId);
    final nextSortOrder = <int, int>{
      for (final category in PackingCategory.values)
        category.index: existingTripItems
            .where((i) => i.category == category.index)
            .length,
    };
    for (final item in templateItems) {
      final sortOrder = nextSortOrder[item.category]!;
      nextSortOrder[item.category] = sortOrder + 1;
      await _dao.insertTripItem(
        TripPackingItemRow(
          id: _idGen(),
          tripId: tripId,
          category: item.category,
          label: item.label,
          status: PackingItemStatus.toPack.index,
          sortOrder: sortOrder,
        ),
      );
    }
  }

  /// Appends to the end of [category]'s section among [existingRows] —
  /// same "count = next index" scheme for both template and trip items.
  Future<int> _nextSortOrder(List<dynamic> existingRows, PackingCategory category) async {
    var count = 0;
    for (final row in existingRows) {
      final rowCategory = row.category as int;
      if (rowCategory == category.index) count++;
    }
    return count;
  }

  PackingTemplate _templateToDomain(PackingTemplateRow row) =>
      PackingTemplate(id: row.id, name: row.name);

  PackingTemplateItem _templateItemToDomain(PackingTemplateItemRow row) =>
      PackingTemplateItem(
        id: row.id,
        templateId: row.templateId,
        category: _categoryFromIndex(row.category),
        label: row.label,
        sortOrder: row.sortOrder,
      );

  TripPackingItem _tripItemToDomain(TripPackingItemRow row) => TripPackingItem(
        id: row.id,
        tripId: row.tripId,
        category: _categoryFromIndex(row.category),
        label: row.label,
        status: _statusFromIndex(row.status),
        sortOrder: row.sortOrder,
      );

  // Defensive: an index from a newer schema version falls back to a safe
  // default rather than throwing a RangeError on an old build (same
  // precedent as ExpenseRepository._toDomain).
  PackingCategory _categoryFromIndex(int index) =>
      index >= 0 && index < PackingCategory.values.length
          ? PackingCategory.values[index]
          : PackingCategory.other;

  PackingItemStatus _statusFromIndex(int index) =>
      index >= 0 && index < PackingItemStatus.values.length
          ? PackingItemStatus.values[index]
          : PackingItemStatus.toPack;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/packing/packing_repository_test.dart`
Expected: PASS (12 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/packing/data/packing_repository.dart test/unit/packing/packing_repository_test.dart
git commit -m "feat(packing): add PackingRepository with copy-on-apply semantics"
```

---

## Task 4: Providers, category/status presentation helpers, and the Trip Packing tab

**Files:**
- Create: `lib/features/packing/presentation/packing_providers.dart`
- Create: `lib/features/packing/presentation/packing_widgets.dart`
- Create: `lib/features/packing/presentation/trip_packing_tab.dart`
- Create: `test/helpers/fake_packing_repository.dart`
- Test: `test/widget/packing/trip_packing_tab_test.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `PackingRepository`, `DriftPackingRepository`, domain types (Tasks 1, 3); `PillChip`, `PaperCard`, `SectionLabel`, `EmptyState`, `ErrorState` (existing `lib/core/widgets/`); `Trip` (`lib/features/trips/domain/trip.dart`).
- Produces: `packingDaoProvider`, `packingRepositoryProvider`, `packingTemplatesProvider` (`StreamProvider<List<PackingTemplate>>`), `tripPackingItemsProvider` (`StreamProvider.family<List<TripPackingItem>, String>`), `packingTemplateItemsProvider` (`StreamProvider.family<List<PackingTemplateItem>, String>`); `packingCategoryLabel(l10n, category)`, `packingCategoryIcon(category)`, `packingStatusLabel(l10n, status)`; `class TripPackingTab extends ConsumerStatefulWidget({required Trip trip})`; `class FakePackingRepository implements PackingRepository` (test helper, constructed with optional initial `templates`/`templateItems`/`tripItems` lists, with an `emitTripItemsError` method matching `FakeExpenseRepository.emitError`'s shape).

- [ ] **Step 1: Add ARB strings**

Add to `lib/l10n/app_en.arb` (near the other `tab*` and feature-empty-state keys):

```json
  "tabPacking": "Packing",
  "packingEmptyTitle": "Nothing packed yet",
  "packingEmptyBody": "Add items yourself, or apply a saved template to get started.",
  "packingEmptyCta": "Add an item",
  "packingCatClothing": "Clothing",
  "packingCatDocuments": "Documents",
  "packingCatElectronics": "Electronics",
  "packingCatToiletries": "Toiletries",
  "packingCatOther": "Other",
  "packingStatusToPack": "To pack",
  "packingStatusPacked": "Packed",
  "packingStatusWorn": "Worn",
  "packingStatusInWash": "In wash",
  "packingStatusClean": "Clean",
  "deletePackingItemTitle": "Delete this item?",
  "deletePackingItemBody": "This removes it from the packing list.",
  "packingItemDeleted": "Item deleted."
```

- [ ] **Step 2: Write the failing widget test**

```dart
// test/widget/packing/trip_packing_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/domain/packing_item_status.dart';
import 'package:tripper/features/packing/domain/trip_packing_item.dart';
import 'package:tripper/features/packing/presentation/packing_providers.dart';
import 'package:tripper/features/packing/presentation/trip_packing_tab.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_packing_repository.dart';

const _trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

TripPackingItem _item({
  required String id,
  PackingCategory category = PackingCategory.other,
  String label = 'Charger',
  PackingItemStatus status = PackingItemStatus.toPack,
  String tripId = 't1',
}) =>
    TripPackingItem(
      id: id,
      tripId: tripId,
      category: category,
      label: label,
      status: status,
      sortOrder: 0,
    );

Widget _app(FakePackingRepository repo) => ProviderScope(
      overrides: [packingRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TripPackingTab(trip: _trip)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('empty trip shows the designed empty state', (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Nothing packed yet'), findsOneWidget);
  });

  testWidgets('items render grouped under their category header',
      (tester) async {
    final repo = FakePackingRepository(tripItems: [
      _item(id: 'a', category: PackingCategory.clothing, label: 'Black shirt'),
      _item(id: 'b', category: PackingCategory.documents, label: 'Passport'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('CLOTHING'), findsOneWidget);
    expect(find.text('DOCUMENTS'), findsOneWidget);
    expect(find.text('Black shirt'), findsOneWidget);
    expect(find.text('Passport'), findsOneWidget);
    // Categories with nothing in them stay hidden.
    expect(find.text('ELECTRONICS'), findsNothing);
  });

  testWidgets('tapping a non-clothing item toggles checked/unchecked',
      (tester) async {
    final repo = FakePackingRepository(tripItems: [
      _item(id: 'a', category: PackingCategory.documents, label: 'Passport'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(
      (await repo.watchTripItems('t1').first).single.status,
      PackingItemStatus.packed,
    );
  });

  testWidgets(
      'a clothing item shows its status and opens a 5-option menu on tap',
      (tester) async {
    final repo = FakePackingRepository(tripItems: [
      _item(
        id: 'a',
        category: PackingCategory.clothing,
        label: 'Black shirt',
        status: PackingItemStatus.worn,
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Worn'), findsOneWidget);

    await tester.tap(find.text('Black shirt'));
    await tester.pumpAndSettle();

    expect(find.text('To pack'), findsWidgets);
    expect(find.text('Clean'), findsWidgets);

    await tester.tap(find.text('Clean').last);
    await tester.pumpAndSettle();

    expect(
      (await repo.watchTripItems('t1').first).single.status,
      PackingItemStatus.clean,
    );
  });

  testWidgets('deleting an item asks for confirmation first', (tester) async {
    final repo = FakePackingRepository(
      tripItems: [_item(id: 'a', label: 'Charger')],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Charger'), findsOneWidget); // still there

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Charger'), findsNothing);
    expect(find.text('Item deleted.'), findsOneWidget);
  });

  testWidgets('a stream failure shows the error state with retry',
      (tester) async {
    final repo = FakePackingRepository(tripItems: [_item(id: 'a')]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    repo.emitTripItemsError(Exception('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/packing/trip_packing_tab_test.dart`
Expected: FAIL — none of the new files exist yet.

- [ ] **Step 4: Implement the fake repository**

```dart
// test/helpers/fake_packing_repository.dart
import 'dart:async';

import 'package:tripper/features/packing/data/packing_repository.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/domain/packing_item_status.dart';
import 'package:tripper/features/packing/domain/packing_template.dart';
import 'package:tripper/features/packing/domain/trip_packing_item.dart';

/// Fake at the repository boundary (testing rules — no DB in widget tests).
class FakePackingRepository implements PackingRepository {
  FakePackingRepository({
    List<PackingTemplate> templates = const [],
    List<PackingTemplateItem> templateItems = const [],
    List<TripPackingItem> tripItems = const [],
  })  : _templates = [...templates],
        _templateItems = [...templateItems],
        _tripItems = [...tripItems];

  final List<PackingTemplate> _templates;
  final List<PackingTemplateItem> _templateItems;
  final List<TripPackingItem> _tripItems;

  final _templatesController =
      StreamController<List<PackingTemplate>>.broadcast();
  final _templateItemsController =
      StreamController<List<PackingTemplateItem>>.broadcast();
  final _tripItemsController =
      StreamController<List<TripPackingItem>>.broadcast();
  var _idCounter = 0;

  void emitTripItemsError(Object error) => _tripItemsController.addError(error);

  @override
  Stream<List<PackingTemplate>> watchTemplates() async* {
    yield List.of(_templates);
    yield* _templatesController.stream;
  }

  @override
  Future<String> createTemplate({required String name}) async {
    final template = PackingTemplate(id: 'tpl-${_idCounter++}', name: name);
    _templates.add(template);
    _templatesController.add(List.of(_templates));
    return template.id;
  }

  @override
  Future<void> renameTemplate(String id, String name) async {
    final i = _templates.indexWhere((t) => t.id == id);
    if (i == -1) return;
    _templates[i] = _templates[i].copyWith(name: name);
    _templatesController.add(List.of(_templates));
  }

  @override
  Future<void> deleteTemplate(String id) async {
    _templates.removeWhere((t) => t.id == id);
    _templateItems.removeWhere((i) => i.templateId == id);
    _templatesController.add(List.of(_templates));
    _templateItemsController.add(List.of(_templateItems));
  }

  @override
  Stream<List<PackingTemplateItem>> watchTemplateItems(
    String templateId,
  ) async* {
    yield _templateItems.where((i) => i.templateId == templateId).toList();
    yield* _templateItemsController.stream
        .map((_) => _templateItems.where((i) => i.templateId == templateId).toList());
  }

  @override
  Future<String> addTemplateItem({
    required String templateId,
    required PackingCategory category,
    required String label,
  }) async {
    final item = PackingTemplateItem(
      id: 'tpli-${_idCounter++}',
      templateId: templateId,
      category: category,
      label: label,
      sortOrder: _templateItems.where((i) => i.templateId == templateId && i.category == category).length,
    );
    _templateItems.add(item);
    _templateItemsController.add(List.of(_templateItems));
    return item.id;
  }

  @override
  Future<void> updateTemplateItem(PackingTemplateItem item) async {
    final i = _templateItems.indexWhere((e) => e.id == item.id);
    if (i == -1) return;
    _templateItems[i] = item;
    _templateItemsController.add(List.of(_templateItems));
  }

  @override
  Future<void> deleteTemplateItem(String id) async {
    _templateItems.removeWhere((i) => i.id == id);
    _templateItemsController.add(List.of(_templateItems));
  }

  @override
  Stream<List<TripPackingItem>> watchTripItems(String tripId) async* {
    yield _tripItems.where((i) => i.tripId == tripId).toList();
    yield* _tripItemsController.stream
        .map((_) => _tripItems.where((i) => i.tripId == tripId).toList());
  }

  @override
  Future<String> addTripItem({
    required String tripId,
    required PackingCategory category,
    required String label,
  }) async {
    final item = TripPackingItem(
      id: 'i-${_idCounter++}',
      tripId: tripId,
      category: category,
      label: label,
      status: PackingItemStatus.toPack,
      sortOrder: _tripItems.where((i) => i.tripId == tripId && i.category == category).length,
    );
    _tripItems.add(item);
    _tripItemsController.add(List.of(_tripItems));
    return item.id;
  }

  @override
  Future<void> updateTripItemLabel(String id, String label) async {
    final i = _tripItems.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _tripItems[i] = _tripItems[i].copyWith(label: label);
    _tripItemsController.add(List.of(_tripItems));
  }

  @override
  Future<void> updateTripItemStatus(String id, PackingItemStatus status) async {
    final i = _tripItems.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _tripItems[i] = _tripItems[i].copyWith(status: status);
    _tripItemsController.add(List.of(_tripItems));
  }

  @override
  Future<void> deleteTripItem(String id) async {
    _tripItems.removeWhere((i) => i.id == id);
    _tripItemsController.add(List.of(_tripItems));
  }

  @override
  Future<void> applyTemplate({
    required String tripId,
    required String templateId,
  }) async {
    final source = _templateItems.where((i) => i.templateId == templateId);
    for (final item in source) {
      _tripItems.add(
        TripPackingItem(
          id: 'i-${_idCounter++}',
          tripId: tripId,
          category: item.category,
          label: item.label,
          status: PackingItemStatus.toPack,
          sortOrder: _tripItems.where((i) => i.tripId == tripId && i.category == item.category).length,
        ),
      );
    }
    _tripItemsController.add(List.of(_tripItems));
  }
}
```

- [ ] **Step 5: Implement providers**

```dart
// lib/features/packing/presentation/packing_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_provider.dart';
import '../data/packing_dao.dart';
import '../data/packing_repository.dart';
import '../domain/packing_template.dart';
import '../domain/trip_packing_item.dart';

const _uuid = Uuid();

final packingDaoProvider =
    Provider<PackingDao>((ref) => ref.watch(databaseProvider).packingDao);

final packingRepositoryProvider = Provider<PackingRepository>(
  (ref) => DriftPackingRepository(ref.watch(packingDaoProvider), _uuid.v4),
);

final packingTemplatesProvider = StreamProvider<List<PackingTemplate>>(
  (ref) => ref.watch(packingRepositoryProvider).watchTemplates(),
);

final packingTemplateItemsProvider =
    StreamProvider.family<List<PackingTemplateItem>, String>(
  (ref, templateId) =>
      ref.watch(packingRepositoryProvider).watchTemplateItems(templateId),
);

final tripPackingItemsProvider =
    StreamProvider.family<List<TripPackingItem>, String>(
  (ref, tripId) => ref.watch(packingRepositoryProvider).watchTripItems(tripId),
);
```

- [ ] **Step 6: Implement category/status presentation helpers**

```dart
// lib/features/packing/presentation/packing_widgets.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_category.dart';
import '../domain/packing_item_status.dart';

IconData packingCategoryIcon(PackingCategory category) => switch (category) {
      PackingCategory.clothing => Icons.checkroom_outlined,
      PackingCategory.documents => Icons.description_outlined,
      PackingCategory.electronics => Icons.power_outlined,
      PackingCategory.toiletries => Icons.soap_outlined,
      PackingCategory.other => Icons.inventory_2_outlined,
    };

String packingCategoryLabel(AppLocalizations l10n, PackingCategory category) =>
    switch (category) {
      PackingCategory.clothing => l10n.packingCatClothing,
      PackingCategory.documents => l10n.packingCatDocuments,
      PackingCategory.electronics => l10n.packingCatElectronics,
      PackingCategory.toiletries => l10n.packingCatToiletries,
      PackingCategory.other => l10n.packingCatOther,
    };

String packingStatusLabel(AppLocalizations l10n, PackingItemStatus status) =>
    switch (status) {
      PackingItemStatus.toPack => l10n.packingStatusToPack,
      PackingItemStatus.packed => l10n.packingStatusPacked,
      PackingItemStatus.worn => l10n.packingStatusWorn,
      PackingItemStatus.inWash => l10n.packingStatusInWash,
      PackingItemStatus.clean => l10n.packingStatusClean,
    };

/// The clothing-only status readout — a small non-interactive chip, kept
/// visually inside the same [PillChip] language the rest of the app uses.
/// Tapping the row (not the chip itself) opens the 5-option menu.
class PackingStatusChip extends StatelessWidget {
  const PackingStatusChip({super.key, required this.status});

  final PackingItemStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PillChip(
      label: packingStatusLabel(l10n, status),
      selected: status != PackingItemStatus.toPack,
    );
  }
}
```

- [ ] **Step 7: Implement the trip tab**

```dart
// lib/features/packing/presentation/trip_packing_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/packing_category.dart';
import '../domain/packing_item_status.dart';
import '../domain/trip_packing_item.dart';
import 'packing_providers.dart';
import 'packing_widgets.dart';

class TripPackingTab extends ConsumerStatefulWidget {
  const TripPackingTab({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripPackingTab> createState() => _TripPackingTabState();
}

class _TripPackingTabState extends ConsumerState<TripPackingTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncItems = ref.watch(tripPackingItemsProvider(widget.trip.id));

    // Everything below returns through this one Scaffold — Task 5 adds
    // `floatingActionButton:` and Task 6 adds `appBar:` to this same
    // widget rather than restructuring it, so the overflow menu (once
    // Task 6 adds it) is reachable from every state, including empty and
    // error, not just the populated list.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _body(context, l10n, asyncItems),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<TripPackingItem>> asyncItems,
  ) {
    if (asyncItems.hasError) {
      return ErrorState(
        onRetry: () =>
            ref.invalidate(tripPackingItemsProvider(widget.trip.id)),
      );
    }

    final items = asyncItems.valueOrNull ?? const <TripPackingItem>[];

    if (asyncItems.hasValue && items.isEmpty) {
      return EmptyState(
        icon: Icons.luggage_outlined,
        title: l10n.packingEmptyTitle,
        body: l10n.packingEmptyBody,
        ctaLabel: l10n.packingEmptyCta,
        onCta: () {}, // Wired to the add-item sheet in Task 5.
      );
    }

    final byCategory = <PackingCategory, List<TripPackingItem>>{};
    for (final item in items) {
      (byCategory[item.category] ??= []).add(item);
    }

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        for (final category in PackingCategory.values)
          if (byCategory[category] case final categoryItems?
              when categoryItems.isNotEmpty) ...[
            SectionLabel(packingCategoryLabel(l10n, category)),
            const SizedBox(height: AppSpacing.sm),
            for (final item in categoryItems) ...[
              _ItemRow(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item});

  final TripPackingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isClothing = item.category == PackingCategory.clothing;

    return PaperCard(
      onTap: isClothing ? () => _pickStatus(context, ref) : null,
      child: Row(
        children: [
          if (!isClothing)
            Checkbox(
              value: item.status == PackingItemStatus.packed,
              onChanged: (checked) => ref
                  .read(packingRepositoryProvider)
                  .updateTripItemStatus(
                    item.id,
                    (checked ?? false)
                        ? PackingItemStatus.packed
                        : PackingItemStatus.toPack,
                  ),
            ),
          Expanded(
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
          if (isClothing) PackingStatusChip(status: item.status),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStatus(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final status = await showModalBottomSheet<PackingItemStatus>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in PackingItemStatus.values)
              ListTile(
                title: Text(packingStatusLabel(l10n, s)),
                selected: s == item.status,
                onTap: () => Navigator.of(context).pop(s),
              ),
          ],
        ),
      ),
    );
    if (status == null) return;
    await ref
        .read(packingRepositoryProvider)
        .updateTripItemStatus(item.id, status);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePackingItemTitle),
        content: Text(l10n.deletePackingItemBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.menuDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = ref.read(packingRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.deleteTripItem(item.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.packingItemDeleted)));
  }
}
```

- [ ] **Step 8: Generate localizations and run test to verify it passes**

Run: `flutter gen-l10n` (or `flutter pub get`, which triggers it automatically if `generate: true` in `pubspec.yaml`), then:
Run: `flutter test test/widget/packing/trip_packing_tab_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 9: Commit**

```bash
git add lib/features/packing/presentation/packing_providers.dart lib/features/packing/presentation/packing_widgets.dart lib/features/packing/presentation/trip_packing_tab.dart lib/l10n/app_en.arb test/helpers/fake_packing_repository.dart test/widget/packing/trip_packing_tab_test.dart
git commit -m "feat(packing): add providers and the trip Packing tab"
```

---

## Task 5: Add/edit item form sheet

**Files:**
- Create: `lib/features/packing/presentation/packing_item_form_sheet.dart`
- Modify: `lib/features/packing/presentation/trip_packing_tab.dart`
- Modify: `test/widget/packing/trip_packing_tab_test.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `PackingCategory`, `PillChip`, `packingCategoryLabel`/`packingCategoryIcon` (Task 4).
- Produces: `Future<void> showPackingItemFormSheet(BuildContext, {required String tripId, TripPackingItem? existing})` — opens a bottom sheet to add or edit a trip item (category picker + label text field); calls `packingRepositoryProvider`'s `addTripItem`/`updateTripItemLabel` directly (category is fixed once created, matching the design's "fixed categories" decision — editing an item only changes its label, not its category, to avoid a resort-into-a-new-section edge case this round). Wires into `TripPackingTab`'s empty-state CTA and a new FAB.

- [ ] **Step 1: Add ARB strings**

```json
  "packingItemFormAddTitle": "Add item",
  "packingItemFormEditTitle": "Edit item",
  "packingItemFormLabel": "Item",
  "packingItemFormCategory": "Category",
  "errPackingLabelRequired": "Enter a name for this item"
```

- [ ] **Step 2: Write the failing test additions**

Add to `test/widget/packing/trip_packing_tab_test.dart`:

```dart
  testWidgets('the empty-state CTA opens the add-item sheet', (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add an item'));
    await tester.pumpAndSettle();

    expect(find.text('Add item'), findsOneWidget);
  });

  testWidgets(
      'adding an item picks a category and label, then appears in that '
      "category's section", (tester) async {
    final repo = FakePackingRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add an item'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Documents'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Item'),
      'Passport',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('DOCUMENTS'), findsOneWidget);
  });

  testWidgets('a floating add button is shown once there are items',
      (tester) async {
    final repo = FakePackingRepository(tripItems: [_item(id: 'a')]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add item'), findsOneWidget);
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/packing/trip_packing_tab_test.dart`
Expected: FAIL — no FAB, empty-state CTA is a no-op, `showPackingItemFormSheet` doesn't exist.

- [ ] **Step 4: Implement the form sheet**

```dart
// lib/features/packing/presentation/packing_item_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_category.dart';
import 'packing_providers.dart';
import 'packing_widgets.dart';

/// Add (or, with [existingLabel]/[existingId], edit) a trip packing item.
/// Category is only asked when creating — editing changes the label only,
/// so an item never has to move between category sections this round.
Future<void> showPackingItemFormSheet(
  BuildContext context, {
  required String tripId,
  String? existingId,
  String? existingLabel,
  PackingCategory? existingCategory,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ItemForm(
        tripId: tripId,
        existingId: existingId,
        existingLabel: existingLabel,
        existingCategory: existingCategory,
      ),
    ),
  );
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({
    required this.tripId,
    this.existingId,
    this.existingLabel,
    this.existingCategory,
  });

  final String tripId;
  final String? existingId;
  final String? existingLabel;
  final PackingCategory? existingCategory;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  late final TextEditingController _label;
  late PackingCategory _category;
  bool _labelError = false;
  bool _saving = false;

  bool get _isEdit => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existingLabel ?? '');
    _category = widget.existingCategory ?? PackingCategory.clothing;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Text(
          _isEdit ? l10n.packingItemFormEditTitle : l10n.packingItemFormAddTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _label,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.packingItemFormLabel,
            errorText: _labelError ? l10n.errPackingLabelRequired : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_isEdit) ...[
          Text(l10n.packingItemFormCategory),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in PackingCategory.values)
                PillChip(
                  label: packingCategoryLabel(l10n, c),
                  icon: packingCategoryIcon(c),
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    setState(() => _labelError = label.isEmpty);
    if (label.isEmpty) return;

    setState(() => _saving = true);
    final repo = ref.read(packingRepositoryProvider);
    final existingId = widget.existingId;
    if (existingId == null) {
      await repo.addTripItem(
        tripId: widget.tripId,
        category: _category,
        label: label,
      );
    } else {
      await repo.updateTripItemLabel(existingId, label);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
```

- [ ] **Step 5: Wire the sheet into `TripPackingTab`**

In `trip_packing_tab.dart`, add the import `import 'packing_item_form_sheet.dart';`.

Task 4's `build()` already wraps every state in one `Scaffold` (see its comment) — this step only adds a `floatingActionButton:` to that same `Scaffold`, shown only once there's something to add to (empty state keeps its own CTA instead, matching `TripExpensesTab`'s precedent):

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncItems = ref.watch(tripPackingItemsProvider(widget.trip.id));
    final hasItems = (asyncItems.valueOrNull ?? const []).isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: hasItems
          ? FloatingActionButton(
              onPressed: () =>
                  showPackingItemFormSheet(context, tripId: widget.trip.id),
              child: const Icon(Icons.add),
            )
          : null,
      body: _body(context, l10n, asyncItems),
    );
  }
```

Replace the empty-state's `onCta: () {}` (in `_body`) with:

```dart
        onCta: () =>
            showPackingItemFormSheet(context, tripId: widget.trip.id),
```

Make `_ItemRow`'s tap-to-edit reachable for non-clothing rows (clothing rows already use the whole card's tap for the status menu). Replace the `Expanded` label in `_ItemRow.build`:

```dart
          Expanded(
            child: isClothing
                ? Text(item.label, overflow: TextOverflow.ellipsis)
                : InkWell(
                    onTap: () => showPackingItemFormSheet(
                      context,
                      tripId: item.tripId,
                      existingId: item.id,
                      existingLabel: item.label,
                      existingCategory: item.category,
                    ),
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
          ),
```

Add the import `import 'packing_item_form_sheet.dart';` to `_ItemRow`'s file if not already present (same file as above).

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/widget/packing/trip_packing_tab_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 7: Commit**

```bash
git add lib/features/packing/presentation/packing_item_form_sheet.dart lib/features/packing/presentation/trip_packing_tab.dart lib/l10n/app_en.arb test/widget/packing/trip_packing_tab_test.dart
git commit -m "feat(packing): add the add/edit item form sheet"
```

---

## Task 6: Apply-template picker sheet

**Files:**
- Create: `lib/features/packing/presentation/apply_template_sheet.dart`
- Modify: `lib/features/packing/presentation/trip_packing_tab.dart`
- Modify: `test/widget/packing/trip_packing_tab_test.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `packingTemplatesProvider`, `packingRepositoryProvider.applyTemplate` (Tasks 3, 4).
- Produces: `Future<void> showApplyTemplateSheet(BuildContext, {required String tripId})`; an overflow `PopupMenuButton` on `TripPackingTab`'s `AppBar` with an "Apply template…" action (and a placeholder "Manage templates…" action wired for real in Task 7).

- [ ] **Step 1: Add ARB strings**

```json
  "packingApplyTemplateAction": "Apply template…",
  "packingManageTemplatesAction": "Manage templates…",
  "packingApplyTemplateEmpty": "No saved templates yet — create one from Manage templates.",
  "packingApplyTemplateApplied": "{count, plural, one{Added 1 item from {name}} other{Added {count} items from {name}}}",
  "@packingApplyTemplateApplied": {
    "placeholders": {
      "count": { "type": "int" },
      "name": { "type": "String" }
    }
  }
```

- [ ] **Step 2: Write the failing test additions**

Add to `test/widget/packing/trip_packing_tab_test.dart` — no new override is needed in `_app`: `packingTemplatesProvider` reads through `packingRepositoryProvider`, which is already overridden there.

```dart
  testWidgets('applying a template with no saved templates shows a hint',
      (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply template…'));
    await tester.pumpAndSettle();

    expect(
      find.text('No saved templates yet — create one from Manage templates.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'applying a template appends its items to the trip list and shows '
      'a confirmation', (tester) async {
    final repo = FakePackingRepository();
    await repo.createTemplate(name: 'Beach trip');
    final templates = await repo.watchTemplates().first;
    await repo.addTemplateItem(
      templateId: templates.single.id,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply template…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beach trip'));
    await tester.pumpAndSettle();

    expect(find.text('Swimsuit'), findsOneWidget);
    expect(find.text('Added 1 item from Beach trip'), findsOneWidget);
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/packing/trip_packing_tab_test.dart`
Expected: FAIL — no `PopupMenuButton` on the tab yet.

- [ ] **Step 4: Implement the apply-template sheet**

```dart
// lib/features/packing/presentation/apply_template_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import 'packing_providers.dart';

Future<void> showApplyTemplateSheet(
  BuildContext context, {
  required String tripId,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => _ApplyTemplateSheet(tripId: tripId),
  );
}

class _ApplyTemplateSheet extends ConsumerWidget {
  const _ApplyTemplateSheet({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final templates = ref.watch(packingTemplatesProvider).valueOrNull ?? const [];

    if (templates.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Text(l10n.packingApplyTemplateEmpty),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final template in templates)
            ListTile(
              title: Text(template.name),
              onTap: () async {
                final repo = ref.read(packingRepositoryProvider);
                final itemCountBefore =
                    (await repo.watchTripItems(tripId).first).length;
                await repo.applyTemplate(
                  tripId: tripId,
                  templateId: template.id,
                );
                final itemCountAfter =
                    (await repo.watchTripItems(tripId).first).length;
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.packingApplyTemplateApplied(
                        itemCountAfter - itemCountBefore,
                        template.name,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Add the overflow menu to `TripPackingTab`**

Add `appBar:` to the same `Scaffold` `build()` returns (Task 5 already put `floatingActionButton:` and `body:` there — the tab bar above this screen in `TripDetailScreen` covers navigation, but the "…" menu needs a home, so this screen gets its own transparent `AppBar` on top of that). Replace `build()` with:

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncItems = ref.watch(tripPackingItemsProvider(widget.trip.id));
    final hasItems = (asyncItems.valueOrNull ?? const []).isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'apply':
                  showApplyTemplateSheet(context, tripId: widget.trip.id);
                case 'manage':
                  // Wired in Task 9, once PackingTemplateManagerScreen
                  // exists (Task 7).
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'apply',
                child: Text(l10n.packingApplyTemplateAction),
              ),
              PopupMenuItem(
                value: 'manage',
                child: Text(l10n.packingManageTemplatesAction),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: hasItems
          ? FloatingActionButton(
              onPressed: () =>
                  showPackingItemFormSheet(context, tripId: widget.trip.id),
              child: const Icon(Icons.add),
            )
          : null,
      body: _body(context, l10n, asyncItems),
    );
  }
```

Add the import: `import 'apply_template_sheet.dart';`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/widget/packing/trip_packing_tab_test.dart`
Expected: PASS (11 tests)

- [ ] **Step 7: Commit**

```bash
git add lib/features/packing/presentation/apply_template_sheet.dart lib/features/packing/presentation/trip_packing_tab.dart lib/l10n/app_en.arb test/widget/packing/trip_packing_tab_test.dart
git commit -m "feat(packing): add apply-template picker sheet"
```

---

## Task 7: Template name dialog + template manager screen

**Files:**
- Create: `lib/features/packing/presentation/packing_template_name_dialog.dart`
- Create: `lib/features/packing/presentation/packing_template_manager_screen.dart`
- Test: `test/widget/packing/packing_template_manager_screen_test.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `packingTemplatesProvider`, `packingRepositoryProvider` (Task 4).
- Produces: `Future<String?> promptTemplateName(BuildContext, {required String title, required String confirmLabel, String initial})`; `class PackingTemplateManagerScreen extends ConsumerWidget` — list of templates (name only this round; item counts are shown once Task 8's editor exists, via `packingTemplateItemsProvider` — out of scope for this task's list row), tap opens `PackingTemplateEditorScreen` (Task 8, referenced but not yet implemented — this task's list row navigation is wired in Task 8 instead, since the editor screen doesn't exist yet). New template / rename / delete actions.

- [ ] **Step 1: Add ARB strings**

```json
  "packingTemplatesTitle": "Packing templates",
  "packingTemplatesEmptyTitle": "No templates yet",
  "packingTemplatesEmptyBody": "Build a reusable list once, then apply it to any trip.",
  "packingTemplatesEmptyCta": "New template",
  "newTemplateDialogTitle": "New template",
  "renameTemplateDialogTitle": "Rename template",
  "templateNameLabel": "Template name",
  "errTemplateNameRequired": "Enter a name for this template",
  "deleteTemplateTitle": "Delete this template?",
  "deleteTemplateBody": "This only removes the template — trips that already used it keep their packing list.",
  "templateDeleted": "Template deleted."
```

- [ ] **Step 2: Write the failing test**

```dart
// test/widget/packing/packing_template_manager_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/packing/presentation/packing_providers.dart';
import 'package:tripper/features/packing/presentation/packing_template_manager_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_packing_repository.dart';

Widget _app(FakePackingRepository repo) => ProviderScope(
      overrides: [packingRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PackingTemplateManagerScreen(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('empty state shown with no templates', (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No templates yet'), findsOneWidget);
  });

  testWidgets('creating a template adds it to the list', (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New template'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Template name'),
      'Beach trip',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Beach trip'), findsOneWidget);
  });

  testWidgets('renaming a template updates the list', (tester) async {
    final repo = FakePackingRepository();
    await repo.createTemplate(name: 'Beach trip');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Summer beach trip');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Summer beach trip'), findsOneWidget);
    expect(find.text('Beach trip'), findsNothing);
  });

  testWidgets('deleting a template asks for confirmation first',
      (tester) async {
    final repo = FakePackingRepository();
    await repo.createTemplate(name: 'Beach trip');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Beach trip'), findsOneWidget); // still there

    await tester.tap(find.text('Delete this template?').hitTestable().first);
    // Confirm button uses the shared delete label; tap the dialog's action.
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Beach trip'), findsNothing);
    expect(find.text('Template deleted.'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/packing/packing_template_manager_screen_test.dart`
Expected: FAIL — the screen and dialog don't exist yet.

- [ ] **Step 4: Implement the name dialog**

```dart
// lib/features/packing/presentation/packing_template_name_dialog.dart
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Shared "type a template name" dialog — used for both creating a new
/// template and renaming an existing one. Mirrors
/// `lib/features/places/presentation/list_name_dialog.dart`'s shape.
Future<String?> promptTemplateName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (context) => _TemplateNameDialog(
      controller: controller,
      title: title,
      confirmLabel: confirmLabel,
      cancelLabel: l10n.cancel,
      errorText: l10n.errTemplateNameRequired,
    ),
  );
}

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog({
    required this.controller,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.errorText,
  });

  final TextEditingController controller;
  final String title;
  final String confirmLabel;
  final String cancelLabel;
  final String errorText;

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  bool _showError = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: widget.controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.templateNameLabel,
          errorText: _showError ? widget.errorText : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }

  void _submit() {
    final name = widget.controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(name);
  }
}
```

- [ ] **Step 5: Implement the manager screen**

```dart
// lib/features/packing/presentation/packing_template_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_template.dart';
import 'packing_providers.dart';
import 'packing_template_name_dialog.dart';

class PackingTemplateManagerScreen extends ConsumerWidget {
  const PackingTemplateManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final templates = ref.watch(packingTemplatesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.packingTemplatesTitle)),
      floatingActionButton: templates.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _create(context, ref),
              child: const Icon(Icons.add),
            ),
      body: templates.isEmpty
          ? EmptyState(
              icon: Icons.checklist_outlined,
              title: l10n.packingTemplatesEmptyTitle,
              body: l10n.packingTemplatesEmptyBody,
              ctaLabel: l10n.packingTemplatesEmptyCta,
              onCta: () => _create(context, ref),
            )
          : ListView.separated(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              itemCount: templates.length,
              separatorBuilder: (context, i) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _row(context, ref, templates[i]),
            ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, PackingTemplate template) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      title: Text(template.name),
      onTap: () {
        // Opens PackingTemplateEditorScreen — wired in Task 8.
      },
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'rename':
              _rename(context, ref, template);
            case 'delete':
              _delete(context, ref, template);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'rename', child: Text(l10n.menuRename)),
          PopupMenuItem(value: 'delete', child: Text(l10n.menuDelete)),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptTemplateName(
      context,
      title: l10n.newTemplateDialogTitle,
      confirmLabel: l10n.save,
    );
    if (name == null) return;
    await ref.read(packingRepositoryProvider).createTemplate(name: name);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    PackingTemplate template,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptTemplateName(
      context,
      title: l10n.renameTemplateDialogTitle,
      confirmLabel: l10n.save,
      initial: template.name,
    );
    if (name == null) return;
    await ref
        .read(packingRepositoryProvider)
        .renameTemplate(template.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PackingTemplate template,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTemplateTitle),
        content: Text(l10n.deleteTemplateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.menuDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = ref.read(packingRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.deleteTemplate(template.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.templateDeleted)));
  }
}
```

**Note:** this reuses `l10n.menuRename`/`l10n.menuDelete` — check `lib/l10n/app_en.arb` for an existing `menuRename` key (the Trip menu only has `menuEdit`/`menuArchive`/`menuDelete` per `trip_detail_screen.dart`). If `menuRename` doesn't exist, add it: `"menuRename": "Rename"`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/widget/packing/packing_template_manager_screen_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 7: Commit**

```bash
git add lib/features/packing/presentation/packing_template_name_dialog.dart lib/features/packing/presentation/packing_template_manager_screen.dart lib/l10n/app_en.arb test/widget/packing/packing_template_manager_screen_test.dart
git commit -m "feat(packing): add the template manager screen"
```

---

## Task 8: Template editor screen (item CRUD within a template)

**Files:**
- Create: `lib/features/packing/presentation/packing_template_editor_screen.dart`
- Modify: `lib/features/packing/presentation/packing_item_form_sheet.dart`
- Modify: `lib/features/packing/presentation/packing_template_manager_screen.dart`
- Test: `test/widget/packing/packing_template_editor_screen_test.dart`

**Interfaces:**
- Consumes: `packingTemplateItemsProvider`, `packingRepositoryProvider.addTemplateItem`/`updateTemplateItem`/`deleteTemplateItem` (Tasks 3, 4); `PillChip`, `packingCategoryLabel`/`packingCategoryIcon` (Task 4).
- Produces: `class PackingTemplateEditorScreen extends ConsumerWidget({required String templateId})`; extends `showPackingItemFormSheet` (Task 5) to also handle template items via a new optional `templateId` parameter (mutually exclusive with `tripId` — exactly one is passed).

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/packing/packing_template_editor_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/presentation/packing_providers.dart';
import 'package:tripper/features/packing/presentation/packing_template_editor_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_packing_repository.dart';

Future<Widget> _app(FakePackingRepository repo, String templateId) async =>
    ProviderScope(
      overrides: [packingRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: PackingTemplateEditorScreen(templateId: templateId),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('items render grouped by category', (tester) async {
    final repo = FakePackingRepository();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await tester.pumpWidget(await _app(repo, templateId));
    await tester.pumpAndSettle();

    expect(find.text('CLOTHING'), findsOneWidget);
    expect(find.text('Swimsuit'), findsOneWidget);
  });

  testWidgets('adding an item via the FAB appears in its category',
      (tester) async {
    final repo = FakePackingRepository();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await tester.pumpWidget(await _app(repo, templateId));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.enterText(find.widgetWithText(TextField, 'Item'), 'Passport');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Passport'), findsOneWidget);
  });

  testWidgets('deleting an item removes it', (tester) async {
    final repo = FakePackingRepository();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await tester.pumpWidget(await _app(repo, templateId));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Swimsuit'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/packing/packing_template_editor_screen_test.dart`
Expected: FAIL — `PackingTemplateEditorScreen` doesn't exist yet.

- [ ] **Step 3: Extend the item form sheet to handle template items**

Task 3's `updateTemplateItem(PackingTemplateItem item)` writes whatever `sortOrder` is on the passed-in item straight through — it doesn't re-fetch. So editing a template item must pass the full existing `PackingTemplateItem` back in (to preserve its `sortOrder`), while editing a trip item only ever needed a label (Task 5's `updateTripItemLabel(id, label)` already preserves everything else server-side). Rather than two different edit shapes, `packing_item_form_sheet.dart` takes an optional full `PackingTemplateItem` for the template-edit case specifically. Replace the file's contents with:

```dart
// lib/features/packing/presentation/packing_item_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_category.dart';
import '../domain/packing_template.dart';
import 'packing_providers.dart';
import 'packing_widgets.dart';

/// Adds or edits a packing item, on either a trip or a template — exactly
/// one of [tripId]/[templateId] must be non-null.
///
/// For a **trip** item, [existingId] + [existingLabel] are enough to edit
/// (label-only; category can't change after creation — see the class doc
/// below). For a **template** item, pass [existingTemplateItem] instead:
/// its `sortOrder` must round-trip through the edit because
/// [PackingRepository.updateTemplateItem] writes it straight through
/// rather than re-fetching it.
Future<void> showPackingItemFormSheet(
  BuildContext context, {
  String? tripId,
  String? templateId,
  String? existingId,
  String? existingLabel,
  PackingCategory? existingCategory,
  PackingTemplateItem? existingTemplateItem,
}) {
  assert((tripId == null) != (templateId == null));
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ItemForm(
        tripId: tripId,
        templateId: templateId,
        existingId: existingId,
        existingLabel: existingLabel ?? existingTemplateItem?.label,
        existingCategory: existingCategory ?? existingTemplateItem?.category,
        existingTemplateItem: existingTemplateItem,
      ),
    ),
  );
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({
    this.tripId,
    this.templateId,
    this.existingId,
    this.existingLabel,
    this.existingCategory,
    this.existingTemplateItem,
  });

  final String? tripId;
  final String? templateId;
  final String? existingId;
  final String? existingLabel;
  final PackingCategory? existingCategory;
  final PackingTemplateItem? existingTemplateItem;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  late final TextEditingController _label;
  late PackingCategory _category;
  bool _labelError = false;
  bool _saving = false;

  bool get _isEdit => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existingLabel ?? '');
    _category = widget.existingCategory ?? PackingCategory.clothing;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Text(
          _isEdit ? l10n.packingItemFormEditTitle : l10n.packingItemFormAddTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _label,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.packingItemFormLabel,
            errorText: _labelError ? l10n.errPackingLabelRequired : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_isEdit) ...[
          Text(l10n.packingItemFormCategory),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in PackingCategory.values)
                PillChip(
                  label: packingCategoryLabel(l10n, c),
                  icon: packingCategoryIcon(c),
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    setState(() => _labelError = label.isEmpty);
    if (label.isEmpty) return;

    setState(() => _saving = true);
    final repo = ref.read(packingRepositoryProvider);
    final existingId = widget.existingId;
    final tripId = widget.tripId;
    final templateId = widget.templateId;
    final existingTemplateItem = widget.existingTemplateItem;

    if (existingId != null && tripId != null) {
      await repo.updateTripItemLabel(existingId, label);
    } else if (existingTemplateItem != null) {
      await repo.updateTemplateItem(existingTemplateItem.copyWith(label: label));
    } else if (tripId != null) {
      await repo.addTripItem(tripId: tripId, category: _category, label: label);
    } else {
      await repo.addTemplateItem(
        templateId: templateId!,
        category: _category,
        label: label,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
```

- [ ] **Step 4: Implement the editor screen**

```dart
// lib/features/packing/presentation/packing_template_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_category.dart';
import '../domain/packing_template.dart';
import 'packing_item_form_sheet.dart';
import 'packing_providers.dart';
import 'packing_widgets.dart';

class PackingTemplateEditorScreen extends ConsumerWidget {
  const PackingTemplateEditorScreen({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final templates = ref.watch(packingTemplatesProvider).valueOrNull ?? const [];
    final template = templates.where((t) => t.id == templateId).firstOrNull;
    final items =
        ref.watch(packingTemplateItemsProvider(templateId)).valueOrNull ??
            const [];

    return Scaffold(
      appBar: AppBar(title: Text(template?.name ?? '')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showPackingItemFormSheet(context, templateId: templateId),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.checklist_outlined,
              title: l10n.packingEmptyTitle,
              body: l10n.packingEmptyBody,
              ctaLabel: l10n.packingEmptyCta,
              onCta: () =>
                  showPackingItemFormSheet(context, templateId: templateId),
            )
          : _list(context, ref, items),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<PackingTemplateItem> items,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final byCategory = <PackingCategory, List<PackingTemplateItem>>{};
    for (final item in items) {
      (byCategory[item.category] ??= []).add(item);
    }
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        for (final category in PackingCategory.values)
          if (byCategory[category] case final categoryItems?
              when categoryItems.isNotEmpty) ...[
            SectionLabel(packingCategoryLabel(l10n, category)),
            const SizedBox(height: AppSpacing.sm),
            for (final item in categoryItems) ...[
              PaperCard(
                onTap: () => showPackingItemFormSheet(
                  context,
                  templateId: templateId,
                  existingId: item.id,
                  existingTemplateItem: item,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => ref
                          .read(packingRepositoryProvider)
                          .deleteTemplateItem(item.id),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}
```

- [ ] **Step 5: Wire navigation from the template manager screen**

In `packing_template_manager_screen.dart`, replace the `_row` method's empty `onTap` body with:

```dart
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              PackingTemplateEditorScreen(templateId: template.id),
        ),
      ),
```

Add the import: `import 'packing_template_editor_screen.dart';`.

- [ ] **Step 6: Run tests to verify everything passes**

Run: `flutter test test/widget/packing/`
Expected: PASS (all packing widget tests, including Task 4-7's suites still passing after the shared form sheet's signature change).

- [ ] **Step 7: Commit**

```bash
git add lib/features/packing/presentation/packing_template_editor_screen.dart lib/features/packing/presentation/packing_item_form_sheet.dart lib/features/packing/presentation/packing_template_manager_screen.dart test/widget/packing/packing_template_editor_screen_test.dart
git commit -m "feat(packing): add the template editor screen"
```

---

## Task 9: Wire the Packing tab into TripDetailScreen

**Files:**
- Modify: `lib/features/trips/presentation/trip_detail_screen.dart`
- Modify: `test/widget/trips/trip_detail_screen_test.dart`
- Modify: `lib/features/packing/presentation/trip_packing_tab.dart`

**Interfaces:**
- Consumes: `TripPackingTab` (Task 5), `PackingTemplateManagerScreen` (Task 7), `FakePackingRepository` (Task 4).
- Produces: `TripDetailScreen` with 5 tabs (Documents, Places, Spend, Journal, Packing); `TripPackingTab`'s overflow menu's "Manage templates…" action now actually navigates.

- [ ] **Step 1: Write the failing test changes**

In `test/widget/trips/trip_detail_screen_test.dart`:

Add imports:

```dart
import 'package:tripper/features/packing/presentation/packing_providers.dart';

import '../../helpers/fake_packing_repository.dart';
```

Add to `_app`'s overrides list:

```dart
        packingRepositoryProvider.overrideWithValue(FakePackingRepository()),
```

Update the tab-count test:

```dart
  testWidgets(
      'the withdrawn Plan tab stays gone, and Packing is the new fifth tab',
      (tester) async {
    final trip = _trip(
      start: DateTime(2026, 7, 16),
      end: DateTime(2026, 7, 27),
    );
    await tester.pumpWidget(await _app(trip));
    await tester.pumpAndSettle();

    expect(find.byType(Tab), findsNWidgets(5));
    expect(find.text('Plan'), findsNothing);
    expect(find.text('Packing'), findsOneWidget);
  });
```

Update the "all tabs reachable" test to include Packing:

```dart
  testWidgets('all five tabs are reachable from an active trip',
      (tester) async {
    final trip = _trip(
      start: DateTime(2026, 7, 16),
      end: DateTime(2026, 7, 27),
    );
    await tester.pumpWidget(await _app(trip));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    expectTabShowing('No documents linked');

    for (final tab in ['Places', 'Journal', 'Packing']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }

    await tester.tap(find.text('Spend'));
    await tester.pumpAndSettle();
    expectTabShowing('Track what this trip costs');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/trips/trip_detail_screen_test.dart`
Expected: FAIL — still 4 tabs, no "Packing" tab or label.

- [ ] **Step 3: Wire the tab into `trip_detail_screen.dart`**

Add the import: `import '../../packing/presentation/trip_packing_tab.dart';`

Update the doc comment and constant:

```dart
/// Tab order is Documents, Places, Spend, Journal, Packing — keep these
/// in sync with the `tabs:`/`TabBarView` children below.
///
/// A "Plan" tab (the day-by-day itinerary) lived in this fourth slot until
/// 2026-07-26 and was withdrawn as "currently won't do"; see
/// `docs/adr/ADR-001-itinerary-redesign.md`. Journal is unrelated new work
/// that happens to reuse the freed slot. Packing (2026-08-22) is a new
/// fifth tab, not a slot reuse.
const _tabCount = 5;
const _expensesTabIndex = 2;
```

Add a `tabPacking` ARB key: `"tabPacking": "Packing"` — **already added in Task 4, Step 1**; skip if present.

Add the tab and view:

```dart
                        tabs: [
                          Tab(text: l10n.tabDocuments),
                          Tab(text: l10n.tabPlacesInTrip),
                          Tab(text: l10n.tabExpenses),
                          Tab(text: l10n.tabJournal),
                          Tab(text: l10n.tabPacking),
                        ],
```

```dart
                  children: [
                    TripDocumentsTab(trip: trip),
                    TripPlacesTab(trip: trip),
                    TripExpensesTab(trip: trip),
                    TripJournalTab(trip: trip),
                    TripPackingTab(trip: trip),
                  ],
```

- [ ] **Step 4: Wire "Manage templates…" to actually navigate**

In `trip_packing_tab.dart`, replace the `case 'manage': break;` placeholder from Task 6 with:

```dart
                case 'manage':
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          const PackingTemplateManagerScreen(),
                    ),
                  );
```

Add the import: `import 'packing_template_manager_screen.dart';`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/widget/trips/trip_detail_screen_test.dart`
Expected: PASS (7 tests)

Run: `flutter test` (full suite)
Expected: PASS — no regressions elsewhere.

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/presentation/trip_detail_screen.dart lib/features/packing/presentation/trip_packing_tab.dart test/widget/trips/trip_detail_screen_test.dart
git commit -m "feat(packing): wire the Packing tab into TripDetailScreen"
```

---

## Self-Review Notes

- **Spec coverage:** data model (Task 2-3) ✅, trip tab with category grouping/checkbox/status menu (Task 4) ✅, add/edit items (Task 5) ✅, apply-template append semantics (Task 6) ✅, template manager (Task 7) ✅, template editor (Task 8) ✅, TripDetailScreen wiring with the doc-comment/tab-count update (Task 9) ✅, migration test (Task 2) ✅, repository-boundary mocking throughout (Tasks 4-9 use `FakePackingRepository`, never a real `AppDatabase`) ✅.
- **Type consistency:** `PackingRepository`'s method names/signatures introduced in Task 3 are used identically in Tasks 4-9 (`addTripItem`, `updateTripItemStatus`, `applyTemplate`, etc.) and in `FakePackingRepository` (Task 4) — checked against each call site above. `showPackingItemFormSheet`'s signature grows once, in Task 8, to add template support (`templateId`, `existingTemplateItem`); Task 8 gives that file's full final contents rather than a diff, so there's one unambiguous version to implement.
- **Placeholder scan:** no TBD/TODO markers or narrated-but-uncoded fixes remain — every step above shows the actual code to write.

## Verification

Flutter can't run in this sandbox — the implementer runs `flutter analyze && flutter test` locally (or pushes and lets CI run it) after each task, and after Task 9 runs the full suite once more to confirm no cross-feature regressions (especially `test/widget/trips/trip_detail_screen_test.dart` and anything touching `app_database.dart`'s migration chain).
