# Packing checklist

Status: approved, not yet implemented.

## Problem

Tripper has no packing/checklist feature at all — not in `lib/features/`,
not mentioned in `docs/SPEC.md`. It's a near-universal expectation for a
travel app and fits the existing trip model cleanly, with no dependency on
anything the project has deferred (climate/weather data, live GPS, cloud
sync).

This spec covers a reusable-template packing list, embedded per trip like
Journal and Expenses, with one wrinkle beyond a plain checklist: clothing
items need to be tracked through a trip-length lifecycle (packed → worn →
needs washing → clean again), not just checked off once.

## Design

### 1. Data model (`lib/features/packing/data/packing_tables.dart`)

Two independent concepts, following the `Expenses`/`JournalEntries` table
style (`@DataClassName`, `TextColumn id`, FK with `onDelete`):

```dart
enum PackingCategory { clothing, documents, electronics, toiletries, other }

enum PackingItemStatus { toPack, packed, worn, inWash, clean }

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
  IntColumn get category => integer()(); // index into PackingCategory
  TextColumn get label => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TripPackingItemRow')
class TripPackingItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  IntColumn get category => integer()(); // index into PackingCategory
  TextColumn get label => text()();
  IntColumn get status => integer()(); // index into PackingItemStatus
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

`status` is a single 5-value enum column on `TripPackingItems`, not a
boolean plus a nullable clothing-only field. Non-clothing categories only
ever hold `toPack`/`packed` (the UI shows a plain checkbox toggling between
those two); clothing items expose all 5 via a free-pick menu. Unifying on
one column keeps the schema and repository single-purpose — only the
presentation layer branches on category. Template items carry no status
(they aren't physical instances yet); every item copied from a template
into a trip starts at `toPack`, regardless of category.

Trip-owned rows cascade-delete with the trip, matching `Expenses` (a
packing list without its trip is meaningless, same reasoning documented on
`Expenses.tripId`). Template rows are independent of any trip and are never
cascade-deleted by trip deletion.

Wired into `lib/core/database/app_database.dart`: add `PackingTemplates`,
`PackingTemplateItems`, `TripPackingItems` to `tables:`, add a
`PackingDao` to `daos:`, bump `schemaVersion` to 17, and add an
`if (from < 17) { await m.createTable(...) }` block for all three new
tables — following the exact pattern of the v16 (`PlaceCollections`) step.
Add a `v17` line to the schema-history doc comment at the top of the file.

### 2. Repository (`lib/features/packing/data/packing_repository.dart`)

Mirrors `ExpenseRepository`'s shape. Key operations:

- Template CRUD: `createTemplate`, `renameTemplate`, `deleteTemplate`,
  `addTemplateItem`, `updateTemplateItem`, `deleteTemplateItem`,
  `watchTemplates()`, `watchTemplateItems(templateId)`.
- Trip list CRUD: `addTripItem(tripId, category, label)` (status defaults
  to `toPack`), `updateTripItemStatus(itemId, status)`,
  `updateTripItemLabel`, `deleteTripItem`, `watchTripItems(tripId)`.
- `applyTemplate(tripId, templateId)`: reads the template's items and
  inserts a copy of each into `TripPackingItems` with `status: toPack` and
  a fresh id — an **append**, not a replace, so applying a second template
  (or applying the same one twice) adds to the existing list rather than
  clearing it. No link is kept back to the template; later edits to either
  side never affect the other.

### 3. Trip tab (`lib/features/packing/presentation/trip_packing_tab.dart`)

Added to `lib/features/trips/presentation/trip_detail_screen.dart` as a
fifth tab, alongside the existing four (`TripDocumentsTab`,
`TripPlacesTab`, `TripExpensesTab`, `TripJournalTab`) — update both the
`tabs:` list and the `TabBarView` children, and the tab-order doc comment
at the top of the file (line 25).

- Items grouped by category (fixed section per `PackingCategory` value,
  hidden when empty), each row using the existing `PaperCard`/list-row
  style already used by Documents/Expenses tabs — a plain content list, not
  a hero/glass surface (CLAUDE.md hard rule 6).
- Non-clothing rows: a checkbox, toggling `toPack`/`packed`.
- Clothing rows: the current status as a small label (e.g. a `PillChip`,
  matching `lib/core/widgets/pill_chip.dart`'s existing use elsewhere),
  tapping it opens a menu with all 5 `PackingItemStatus` values.
- Inline "add item" entry (category picker + label text field) at the
  bottom of each category section, or a single add action that asks for
  category first — matches `ExpenseFormSheet`'s bottom-sheet pattern rather
  than introducing a new interaction shape.
- AppBar/overflow action **"Apply template…"**: opens a picker over
  `watchTemplates()`, selecting one calls `applyTemplate`.
- AppBar/overflow action **"Manage templates…"**: opens the template
  manager (§4). Deliberately **not** placed in `SettingsScreen` — that
  screen is gated behind the vault lock for its whole body (see its
  `initState`/`_unlock` comment: "same gate as the vault," covering the
  lock toggle and document export), and packing templates have no
  security-sensitive content that justifies that friction. Keeping the
  entry point on the Packing tab itself also matches the existing pattern
  of contextual actions living where they're used (e.g. `PlacesScreen`'s
  "+" `PopupMenuButton`).

### 4. Template manager (`lib/features/packing/presentation/packing_template_manager_screen.dart`)

A standalone screen (pushed from the Packing tab's overflow menu, not part
of the tab shell):

- List of templates (name + item count), tap to open an editor.
- Editor: rename the template, add/edit/remove items (category + label),
  reorder within a category (`sortOrder`).
- Create/delete a template from the list screen.

## Localization & theming

All user-facing strings via ARB (`lib/l10n/app_en.arb`), RTL-safe layout
using `EdgeInsetsDirectional`/start-end (CLAUDE.md hard rule 3). No new
color tokens — status chips and category sections use the existing
`AppColors`/`PaperCard`/`PillChip`/`SectionLabel` primitives; no gradient or
glass chrome (hard rule 6). No `DateTime.now()` in domain code — this
feature has no timestamp fields at all, so hard rule 2 doesn't come into
play.

## Error handling

- Fully local/offline feature — no network path exists anywhere in this
  design, so CLAUDE.md hard rule 4 ("network may enhance, never gate") is
  trivially satisfied: there is nothing to degrade.
- Deleting a template that's been applied to trips in the past does not
  affect those trips' existing packing lists (no link is kept — see §2).
- Deleting a trip cascade-deletes its `TripPackingItems` (FK
  `onDelete: KeyAction.cascade`), consistent with `Expenses`.
- Applying a template to a trip with an already-nonempty list appends
  rather than overwrites; there is no "undo" for an apply beyond manually
  deleting the added items — acceptable since nothing is destroyed by the
  action itself.

## Testing

- Migration test for the v17 schema bump (CLAUDE.md hard rule 5), covering
  a fresh install (`onCreate`) and an upgrade from v16.
- `PackingRepository` unit tests: template CRUD, trip-item CRUD,
  `applyTemplate` copy semantics (every copied item starts at `toPack`,
  independent of source template afterward, append not replace, applying
  twice duplicates), status transitions including non-adjacent ones (e.g.
  `worn` → `clean` directly, skipping `inWash`).
- Widget tests for `TripPackingTab` and `PackingTemplateManagerScreen`,
  mocked at the repository boundary (hard rule 5): category grouping and
  empty-category hiding, checkbox toggle for non-clothing items, the
  5-option status menu for clothing items, apply-template flow, add/edit/
  delete item, template create/rename/delete.

## Out of scope this round

- Auto-suggested/climate-driven starter lists (ruled out during
  brainstorming in favor of reusable templates only).
- User-defined categories (fixed 5-category enum only).
- A live link between a template and trips it's been applied to.
- Reordering categories themselves, or cross-category drag-and-drop.
- Sharing/exporting a template or a trip's packing list.
