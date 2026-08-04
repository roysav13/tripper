# Journal: globe, gallery, and place↔entry correlation — design

Status: approved, not yet implemented.

## Problem

Six issues reported against the current Journal tab (`lib/features/journal/`):

1. Globe dots are flat, oversized, and collide easily even for far-apart locations.
2. The globe plots visited **Places**, not journal **entries** — the two concepts aren't correlated in either direction.
3. No line connects the dots on the globe to show trip progression.
4. The globe auto-rotates continuously (`isRotating: true`), which is disorienting; it should only move on user drag, and should open oriented on the most recent entry rather than a fixed default.
5. Entries with a photo render as a plain dot on the globe instead of showing the photo.
6. The horizontal entry gallery below the globe is visually flat — no rhythm, no reason to want to scroll through it.

Two things already do part of what's needed and should NOT be rebuilt: `JournalMapView` (the map toggle) already plots entries (not places) as circles/photo-bitmap markers connected by a chronological `Polyline` — the globe should get the equivalent treatment, on the globe's own terms (below). The location picker already auto-creates a visited `Place` when a *new* named location is picked for an entry — the correlation work extends this, it doesn't replace it.

## 1. Data model & Place↔JournalEntry correlation

An entry *is* a visited place, conceptually — the app should keep both directions in sync rather than track them independently.

### Schema

`journal_entries` gains a nullable `placeId` column (schema v11), FK to `places(id)`:

```dart
TextColumn get placeId =>
    text().nullable().references(Places, #id, onDelete: KeyAction.setNull)();
```

`onDelete: setNull`, not `cascade` — matches how `Places.tripId` already treats its own trip FK (deleting the parent unlinks, never deletes, the child). Deleting a place must never delete a journal entry; entries are user content (text, photos) and are only ever removed by explicit user action (existing delete-entry flow, unchanged).

Migration (`app_database.dart`, `schemaVersion` 10 → 11):
```dart
if (from < 11) {
  await m.addColumn(journalEntries, journalEntries.placeId);
}
```
Ships with a migration test (v10→v11: column added; a place with a linked entry, deleted, leaves the entry with `placeId = null` and everything else intact) — following the existing migration-test convention in this codebase.

`JournalEntry` (domain), `JournalEntryRow`/DAO mapping, and `JournalRepository.createEntry`/`updateEntry` all gain a `placeId` parameter, threaded through the same way `lat`/`lng`/`placeName` already are.

### Place → Entry (marking a place visited creates an entry)

Today, three call sites independently call `placeRepository.setVisited(id, visited: ...)`:
`trip_places_tab.dart`, `places_screen.dart`, `place_actions_sheet.dart`.

Replace all three with a single orchestration function (new, small — e.g. `lib/features/places/presentation/place_visit_actions.dart`):

```dart
Future<void> markPlaceVisited(WidgetRef ref, Place place, {required bool visited}) async {
  final placeRepo = ref.read(placeRepositoryProvider);
  final clock = ref.read(clockProvider);
  final visitedOn = visited ? clock() : null;
  await placeRepo.setVisited(place.id, visited: visited, visitedOn: visitedOn);
  if (!visited || place.tripId == null) return;
  final journalRepo = ref.read(journalRepositoryProvider);
  final hasEntry = await journalRepo.hasEntryForPlace(place.id); // new DAO query
  if (hasEntry) return;
  await journalRepo.createEntry(
    tripId: place.tripId!,
    summary: '',
    loggedAt: visitedOn,
    lat: place.lat,
    lng: place.lng,
    placeName: place.name,
    placeId: place.id,
  );
}
```

- Un-visiting (`visited: false`) never touches the linked entry — it's left exactly as-is (per "never auto-delete entries").
- A place with no `tripId` (not attached to any trip) can't get a trip-scoped entry — `setVisited` still runs, stub creation is silently skipped.
- The `hasEntryForPlace` check makes re-toggling visited on/off/on idempotent — never a second stub.
- The stub entry has an empty summary — it appears on the globe/gallery immediately (as a placeholder card/dot) and invites the user to open and fill it in.

### Entry → Place (picking a place for an entry marks it visited)

`journal_location_picker.dart` already tracks `_pickedPlaceId` when the user taps one of the trip's existing place chips, but only acts on it (creating a new `Place`) when the picked name is *not* already one of the trip's places. Existing-but-unvisited places picked via chip currently do nothing to the place's visited status — that's the gap.

Fix in `_confirmPick`: whichever place ends up resolved (existing chip pick, or a newly-created one for a new named search result) gets `placeRepository.setVisited(id, visited: true, visitedOn: <entry's loggedAt>)` if it isn't already visited. `JournalLocationPick` gains a `placeId` field so the caller (`journal_entry_form_sheet.dart`) can pass it through to `createEntry`/`updateEntry`.

No recursion: this call goes straight to `placeRepository.setVisited` — never through `markPlaceVisited` — so it can't loop back into stub-entry creation. The two directions are separate one-way call sites by construction.

## 2. Globe (`journal_globe.dart`)

### Data source

`JournalGlobe` takes `entries: List<JournalEntry>` instead of `places: List<Place>`. `TripJournalTab` passes the already-fetched `entries` list instead of `visitedPlaces` (the `tripVisitedPlacesProvider` stays — it still feeds the `journalStatsLine` "N places visited" count). Only entries with `hasLocation` participate, same filter `JournalMapView._located` already applies.

### Motion

`FlutterEarthGlobeController(isRotating: false, ...)` — no idle auto-spin; user drag rotation is native to the package and untouched.

On load, and again whenever the chronologically-latest located entry's id changes (not on every unrelated entry edit), animate to it:
```dart
controller.focusOnCoordinates(
  GlobeCoordinates(latest.lat!, latest.lng!),
  animate: true,
  duration: const Duration(milliseconds: 600),
);
```

### Dot size

Reduce `PointStyle.size` well below the package default — this alone is the agreed fix for the "way too big, collides easily" complaint (no clustering logic; hit-testing is still per-point and unaffected by visual overlap).

### Photo dots

`flutter_earth_globe`'s `Point`/`PointStyle` has no built-in image support — but `Point.labelBuilder` renders an arbitrary widget positioned at the point's projected screen coordinate (`FlutterEarthGlobe`'s own `Positioned` math: `left = pos.dx - labelOffset.dx - width/2`, `top = pos.dy - labelOffset.dy - height`). For a fixed-size circular thumbnail widget of diameter `d`, setting `isLabelVisible: true` and `labelOffset: Offset(0, -d / 2)` centers it exactly on the point.

So: entries with a photo get `PointStyle(size: 0)` (native dot suppressed) plus a `labelBuilder` returning a small circle-clipped, accent-bordered thumbnail (`ClipOval` + `Image.file`, same crop treatment `_photoMarkerBitmap` already uses for the map view, minus the canvas/bitmap step since this is a plain widget). Entries without a photo keep the plain small dot from PointStyle, no labelBuilder.

The package's `isVisible` flag (already tracked per point, used for hover/label visibility) keeps the widget hidden when the point is on the far side of the globe — no extra occlusion handling needed.

### Journey line

Sort located entries by `loggedAt` ascending (same order `JournalMapView._located` uses) and connect each consecutive pair with `controller.addPointConnection(PointConnection(start: ..., end: ..., style: PointConnectionStyle(color: colors.accent.withValues(alpha: 0.6), lineWidth: 1.5), ...))`. Default `curveScale` (arced above the surface, not flush with it) — reads clearly as a route rather than disappearing into the sphere's curvature. Connections are diffed on entry-list change the same way `_syncPoints` already diffs points (remove all, re-add) — same rebuild boundary, same reasoning already documented in that method about not disposing the controller itself.

### Test seam

The existing `renderGlobe: false` scaffold (tappable icons, no GPU surface) updates to iterate `entries` instead of `places`, using a photo icon for entries with photos vs. a plain dot icon otherwise — mirroring how `JournalMapView`'s own `renderMap: false` scaffold already distinguishes `Icons.photo_camera` vs `Icons.circle`.

## 3. Gallery (`journal_widgets.dart` / the strip in `trip_journal_tab.dart`)

Confirmed visually via the brainstorming companion (mockups in `.superpowers/brainstorm/…/content/gallery-*.html`, gitignored).

Replace the plain horizontal `ListView` of cards with a horizontal timeline:

- A hairline track runs left→right across the top of the strip.
- Entries are grouped by **calendar day** of `loggedAt` (local date), chronological, one slot per day.
- Each day gets a dot on the track and one card hanging below it on a short stem (flat single row — no zigzag).
- **Single-entry day**: card looks like today's `JournalGalleryCard` (photo-or-placeholder, date, summary).
- **Multi-entry day**: card shows a stacked-photo effect (peeking card edges behind the top photo — the first entry's photo, or the placeholder if none of that day's entries has one) plus a small count badge (e.g. "3"). Summary line shows the first (earliest-logged) entry's summary for that day.
- Tapping a single-entry card opens that entry's edit form directly, as today.
- Tapping a multi-entry card opens a bottom sheet listing that day's entries (thumbnail-or-placeholder, summary, time), tapping a row opens that entry's edit form.
- The existing inline delete "×" stays on single-entry cards; multi-entry (grouped) cards don't show it — deleting happens per-entry, reached via the day-list sheet → edit form → existing delete confirmation.

New strings needed in `app_en.arb` (naming convention matches existing `journal*` keys): a day-list sheet title/count line (e.g. `journalDayEntriesTitle`), nothing else user-facing changes wording.

## 4. Testing

- **Migration test**: v10→v11 `placeId` column add; FK `setNull` behavior verified (delete a place with a linked entry → entry survives with `placeId == null`).
- **Repository/DAO tests**: `createEntry`/`updateEntry` with `placeId`; new `hasEntryForPlace` query.
- **Orchestrator tests** (`markPlaceVisited`): marking visited creates one stub entry; toggling visited off→on→off→on again never creates a second; marking visited on a place with no `tripId` doesn't throw and doesn't create an entry; un-visiting never deletes the entry.
- **Location picker test**: picking an existing, not-yet-visited trip place marks it visited on save; picking an already-visited place is a no-op on visited status (doesn't re-stamp `visitedAt`).
- **Widget tests**: `JournalGlobe` (`renderGlobe: false`) scaffold reflects entries + photo-vs-plain icon; gallery day-grouping (single vs. multi-entry rendering) and the day-list sheet; existing `JournalMapView` tests are unaffected (no behavior change there).

No new network calls anywhere in this design — everything is local Drift data and on-device vault files, consistent with CLAUDE.md's offline-first rule.
