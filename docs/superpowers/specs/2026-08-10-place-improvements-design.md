# Place feature improvements

Status: approved, not yet implemented. Second of five independent
sub-projects scoped out of a larger batch request (Spend — shipped;
Place — this spec; Vault; Hebrew/RTL; trip-subtitle — each gets its own
spec).

## Problem

Four independent gaps in the Place (wishlist/visited) feature:

1. A place has no category — every place looks the same in the list
   regardless of whether it's a hotel, a restaurant, or a hiking trail.
2. (Depends on #1) There's no way to filter the Places list by category or
   country — with enough places, the wishlist becomes one long undifferentiated
   scroll.
3. A place has a hidden `notes` field with no form to edit it, and no way
   to see or open its location as a Google Maps link.
4. `PlaceStatsHeader`'s "Places visited" stat renders left-aligned instead
   of centered like its two siblings, once it wraps to two lines.

## Design

### 1. Category

New enum, `lib/features/places/domain/place.dart`:

```dart
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

Order is stable and append-only (stored as an int index, same convention
`ExpenseCategory`/`DocumentCategory` already use). `Place.category` is
`PlaceCategory?` — **nullable, not defaulted** — every place that exists
before this ships has no category, and "uncategorized" is a real, valid
state distinct from "Other" (silently bucketing pre-existing places into
"Other" would be a lossy, invented fact, not a migration).

**Schema:** `Places` table gains `IntColumn get category =>
integer().nullable()()`. `schemaVersion` 11 → 12, `onUpgrade` gets an
`addColumn` step, following the exact pattern already established for
`journalEntries.placeId` (v10→v11) and `expenses`'s conversion columns
(v7→v8) in `lib/core/database/app_database.dart`. Ships with a migration
test in `test/unit/places/places_migration_test.dart`, mirroring
`test/unit/expenses/expenses_migration_test.dart`'s structure exactly
(hand-built old-shaped table, assert existing rows survive with `category
IS NULL`).

**Icons + labels:** a `placeCategoryIcon(PlaceCategory)` /
`placeCategoryLabel(AppLocalizations, PlaceCategory)` pair, matching
`expenseCategoryIcon`/`expenseCategoryLabel`'s exact shape
(`lib/features/expenses/presentation/expense_widgets.dart`). 12 new ARB
keys (`catHotel`, `catCoffeeShop`, etc. — reusing `catRestaurant`/`catOther`
where an identical word already exists from Expense/Document categories,
one translation to maintain rather than two, same reasoning Expense's own
category labels already use).

**Forms:** both `AddPlaceScreen`'s save card and `_EditPlaceForm`
(`place_actions_sheet.dart`) get a `Wrap` of `ChoiceChip`s (one category
selectable at a time — matches how Expense/Document categories work, one
category per item, not a multi-tag model), each chip showing its icon +
label. No category selected is a valid state (renders as "no chip
selected," not a forced default) — the create flow doesn't force a choice
before saving, matching the existing least-friction philosophy of that
screen.

### 2. Filters (categories + countries, multi-select)

New filter-chip UI, first of its kind in this app (no existing
list-filtering pattern to match — the codebase's only prior chip usage is
*selection*, e.g. the trip-picker chips in these same two forms). New
widget `PlaceFilterBar` (`place_widgets.dart`): two `Wrap` rows of
`FilterChip`s — one for categories (fixed 12-entry enum, only categories
actually present across the currently-visible places render a chip, so an
empty category never shows a dead-end filter), one for countries
(generated dynamically from the distinct, non-empty `country` values
across the current place list — no fixed list, matching country's existing
free-text nature).

Selection model: multi-select within each row (OR — "Restaurant or Coffee
Shop"), AND across the two rows ("(Restaurant or Coffee Shop) and (Thailand
or Japan)"). No selection in a row means that row doesn't filter (shows
everything). Filter state is per-screen, in-memory, session-scoped (like
`placesMapModeProvider` already is) — doesn't need to persist across app
restarts.

A pure function, `filterPlaces(List<Place> places, {Set<PlaceCategory>
categories, Set<String> countries})`, in `domain/place.dart` — unit-testable
without widgets, same shape as `sortForList`/`visitedStats` already there.

**Applies everywhere places are listed:** both `PlacesScreen` (aggregate)
and `TripPlacesTab` (per-trip) get the filter bar, per the approved design
choice to cover both rather than just the aggregate screen. `PlacesScreen`
already branches between list view and `PlacesMapView` (`mapMode`) — the
*same* filtered list feeds both, so switching to map view while a filter
is active keeps it applied, not silently reset.

### 3. Description + Google Maps link

**Description** reuses the existing `notes` field end to end — no schema
change. Both `AddPlaceScreen`'s save card and `_EditPlaceForm` get a new
multi-line `TextField` (`labelText: l10n.placeFormDescription`), wired to
`_notes`/a new controller respectively. `_PlaceActions`
(`place_actions_sheet.dart`) — which currently shows only name and
city/country and nothing else — gets the description rendered under the
existing subtitle line when `place.notes` is non-empty.

**Google Maps link** is generated on the fly, never stored:
```dart
Uri googleMapsUri(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
```
(`domain/place.dart` — pure, easy to unit-test the URL shape directly). A
new `_PlaceActions` list item, "Open in Google Maps," appears whenever
`place.hasLocation`, right next to the existing "View on map" (in-app map)
action — the two are complementary, not a replacement: "View on map" jumps
to this app's own map view, "Open in Google Maps" launches the external
Maps app/website.

**New dependency:** `url_launcher` (not currently in `pubspec.yaml` — the
app has no prior external-URL-launch code; `open_filex` exists but only
opens local files). Added as a normal `dependencies:` entry, pinned the
same way other deps in this file are (`^` caret constraint on the current
stable major).

### 4. `PlaceStatsHeader` alignment fix

Root cause: `_stat()`'s two `Text` widgets have no `textAlign`. A
`Column`'s `crossAxisAlignment: center` centers a child's *bounding box* —
for single-line text that's indistinguishable from centering the text
itself, but "Places visited" (the longest of the three labels) can wrap to
two lines on narrower screens; once it wraps, its box fills the whole
`Expanded` slot and the text default-aligns left inside that box,
revealing the difference. Fix: add `textAlign: TextAlign.center` to both
`Text` widgets in `_stat()`. Two-line change, no layout restructuring.

## Error handling

- `url_launcher`'s `launchUrl` returning `false` (no app can handle the
  URL — a real possibility on some Android configurations) is handled with
  a quiet `SnackBar` ("Couldn't open Google Maps"), not a crash or a silent
  no-op — consistent with this app's established pattern of never leaving
  a tap looking like it did nothing (same reasoning as the vault's existing
  `showCodePdfFallback`/`showCodeFileMissing` messages).
- Every part of this spec is fully local (category, filters, description)
  except opening the Maps link, which is the *user* leaving the app
  deliberately (a tap, not an automatic network call) — CLAUDE.md rule 4
  doesn't apply the same way it does to a background fetch, but it's worth
  noting explicitly: nothing here changes what data is visible without a
  connection.

## Testing

- `filterPlaces` and `googleMapsUri`: pure, unit-tested directly.
- Migration test for v11→v12 (category column), mirroring
  `expenses_migration_test.dart`'s structure: old-shaped table survives,
  new column is nullable and defaults to `NULL` on existing rows, a
  multi-version jump (e.g. v10→v12) doesn't double-apply.
- Widget tests (repository boundary mocked, per rule 5): category chip
  selection in both add/edit forms persists through save; filter bar
  narrows the visible list correctly for single- and multi-select cases
  across both categories and countries, in both `PlacesScreen` and
  `TripPlacesTab`; the Maps-link action only appears when `hasLocation` is
  true; description text renders in the actions sheet when non-empty and
  is absent when empty (no empty label floating there).
- The alignment fix itself needs no new test — this is a leaf visual tweak
  with no logic branch to assert on; confirmed by the same 1.3× text-scale
  accessibility check already in `test/widget/accessibility_test.dart`
  (flagged as a coverage gap during the Spend plan's final review — this
  is the natural place to extend it to also render `PlacesScreen`).

## Out of scope this round

- Multiple categories per place (tags) — one category per place, matching
  the existing Expense/Document single-category convention.
- Persisting filter selections across app restarts.
- A fixed/curated country list (countries stay free-text input, same as
  today) — filtering only reads from whatever's already been typed.
- Editing the Google Maps link manually, or supporting a place with no
  coordinates having one at all (approved design: generate-from-coordinates
  only, no stored/pasted link).
- Any change to the existing `notes` *storage* — this only adds UI to a
  field that already existed.
