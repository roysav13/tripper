# Place feature improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give places a category, let the Places lists (aggregate and
per-trip) be filtered by category and country, expose the existing hidden
`notes` field as an editable "Description" plus a generated Google Maps
link, and fix a stats-header alignment bug.

**Architecture:** `PlaceCategory` is a new nullable-indexed enum column
(schema v11→v12, migration test required). Filtering is a pure domain
function (`filterPlaces`) plus a controlled, stateless `PlaceFilterBar`
widget — filter *state* lives in the two screens that use it (converted to
`ConsumerStatefulWidget`, same pattern the Spend tab already established
for local UI state), not in a new Riverpod provider. The Google Maps link
is generated on the fly from existing `lat`/`lng` — no new stored field —
using a new `url_launcher` dependency.

**Tech Stack:** Flutter/Dart, Riverpod, Drift (migration), `url_launcher`
(new dependency).

## Global Constraints

(From `CLAUDE.md` and `docs/superpowers/specs/2026-08-10-place-improvements-design.md`.)

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`.
- No `DateTime.now()` in domain code.
- Every user-facing string goes through ARB (`lib/l10n/app_en.arb`).
- Every Drift schema bump ships a migration test in the same commit.
  `createTable` always builds a table at its *current* definition, so a
  version's `createTable` step and a later version's `addColumn` on the
  *same table* are mutually exclusive (`if` / `else if`, never two
  separate `if`s) — getting this wrong crashes ("duplicate column name")
  for anyone upgrading across two or more versions at once. See
  `lib/core/database/app_database.dart`'s existing comment on this exact
  failure mode, and `test/unit/expenses/expenses_migration_test.dart`'s
  multi-version-jump test for the established pattern to mirror.
- Widget tests mock at the repository boundary (`FakePlaceRepository`).
- Resolve every `ref`/`context`-derived object *before* the next `await`,
  never after — this file (`place_actions_sheet.dart`) already follows
  this convention; new code must too.
- `EdgeInsetsDirectional`/RTL-safe layout; `SectionLabel`/`MonoText`/
  `PaperCard` primitives, not ad-hoc styling.
- One category per place (not multiple tags) — matches the existing
  `ExpenseCategory`/`DocumentCategory` single-category convention.
- `PlaceStatsHeader`'s numbers stay **unfiltered** — it's a whole-trip
  trophy case ("countries visited," "places visited"), not a view into
  the currently-filtered list. Only the want/been rows and the map view
  respond to the filter.

---

### Task 1: Category domain model + database migration (TDD)

**Files:**
- Modify: `lib/features/places/domain/place.dart`
- Modify: `lib/features/places/data/place_tables.dart`
- Modify: `lib/core/database/app_database.dart`
- Modify: `lib/features/places/data/place_repository.dart`
- Test: Create `test/unit/places/places_migration_test.dart`
- Test: Modify `test/unit/places/place_domain_test.dart`

**Interfaces:**
- Produces: `PlaceCategory` enum (12 values, append-only, stored as index);
  `Place.category` (`PlaceCategory?`, nullable = uncategorized);
  `PlaceRepository.createPlace(..., PlaceCategory? category)`. Consumed by
  Task 2 (forms), Task 3 (`filterPlaces`).

- [ ] **Step 1: Write the failing migration test**

Create `test/unit/places/places_migration_test.dart`:

```dart
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

  test(
      'v11 -> v12 adds the category column to an existing table, null '
      '(= uncategorized), keeping existing rows', () async {
    await db.customStatement('DROP TABLE places');
    await db.customStatement(createV11Places);
    await db.customStatement(insertTrip);
    await db.customStatement(
      "INSERT INTO places (id, name, country, city, status, notes, "
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
    await db.customStatement(insertTrip);

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 4, 12),
      completes,
    );
    // The freshly created table already has the v12 shape.
    await db.customSelect('SELECT category FROM places').get();
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/unit/places/places_migration_test.dart`
Expected: FAIL — `schemaVersion` is still 11, no `category` column exists.

- [ ] **Step 3: Add the enum and field to the domain model**

In `lib/features/places/domain/place.dart`, add the enum after
`PlaceStatus`:

```dart
/// Order is stable — stored as index in the DB. Append only.
enum PlaceCategory {
  hotel,
  restaurant,
  coffeeShop,
  bar,
  attraction,
  museum,
  amusementPark,
  trek,
  beach,
  shopping,
  nature,
  other,
}
```

Add `category` to `Place`: constructor param, field, `copyWith`,
`operator ==`, `hashCode`:

```dart
class Place {
  const Place({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.country = '',
    this.city = '',
    this.status = PlaceStatus.wantToGo,
    this.visitedAt,
    this.tripId,
    this.notes = '',
    this.category,
  });

  final String id;
  final String name;
  final double? lat;
  final double? lng;
  final String country;
  final String city;
  final PlaceStatus status;
  final DateTime? visitedAt;
  final String? tripId;
  final String notes;

  /// Null = uncategorized — every place that existed before this field
  /// shipped has no category, and that's a real, distinct state from
  /// "Other" (defaulting old rows to "Other" would invent a fact nobody
  /// entered).
  final PlaceCategory? category;

  bool get isVisited => status == PlaceStatus.beenThere;
  bool get hasLocation => lat != null && lng != null;

  Place copyWith({
    String? name,
    double? Function()? lat,
    double? Function()? lng,
    String? country,
    String? city,
    PlaceStatus? status,
    DateTime? Function()? visitedAt,
    String? Function()? tripId,
    String? notes,
    PlaceCategory? Function()? category,
  }) {
    return Place(
      id: id,
      name: name ?? this.name,
      lat: lat == null ? this.lat : lat(),
      lng: lng == null ? this.lng : lng(),
      country: country ?? this.country,
      city: city ?? this.city,
      status: status ?? this.status,
      visitedAt: visitedAt == null ? this.visitedAt : visitedAt(),
      tripId: tripId == null ? this.tripId : tripId(),
      notes: notes ?? this.notes,
      category: category == null ? this.category : category(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.id == id &&
      other.name == name &&
      other.lat == lat &&
      other.lng == lng &&
      other.country == country &&
      other.city == city &&
      other.status == status &&
      other.visitedAt == visitedAt &&
      other.tripId == tripId &&
      other.notes == notes &&
      other.category == category;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        lat,
        lng,
        country,
        city,
        status,
        visitedAt,
        tripId,
        notes,
        category,
      );
}
```

(`sortForList` and `visitedStats` are unchanged — leave them exactly as
they are.)

- [ ] **Step 4: Add the column to the Drift table**

In `lib/features/places/data/place_tables.dart`, add after `createdAt`:

```dart
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  /// Index into PlaceCategory enum; null = uncategorized (existing rows,
  /// or a place the user hasn't categorized yet).
  IntColumn get category => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
```

- [ ] **Step 5: Add the migration step**

In `lib/core/database/app_database.dart`:

1. Update the schema-history doc comment, adding a v12 line after v11.
2. `schemaVersion` 11 → 12.
3. Find the existing places block:
   ```dart
   if (from < 5) {
     await m.createTable(places);
   }
   ```
   Replace with (this is the critical part — `createTable` at v5 already
   builds the table at its *current*, v12 shape, so the `addColumn` step
   below must only run for installs that already had the table *before*
   v12, i.e. `else if`, never a second independent `if`):
   ```dart
   if (from < 5) {
     await m.createTable(places);
   } else if (from < 12) {
     await m.addColumn(places, places.category);
   }
   ```

- [ ] **Step 6: Run the migration test to verify it passes**

Run: `flutter test test/unit/places/places_migration_test.dart`
Expected: PASS, both cases.

- [ ] **Step 7: Wire category through the repository**

In `lib/features/places/data/place_repository.dart`:

`PlaceRepository.createPlace`'s signature gains `PlaceCategory? category`:
```dart
  Future<String> createPlace({
    required String name,
    String country,
    String city,
    double? lat,
    double? lng,
    String? tripId,
    String notes,
    PlaceCategory? category,
  });
```

`DriftPlaceRepository.createPlace`:
```dart
  @override
  Future<String> createPlace({
    required String name,
    String country = '',
    String city = '',
    double? lat,
    double? lng,
    String? tripId,
    String notes = '',
    PlaceCategory? category,
  }) async {
    final id = _uuid.v4();
    await _dao.insertPlace(
      PlaceRow(
        id: id,
        name: name.trim(),
        lat: lat,
        lng: lng,
        country: country.trim(),
        city: city.trim(),
        status: PlaceStatus.wantToGo.index,
        visitedAt: null,
        tripId: tripId,
        notes: notes.trim(),
        createdAt: _clock(),
        category: category?.index,
      ),
    );
    return id;
  }
```

`DriftPlaceRepository.updatePlace` — add `category: Value(place.category?.index),`
to the `existing.copyWith(...)` call.

`DriftPlaceRepository._toDomain` — add:
```dart
        category:
            row.category == null ? null : PlaceCategory.values[row.category!],
```
to the returned `Place(...)`.

- [ ] **Step 8: Add a domain-model test for category round-tripping**

In `test/unit/places/place_domain_test.dart`, add (near the existing
tests, same file, same style):

```dart
  group('Place category', () {
    test('copyWith sets and clears category', () {
      const place = Place(id: 'p1', name: 'Test');
      expect(place.category, isNull);

      final categorized =
          place.copyWith(category: () => PlaceCategory.restaurant);
      expect(categorized.category, PlaceCategory.restaurant);

      final cleared = categorized.copyWith(category: () => null);
      expect(cleared.category, isNull);
    });

    test('equality includes category', () {
      const a = Place(id: 'p1', name: 'Test', category: PlaceCategory.hotel);
      const b = Place(id: 'p1', name: 'Test', category: PlaceCategory.hotel);
      const c = Place(id: 'p1', name: 'Test', category: PlaceCategory.trek);
      expect(a, b);
      expect(a, isNot(c));
    });
  });
```
(add `import 'package:tripper/features/places/domain/place.dart';` — this
import already exists in the file, no change needed there.)

- [ ] **Step 9: Run the full places unit suite and analyze**

Run: `flutter test test/unit/places/`
Expected: PASS, all cases.

Run: `flutter analyze lib/features/places/ lib/core/database/app_database.dart test/unit/places/`
Expected: No issues found.

- [ ] **Step 10: Commit**

```bash
git add lib/features/places/domain/place.dart lib/features/places/data/place_tables.dart lib/core/database/app_database.dart lib/features/places/data/place_repository.dart test/unit/places/places_migration_test.dart test/unit/places/place_domain_test.dart
git commit -m "feat(places): add PlaceCategory, schema v12 migration"
```

---

### Task 2: Category icon/label + category & description fields in add/edit forms

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/features/places/presentation/place_widgets.dart`
- Modify: `lib/features/places/presentation/add_place_screen.dart`
- Modify: `lib/features/places/presentation/place_actions_sheet.dart`
- Test: Modify `test/widget/places/add_place_screen_test.dart`
- Test: Modify `test/widget/places/place_actions_test.dart`

**Interfaces:**
- Consumes: `PlaceCategory`, `Place.category` (Task 1).
- Produces: `placeCategoryIcon(PlaceCategory)`, `placeCategoryLabel(AppLocalizations, PlaceCategory)` — consumed by Task 3's `PlaceFilterBar`.

- [ ] **Step 1: Write the failing tests**

In `test/widget/places/add_place_screen_test.dart`, add a test exercising
the new category chips and description field (adapt to however that
file's existing tests drive the save card — read the file first; the
shape below matches this plan's other examples but the exact widget-finder
setup must match what's already established there):

```dart
  testWidgets('picking a category and typing a description saves both',
      (tester) async {
    final repo = FakePlaceRepository([]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Drive the existing search-or-manual-add flow to reach the save card
    // (mirror however the existing tests in this file get there), then:
    await tester.enterText(find.byType(TextField).last, 'A description');
    await tester.tap(find.text('Restaurant'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repo.watchAll().first).single;
    expect(saved.category, PlaceCategory.restaurant);
    expect(saved.notes, 'A description');
  });
```

In `test/widget/places/place_actions_test.dart`, add:

```dart
  testWidgets('editing sets a category and a description', (tester) async {
    final repo = FakePlaceRepository([_place]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attraction'));
    await tester.enterText(find.byType(TextField).last, 'Great sunset spot');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repo.watchAll().first).single;
    expect(saved.category, PlaceCategory.attraction);
    expect(saved.notes, 'Great sunset spot');
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/widget/places/add_place_screen_test.dart test/widget/places/place_actions_test.dart`
Expected: FAIL — no category chips or description field exist yet.

- [ ] **Step 3: Add the ARB strings**

In `lib/l10n/app_en.arb`, add near `placeFormTrip`:

```json
  "placeFormDescription": "Description",
  "catHotel": "Hotel",
  "catRestaurant": "Restaurant",
  "catCoffeeShop": "Coffee Shop",
  "catBar": "Bar",
  "catAttraction": "Attraction",
  "catMuseum": "Museum",
  "catAmusementPark": "Amusement Park",
  "catTrek": "Trek",
  "catBeach": "Beach",
  "catNature": "Nature",
```
(`catShopping` and `catOther` already exist from Expense/Document
categories — reused, not duplicated.)

- [ ] **Step 4: Add category icon/label helpers**

In `lib/features/places/presentation/place_widgets.dart`, add near the top
(after imports, before `PlaceRowCard`):

```dart
IconData placeCategoryIcon(PlaceCategory category) => switch (category) {
      PlaceCategory.hotel => Icons.hotel_outlined,
      PlaceCategory.restaurant => Icons.restaurant_outlined,
      PlaceCategory.coffeeShop => Icons.local_cafe_outlined,
      PlaceCategory.bar => Icons.local_bar_outlined,
      PlaceCategory.attraction => Icons.local_activity_outlined,
      PlaceCategory.museum => Icons.museum_outlined,
      PlaceCategory.amusementPark => Icons.attractions_outlined,
      PlaceCategory.trek => Icons.hiking_outlined,
      PlaceCategory.beach => Icons.beach_access_outlined,
      PlaceCategory.shopping => Icons.shopping_bag_outlined,
      PlaceCategory.nature => Icons.park_outlined,
      PlaceCategory.other => Icons.category_outlined,
    };

String placeCategoryLabel(AppLocalizations l10n, PlaceCategory category) =>
    switch (category) {
      PlaceCategory.hotel => l10n.catHotel,
      PlaceCategory.restaurant => l10n.catRestaurant,
      PlaceCategory.coffeeShop => l10n.catCoffeeShop,
      PlaceCategory.bar => l10n.catBar,
      PlaceCategory.attraction => l10n.catAttraction,
      PlaceCategory.museum => l10n.catMuseum,
      PlaceCategory.amusementPark => l10n.catAmusementPark,
      PlaceCategory.trek => l10n.catTrek,
      PlaceCategory.beach => l10n.catBeach,
      // Reuses Expense's category strings where the word is identical —
      // one translation to maintain, not two.
      PlaceCategory.shopping => l10n.catShopping,
      PlaceCategory.nature => l10n.catNature,
      PlaceCategory.other => l10n.catOther,
    };
```

- [ ] **Step 5: Wire category + description into `AddPlaceScreen`**

In `lib/features/places/presentation/add_place_screen.dart`:

Add imports: `import '../domain/place.dart';` and `import 'place_widgets.dart';`.

Replace the `_notes` field and its two use sites:
```dart
  String _notes = '';
```
becomes:
```dart
  final _description = TextEditingController();
  PlaceCategory? _category;
```

In `initState`, replace `_notes = widget.initialNotes ?? '';` with
`_description.text = widget.initialNotes ?? '';`.

In `dispose`, add `_description.dispose();` alongside the other controller
disposals.

In `_saveCard`, insert this block right after the trip `ChoiceChip` `if
(trips.isNotEmpty) ...` block and before the final `Row` (Save/Cancel):
```dart
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final category in PlaceCategory.values)
                ChoiceChip(
                  avatar: Icon(placeCategoryIcon(category), size: 16),
                  label: Text(placeCategoryLabel(l10n, category)),
                  selected: _category == category,
                  onSelected: (_) => setState(
                    () => _category = _category == category ? null : category,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _description,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.placeFormDescription,
              isDense: true,
            ),
          ),
```

In `_save()`, change `notes: _notes` to `notes: _description.text` and add
`category: _category,` to the `createPlace(...)` call.

- [ ] **Step 6: Wire category + description into `_EditPlaceForm`**

In `lib/features/places/presentation/place_actions_sheet.dart`, add import
`import 'place_widgets.dart';`.

In `_EditPlaceFormState`, add fields:
```dart
  final _description = TextEditingController();
  PlaceCategory? _category;
```

In `initState`, add:
```dart
    _description.text = widget.place.notes;
    _category = widget.place.category;
```

In `dispose`, add `_description.dispose();`.

In `build`, insert this block right after the City/Country `Row` and
before the `if (trips.isNotEmpty) ...` trip-chips block:
```dart
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final category in PlaceCategory.values)
              ChoiceChip(
                avatar: Icon(placeCategoryIcon(category), size: 16),
                label: Text(placeCategoryLabel(l10n, category)),
                selected: _category == category,
                onSelected: (_) => setState(
                  () => _category = _category == category ? null : category,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _description,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.placeFormDescription),
        ),
```

In `_save()`, add `category: () => _category, notes: _description.text,` to
the `widget.place.copyWith(...)` call.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/widget/places/add_place_screen_test.dart test/widget/places/place_actions_test.dart`
Expected: PASS, all cases (existing + new).

- [ ] **Step 8: Run analyze**

Run: `flutter analyze lib/features/places/presentation/ test/widget/places/`
Expected: No issues found.

- [ ] **Step 9: Regenerate localizations and commit**

```bash
flutter gen-l10n
git add lib/l10n/app_en.arb lib/l10n/app_localizations*.dart lib/features/places/presentation/place_widgets.dart lib/features/places/presentation/add_place_screen.dart lib/features/places/presentation/place_actions_sheet.dart test/widget/places/add_place_screen_test.dart test/widget/places/place_actions_test.dart
git commit -m "feat(places): category picker and description field in add/edit forms"
```

---

### Task 3: Filtering by category and country (both Places screens)

**Files:**
- Modify: `lib/features/places/domain/place.dart`
- Modify: `lib/features/places/presentation/place_widgets.dart`
- Modify: `lib/features/places/presentation/places_screen.dart`
- Modify: `lib/features/places/presentation/trip_places_tab.dart`
- Test: Modify `test/unit/places/place_domain_test.dart`
- Test: Modify `test/widget/places/places_screen_test.dart`
- Test: Create `test/widget/places/trip_places_tab_test.dart`

**Interfaces:**
- Consumes: `PlaceCategory`, `placeCategoryIcon`/`placeCategoryLabel` (Tasks 1-2).
- Produces: `filterPlaces(List<Place>, {Set<PlaceCategory> categories, Set<String> countries})`, `PlaceFilterBar` widget — both consumed only within this task's own two screens.

- [ ] **Step 1: Write the failing domain test**

In `test/unit/places/place_domain_test.dart`, add:

```dart
  group('filterPlaces', () {
    final places = [
      const Place(id: 'a', name: 'A', country: 'Thailand', category: PlaceCategory.hotel),
      const Place(id: 'b', name: 'B', country: 'Thailand', category: PlaceCategory.restaurant),
      const Place(id: 'c', name: 'C', country: 'Japan', category: PlaceCategory.hotel),
      const Place(id: 'd', name: 'D', country: 'Japan', category: null),
    ];

    test('no filters returns everything', () {
      expect(filterPlaces(places), hasLength(4));
    });

    test('category filter is OR within the set', () {
      final result = filterPlaces(
        places,
        categories: {PlaceCategory.hotel, PlaceCategory.restaurant},
      );
      expect(result.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('country filter is OR within the set', () {
      final result = filterPlaces(places, countries: {'Japan'});
      expect(result.map((p) => p.id), ['c', 'd']);
    });

    test('category and country filters combine with AND', () {
      final result = filterPlaces(
        places,
        categories: {PlaceCategory.hotel},
        countries: {'Japan'},
      );
      expect(result.map((p) => p.id), ['c']);
    });

    test('an uncategorized place never matches an active category filter',
        () {
      final result = filterPlaces(places, categories: {PlaceCategory.hotel});
      expect(result.any((p) => p.id == 'd'), isFalse);
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/unit/places/place_domain_test.dart`
Expected: FAIL — `filterPlaces` doesn't exist yet.

- [ ] **Step 3: Implement `filterPlaces`**

In `lib/features/places/domain/place.dart`, add after `visitedStats`:

```dart
/// Places matching the filter: AND across the two dimensions, OR within
/// each (an empty set for a dimension means that dimension doesn't
/// filter at all). Pure — unit-tested without widgets.
List<Place> filterPlaces(
  List<Place> places, {
  Set<PlaceCategory> categories = const {},
  Set<String> countries = const {},
}) {
  return [
    for (final p in places)
      if ((categories.isEmpty ||
              (p.category != null && categories.contains(p.category))) &&
          (countries.isEmpty || countries.contains(p.country)))
        p,
  ];
}
```

- [ ] **Step 4: Run the domain test to verify it passes**

Run: `flutter test test/unit/places/place_domain_test.dart`
Expected: PASS, all cases.

- [ ] **Step 5: Write the failing widget tests**

In `test/widget/places/places_screen_test.dart`, add (adapt fixture setup
to the file's existing `_app`/`_place`-style helpers):

```dart
  testWidgets('category filter narrows the visible list', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', category: PlaceCategory.hotel),
      const Place(id: 'b', name: 'Cafe B', category: PlaceCategory.coffeeShop),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);

    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);
  });

  testWidgets('country filter narrows the visible list', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Thai spot', country: 'Thailand'),
      const Place(id: 'b', name: 'Japan spot', country: 'Japan'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Japan'));
    await tester.pumpAndSettle();

    expect(find.text('Thai spot'), findsNothing);
    expect(find.text('Japan spot'), findsOneWidget);
  });
```

Create `test/widget/places/trip_places_tab_test.dart` — mirror the
`_app`/fixture style already established in
`test/widget/expenses/trip_expenses_tab_test.dart` (a `ProviderScope` with
`placeRepositoryProvider`/`clockProvider` overridden, `home:
Scaffold(body: TripPlacesTab(trip: _trip))`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/places/presentation/trip_places_tab.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_repository.dart';

const _trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

Widget _app(FakePlaceRepository repo) => ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TripPlacesTab(trip: _trip)),
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
  testWidgets('category filter narrows this trip\'s visible list',
      (tester) async {
    final repo = FakePlaceRepository([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        category: PlaceCategory.hotel,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
        tripId: 't1',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);

    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);
  });
}
```

- [ ] **Step 6: Run to verify they fail**

Run: `flutter test test/widget/places/places_screen_test.dart test/widget/places/trip_places_tab_test.dart`
Expected: FAIL — no filter chips exist yet.

- [ ] **Step 7: Add `PlaceFilterBar`**

In `lib/features/places/presentation/place_widgets.dart`, add (after the
category helpers from Task 2, before `PlaceRowCard`):

```dart
/// Category + country filter chips — a controlled widget, all state lives
/// in the parent screen. Only categories/countries actually present in
/// [places] render a chip, so there's never a dead-end filter option.
class PlaceFilterBar extends StatelessWidget {
  const PlaceFilterBar({
    super.key,
    required this.places,
    required this.selectedCategories,
    required this.selectedCountries,
    required this.onCategoriesChanged,
    required this.onCountriesChanged,
  });

  final List<Place> places;
  final Set<PlaceCategory> selectedCategories;
  final Set<String> selectedCountries;
  final ValueChanged<Set<PlaceCategory>> onCategoriesChanged;
  final ValueChanged<Set<String>> onCountriesChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = {
      for (final p in places)
        if (p.category != null) p.category!,
    }.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final countries = {
      for (final p in places)
        if (p.country.trim().isNotEmpty) p.country,
    }.toList()
      ..sort();

    if (categories.isEmpty && countries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final category in categories)
                FilterChip(
                  avatar: Icon(placeCategoryIcon(category), size: 16),
                  label: Text(placeCategoryLabel(l10n, category)),
                  selected: selectedCategories.contains(category),
                  onSelected: (selected) => onCategoriesChanged(
                    selected
                        ? {...selectedCategories, category}
                        : selectedCategories
                            .where((c) => c != category)
                            .toSet(),
                  ),
                ),
            ],
          ),
        if (categories.isNotEmpty && countries.isNotEmpty)
          const SizedBox(height: AppSpacing.sm),
        if (countries.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final country in countries)
                FilterChip(
                  label: Text(country),
                  selected: selectedCountries.contains(country),
                  onSelected: (selected) => onCountriesChanged(
                    selected
                        ? {...selectedCountries, country}
                        : selectedCountries
                            .where((c) => c != country)
                            .toSet(),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
```

- [ ] **Step 8: Wire filtering into `PlacesScreen`**

Convert `PlacesScreen` from `ConsumerWidget` to `ConsumerStatefulWidget`,
holding the filter state and inserting `PlaceFilterBar` into the list
body. Replace the whole file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/presentation/trip_providers.dart';
import '../domain/place.dart';
import 'add_place_screen.dart';
import 'place_actions_sheet.dart';
import 'place_providers.dart';
import 'place_visit_actions.dart';
import 'place_widgets.dart';
import 'places_map_view.dart';

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key});

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  Set<PlaceCategory> _categoryFilter = {};
  Set<String> _countryFilter = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncPlaces = ref.watch(placeListProvider);
    final places = asyncPlaces.valueOrNull ?? const <Place>[];
    final filtered = filterPlaces(
      places,
      categories: _categoryFilter,
      countries: _countryFilter,
    );
    final stats = ref.watch(placeStatsProvider);
    final trips = ref.watch(tripListProvider).valueOrNull ?? [];
    final tripNames = {for (final t in trips) t.id: t.name};
    final mapMode = ref.watch(placesMapModeProvider);

    final want = filtered.where((p) => !p.isVisited).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final been = sortForList(filtered).where((p) => p.isVisited).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabPlaces),
        actions: [
          if (places.isNotEmpty)
            IconButton(
              icon: Icon(
                mapMode ? Icons.view_list_outlined : Icons.map_outlined,
                color: colors.inkSecondary,
              ),
              tooltip: mapMode ? l10n.listViewToggle : l10n.mapViewToggle,
              onPressed: () =>
                  ref.read(placesMapModeProvider.notifier).state = !mapMode,
            ),
          IconButton(
            icon: Icon(Icons.add, color: colors.accent),
            tooltip: l10n.placesEmptyCta,
            onPressed: () => AddPlaceScreen.open(context),
          ),
        ],
      ),
      body: _body(
        context,
        l10n,
        asyncPlaces,
        places,
        filtered,
        want,
        been,
        stats,
        tripNames,
        mapMode,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<Place>> asyncPlaces,
    List<Place> places,
    List<Place> filtered,
    List<Place> want,
    List<Place> been,
    ({int countries, int visited, int days}) stats,
    Map<String, String> tripNames,
    bool mapMode,
  ) {
    if (asyncPlaces.hasError) {
      return ErrorState(onRetry: () => ref.invalidate(placeListProvider));
    }
    if (asyncPlaces.hasValue && places.isEmpty) {
      return EmptyState(
        icon: Icons.place_outlined,
        title: l10n.placesEmptyTitle,
        body: l10n.placesEmptyBody,
        ctaLabel: l10n.placesEmptyCta,
        onCta: () => AddPlaceScreen.open(context),
      );
    }
    if (mapMode) {
      return PlacesMapView(
        places: filtered,
        focusPlaceId: ref.watch(selectedPlaceIdProvider),
        onFocusHandled: () =>
            ref.read(selectedPlaceIdProvider.notifier).state = null,
        onPlaceTap: (place) => showPlaceActionsSheet(context, ref, place),
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        PlaceStatsHeader(
          countries: stats.countries,
          visited: stats.visited,
          days: stats.days,
        ),
        const SizedBox(height: AppSpacing.lg),
        PlaceFilterBar(
          places: places,
          selectedCategories: _categoryFilter,
          selectedCountries: _countryFilter,
          onCategoriesChanged: (v) => setState(() => _categoryFilter = v),
          onCountriesChanged: (v) => setState(() => _countryFilter = v),
        ),
        if (want.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: SectionLabel(
              '${l10n.placesWantSection} · ${want.length}',
              accent: true,
            ),
          ),
          for (final place in want) _row(context, place, tripNames),
        ],
        if (been.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: SectionLabel(
              '${l10n.placesBeenSection} · ${been.length}',
            ),
          ),
          for (final place in been) _row(context, place, tripNames),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context,
    Place place,
    Map<String, String> tripNames,
  ) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: RowSettleAnimation(
        placeId: place.id,
        child: PlaceRowCard(
          place: place,
          tripName: place.tripId == null ? null : tripNames[place.tripId],
          onTap: () => showPlaceActionsSheet(context, ref, place),
          onToggleVisited: () {
            HapticFeedback.selectionClick();
            markPlaceVisited(ref, place, visited: !place.isVisited);
          },
        ),
      ),
    );
  }
}
```

Note what changed versus the original: `_body`/`_row` moved from
instance methods taking `(context, ref, ...)` to instance methods on the
`State` (dropping the now-redundant `ref` param, since `State` has it
directly); `want`/`been` now derive from `filtered` instead of `places`;
`PlacesMapView.places` gets `filtered` instead of `places`; the stats
header still reads `stats` (unfiltered, per the Global Constraints note)
and `PlaceFilterBar`'s `places:` param is the *unfiltered* `places` (so
its chip set doesn't shrink as filters get applied — you can always widen
a filter back out).

- [ ] **Step 9: Wire filtering into `TripPlacesTab`**

Replace `lib/features/places/presentation/trip_places_tab.dart` in full:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/place.dart';
import 'add_place_screen.dart';
import 'place_actions_sheet.dart';
import 'place_providers.dart';
import 'place_visit_actions.dart';
import 'place_widgets.dart';

/// Places tab inside a trip's detail screen (fills the M1 shell).
class TripPlacesTab extends ConsumerStatefulWidget {
  const TripPlacesTab({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripPlacesTab> createState() => _TripPlacesTabState();
}

class _TripPlacesTabState extends ConsumerState<TripPlacesTab> {
  Set<PlaceCategory> _categoryFilter = {};
  Set<String> _countryFilter = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncPlaces = ref.watch(tripPlacesProvider(widget.trip.id));
    final places = asyncPlaces.valueOrNull ?? const <Place>[];

    if (asyncPlaces.hasValue && places.isEmpty) {
      return EmptyState(
        icon: Icons.place_outlined,
        title: l10n.tripPlacesEmptyTitle,
        body: l10n.tripPlacesEmptyBody,
        ctaLabel: l10n.placesEmptyCta,
        onCta: () => AddPlaceScreen.open(context, tripId: widget.trip.id),
      );
    }

    final filtered = filterPlaces(
      places,
      categories: _categoryFilter,
      countries: _countryFilter,
    );
    final sorted = sortForList(filtered);
    final visitedCount = places.where((p) => p.isVisited).length;

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
          child: SectionLabel(
            l10n.tripPlacesProgress(visitedCount, places.length),
          ),
        ),
        PlaceFilterBar(
          places: places,
          selectedCategories: _categoryFilter,
          selectedCountries: _countryFilter,
          onCategoriesChanged: (v) => setState(() => _categoryFilter = v),
          onCountriesChanged: (v) => setState(() => _countryFilter = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final place in sorted)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: PlaceRowCard(
              place: place,
              onTap: () => showPlaceActionsSheet(context, ref, place),
              onToggleVisited: () =>
                  markPlaceVisited(ref, place, visited: !place.isVisited),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(l10n.placesEmptyCta),
          onPressed: () => AddPlaceScreen.open(context, tripId: widget.trip.id),
        ),
      ],
    );
  }
}
```

Note: `tripPlacesProgress` (the `SectionLabel`) still counts against the
*unfiltered* `places`/`visitedCount` — it's "N of M visited" for the whole
trip, same reasoning as the aggregate screen's stats header staying
unfiltered.

- [ ] **Step 10: Run tests to verify they pass**

Run: `flutter test test/unit/places/ test/widget/places/`
Expected: PASS, all cases (existing + new).

- [ ] **Step 11: Run analyze**

Run: `flutter analyze lib/features/places/ test/unit/places/ test/widget/places/`
Expected: No issues found.

- [ ] **Step 12: Commit**

```bash
git add lib/features/places/domain/place.dart lib/features/places/presentation/place_widgets.dart lib/features/places/presentation/places_screen.dart lib/features/places/presentation/trip_places_tab.dart test/unit/places/place_domain_test.dart test/widget/places/places_screen_test.dart test/widget/places/trip_places_tab_test.dart
git commit -m "feat(places): filter by category and country on both Places screens"
```

---

### Task 4: Description display + Google Maps link in the place actions sheet

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/sharing/maps_link.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/features/places/presentation/place_actions_sheet.dart`
- Test: Modify `test/unit/places/maps_link_test.dart`
- Test: Modify `test/widget/places/place_actions_test.dart`

**Interfaces:**
- Produces: `googleMapsUri(double lat, double lng)` — consumed only by
  `_PlaceActions` in this task.

- [ ] **Step 1: Write the failing unit test**

In `test/unit/places/maps_link_test.dart`, add a new top-level test group
(same file — `googleMapsUri` belongs conceptually with `parseMapsShare`,
the opposite-direction function already there):

```dart
  group('googleMapsUri', () {
    test('builds a maps.google.com search URL from coordinates', () {
      final uri = googleMapsUri(8.0119, 98.8378);
      expect(uri.toString(),
          'https://www.google.com/maps/search/?api=1&query=8.0119,98.8378');
    });

    test('handles negative coordinates', () {
      final uri = googleMapsUri(-33.8688, 151.2093);
      expect(uri.queryParameters['query'], '-33.8688,151.2093');
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/unit/places/maps_link_test.dart`
Expected: FAIL — `googleMapsUri` doesn't exist yet.

- [ ] **Step 3: Add the `url_launcher` dependency**

In `pubspec.yaml`, add a new line after `google_mlkit_text_recognition:
^0.13.0`:
```yaml
  url_launcher: ^6.3.0
```
Run: `flutter pub get`

- [ ] **Step 4: Implement `googleMapsUri`**

In `lib/core/sharing/maps_link.dart`, add after `MapsLinkService`:

```dart
/// Builds a Google Maps URL that opens [lat],[lng] directly — the
/// opposite direction from [parseMapsShare]: this app already HAS
/// coordinates and wants to hand off to the real Maps app/website, not
/// parse an incoming link. Always the same well-known URL shape, never
/// fetched or cached.
Uri googleMapsUri(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
```

- [ ] **Step 5: Run the unit test to verify it passes**

Run: `flutter test test/unit/places/maps_link_test.dart`
Expected: PASS, both cases.

- [ ] **Step 6: Add the ARB strings**

In `lib/l10n/app_en.arb`, add near `placeViewOnMap`:
```json
  "placeOpenInGoogleMaps": "Open in Google Maps",
  "placeOpenMapsFailed": "Couldn't open Google Maps.",
```

- [ ] **Step 7: Write the failing widget test**

In `test/widget/places/place_actions_test.dart`, add:

```dart
  testWidgets('description shows in the actions sheet when set',
      (tester) async {
    final repo = FakePlaceRepository([
      _place.copyWith(notes: 'A lovely lookout'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();

    expect(find.text('A lovely lookout'), findsOneWidget);
    expect(find.byKey(const Key('place-description')), findsOneWidget);
  });

  testWidgets('no description line when notes is empty', (tester) async {
    final repo = FakePlaceRepository([_place]); // _place has no notes
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('place-description')), findsNothing);
  });

  testWidgets('Google Maps action only appears for a located place',
      (tester) async {
    final located = _place.copyWith(lat: () => 8.0119, lng: () => 98.8378);
    final repo = FakePlaceRepository([located]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();

    expect(find.text('Open in Google Maps'), findsOneWidget);
  });

  testWidgets('no Google Maps action for a place with no location',
      (tester) async {
    final repo = FakePlaceRepository([_place]); // _place has no lat/lng
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay viewpoint'));
    await tester.pumpAndSettle();

    expect(find.text('Open in Google Maps'), findsNothing);
  });
```

- [ ] **Step 8: Run to verify they fail**

Run: `flutter test test/widget/places/place_actions_test.dart`
Expected: FAIL — no description line, no "Open in Google Maps" action.

- [ ] **Step 9: Implement**

In `lib/features/places/presentation/place_actions_sheet.dart`, add
imports:
```dart
import 'package:url_launcher/url_launcher.dart';

import '../../../core/sharing/maps_link.dart';
```

In `_PlaceActions.build`, insert a description block right after the
existing `ListTile` (name/subtitle) and before the `const Divider()`:
```dart
            if (place.notes.trim().isNotEmpty)
              Padding(
                key: const Key('place-description'),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  place.notes,
                  style: TextStyle(color: colors.inkSecondary),
                ),
              ),
            const Divider(),
```

Add a new `ListTile` right after the existing `if (place.hasLocation)
ListTile(... l10n.placeViewOnMap ...)` block, still inside that same `if
(place.hasLocation)` guard (turn it into a list with `[...]` if it isn't
already, so both tiles share the one location check):
```dart
            if (place.hasLocation) ...[
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(l10n.placeViewOnMap),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(placesMapModeProvider.notifier).state = true;
                  ref.read(selectedPlaceIdProvider.notifier).state = place.id;
                  context.go('/places');
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.placeOpenInGoogleMaps),
                onTap: () async {
                  // Resolve everything from context BEFORE the await —
                  // this sheet's own context becomes unreliable once the
                  // pop below settles, and launchUrl is a real async gap.
                  final messenger = ScaffoldMessenger.of(context);
                  final failedMessage = l10n.placeOpenMapsFailed;
                  Navigator.of(context).pop();
                  final launched = await launchUrl(
                    googleMapsUri(place.lat!, place.lng!),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched) {
                    messenger
                        .showSnackBar(SnackBar(content: Text(failedMessage)));
                  }
                },
              ),
            ],
```

- [ ] **Step 10: Run tests to verify they pass**

Run: `flutter test test/widget/places/place_actions_test.dart`
Expected: PASS, all cases.

- [ ] **Step 11: Run analyze**

Run: `flutter analyze lib/core/sharing/maps_link.dart lib/features/places/presentation/place_actions_sheet.dart test/unit/places/maps_link_test.dart test/widget/places/place_actions_test.dart`
Expected: No issues found.

- [ ] **Step 12: Regenerate localizations and commit**

```bash
flutter gen-l10n
git add pubspec.yaml pubspec.lock lib/core/sharing/maps_link.dart lib/l10n/app_en.arb lib/l10n/app_localizations*.dart lib/features/places/presentation/place_actions_sheet.dart test/unit/places/maps_link_test.dart test/widget/places/place_actions_test.dart
git commit -m "feat(places): show description and an Open in Google Maps action"
```

---

### Task 5: `PlaceStatsHeader` alignment fix

**Files:**
- Modify: `lib/features/places/presentation/place_widgets.dart`
- Test: Modify `test/widget/places/places_screen_test.dart`

**Interfaces:** none — self-contained visual fix, no new public surface.

- [ ] **Step 1: Write the failing test**

In `test/widget/places/places_screen_test.dart`, add:

```dart
  testWidgets(
      'stat labels stay centered even when the longest one wraps to two '
      'lines', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 200, // narrow enough to force "Places visited" to wrap
            child: PlaceStatsHeader(countries: 3, visited: 12, days: 20),
          ),
        ),
      ),
    );
    final label = tester.widget<Text>(find.text('PLACES VISITED'));
    expect(label.textAlign, TextAlign.center);
  });
```
(add `import 'package:tripper/features/places/presentation/place_widgets.dart';`
if this file doesn't already import it — check first, `PlacesScreen`
likely already pulls it in transitively but the direct import may be
needed for the `PlaceStatsHeader` constructor reference.)

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/widget/places/places_screen_test.dart`
Expected: FAIL — `textAlign` is null, not `TextAlign.center`.

- [ ] **Step 3: Implement**

In `lib/features/places/presentation/place_widgets.dart`, in
`PlaceStatsHeader._stat`, add `textAlign: TextAlign.center` to both `Text`
widgets:

```dart
  Widget _stat(BuildContext context, String value, String label) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: colors.inkPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionLabel.copyWith(color: colors.inkMuted),
        ),
      ],
    );
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget/places/places_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full places suite and analyze**

Run: `flutter test test/unit/places/ test/widget/places/`
Expected: PASS, all cases across the whole feature.

Run: `flutter analyze lib/features/places/ test/unit/places/ test/widget/places/`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/places/presentation/place_widgets.dart test/widget/places/places_screen_test.dart
git commit -m "fix(places): center stats-header labels when they wrap to two lines"
```

## Self-Review Notes

- **Spec coverage:** category (Task 1 schema/domain, Task 2 forms),
  filtering by category+country on both screens (Task 3), description
  display + Google Maps link (Task 4), stats-header alignment (Task 5).
  "Out of scope" items from the design (multiple categories per place,
  persisted filter state, a fixed country list, an editable/pasted maps
  link) — none introduced.
- **Refinement caught during planning, not left for the review loop:**
  the design spec named `lib/features/places/domain/place.dart` as
  `googleMapsUri`'s home; while gathering exact file context,
  `lib/core/sharing/maps_link.dart` turned out to already exist holding
  the *opposite*-direction function (`parseMapsShare`, Maps-link →
  coordinates) — placing the new coordinates → Maps-link function in the
  same file, right next to it, is more consistent than inventing a second
  "maps link" concept in `place.dart`. Task 4 reflects this.
- **Migration correctness verified against the codebase's own documented
  failure mode:** Task 1 Step 5 explicitly restructures the *existing*
  `if (from < 5) { createTable(places); }` into an `if`/`else if` with the
  new `addColumn` step — never two independent `if`s — matching
  `app_database.dart`'s own comment about this exact class of bug, and
  Task 1's migration test includes the multi-version-jump case
  (`v4 -> v12` in one step) that would have caught getting this wrong, the
  same way `expenses_migration_test.dart`'s `v6 -> v8` test already does
  for that table.
- **`PlaceStatsHeader`/`TripPlacesTab.tripPlacesProgress` stay unfiltered**
  by deliberate design choice (Global Constraints), not an oversight —
  both are "whole trip/whole collection" figures, not a view into the
  currently-filtered subset.
- **Placeholder scan:** no TBD/TODO; every step has complete, runnable
  code including exact ARB additions and the new `pubspec.yaml` line.
- **Type consistency:** `PlaceCategory`, `Place.category`,
  `filterPlaces`, `placeCategoryIcon`/`Label`, `PlaceFilterBar`,
  `googleMapsUri` are each defined once (Tasks 1-4) and consumed with
  matching names/signatures everywhere they're used afterward.
- **New dependency called out explicitly, not smuggled in:** `url_launcher`
  is a new `pubspec.yaml` entry (Task 4, Step 3) — flagged here and in the
  design spec's "New dependency" note, not silently added inside a larger
  diff.
