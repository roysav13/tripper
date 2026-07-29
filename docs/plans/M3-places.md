# M3 — Wishlist & visited places

**Goal:** track places as **want to go** (teal, first) and **been there** (gray, recessed, bottom) across map and list views; link places to trips; completing a trip offers bulk-move of its wishlist to visited.

**Exit criteria:** add a place manually, see teal pin on map; mark visited → pin grays, row drops to BEEN THERE section with visited date; finish a trip → bulk-complete sheet works; integration test covers the full loop; CI green.

## 3.1 Data layer (`lib/features/places/data/`)

- [ ] Drift table `Places`: `id`, `name`, `lat`, `lng` (nullable — a place can exist before it's located), `country`, `city` (nullable), `status` (enum: wantToGo, beenThere), `visitedAt` (nullable date), `tripId` (nullable FK, `ON DELETE SET NULL` — deleting a trip keeps its places), `notes`, `createdAt`
- [ ] Schema v4 + migration test
- [ ] `PlacesDao`: CRUD, `watchAll()`, `watchForTrip(tripId)`, `bulkMarkVisited(ids, date)`, counts per status
- [ ] Repository + domain model

## 3.2 Map (`google_maps_flutter`)

> Superseded: shipped on `google_maps_flutter` (Google Maps SDK, API key in
> `android/local.properties`), not `flutter_map`/OSM as originally scoped —
> see README status. As of 2026-07-23 the map also dropped the muted
> app-branded style for a **stock Google Maps look**: default colors/POIs/
> transit, standard chrome (zoom controls, map toolbar, my-location button +
> blue dot), default red pins, and a layers (default/satellite/terrain)
> button — see `lib/features/places/presentation/map_style.dart`. Status
> (visited vs. wishlist) now lives in the marker's info-window text instead
> of pin color, since pins are stock red.

- [ ] Pin widgets per revised design: teal `map-pin` (want to go) vs gray `circle-check` (been there) — shape + color differ, survives grayscale; **list-view only now, map pins are stock red (see note above)**
- [ ] Tap pin → bottom card with place info + status toggle
- [ ] Camera: fit-bounds to shown pins; cluster nothing in MVP (revisit past ~200 places)
- [ ] Tile caching: persistent tile cache (`flutter_map_tile_caching` or a `Dio`-cached tile provider) — not just the in-memory image cache. When a trip is viewed online, pre-cache tiles for its places' bounding box at 3 zoom levels
- [ ] Offline map state: no cached tile → flat paper-tone canvas, pins still render and remain tappable, quiet "map unavailable offline" chip (SPEC §3.1.2) — never a spinner or error dialog
- [ ] Widget test: pins render and toggle on the no-tile canvas (offline simulation)

## 3.3 Presentation (`lib/features/places/presentation/`)

- [ ] `PlacesScreen` (tab 3): map on top, Map/List toggle in header; below, sections **WANT TO GO (teal label, white cards, first)** then **BEEN THERE (gray label, paper cards, gray text, last)** — per revised mockup
- [ ] Wishlist row: teal pin icon, name, mono `CITY, COUNTRY · THIS TRIP` metadata, faint check target on the right → tap marks visited (sets `visitedAt` = today, animates row down)
- [ ] Visited row: gray check, gray text, mono `VISITED 18 JUL 2026`; tap to un-visit (mistakes happen)
- [ ] `PlaceFormSheet`: name (required), country/city, optional lat/lng via long-press-on-map picker ("drop pin" flow — no places-search API in MVP)
- [ ] Trip detail → Places tab (fills M1 shell): trip-linked places only, same two-section layout, "X of Y visited" counter chip feeding the trip card stat from M1
- [ ] **Trip completion flow**: when a trip transitions active→past (bucketer from M1, checked on app open), one-time prompt: "Trip over — mark its 6 wishlist places as visited?" with per-place checkboxes; writes `visitedAt = trip.endDate`

## 3.3.1 Share target — Google Maps links

- [ ] Handle `ACTION_SEND` with `text/plain` containing a maps URL (`maps.app.goo.gl`, `google.com/maps`): parse place name + coordinates from the URL (short links need one HTTP resolve — the only network call in the MVP, fails gracefully offline into "add manually" with the link kept in notes)
- [ ] Opens `PlaceFormSheet` prefilled → user picks trip (optional) → saved as want-to-go

## 3.3.2 Stats header (trophy case)

- [ ] Places tab header row above the map: countries visited count, places visited count — mono numerals, serif labels
- [ ] Tapping it → all-time map view: only been-there pins, fit-bounds to everything, country list below grouped by continent
- [ ] Pure queries over existing data (`DISTINCT country WHERE status = beenThere`) — no new entities

## 3.4 Tests

Unit:

- [ ] DAO: status transitions, bulk-mark, trip-delete keeps places (`SET NULL` verified), counts
- [ ] Maps-URL parser: full URL with coords, short link (mocked resolve), garbage text, offline fallback
- [ ] Stats queries: distinct-country counting, empty state (0 visited)
- [ ] Sort/section logic: want-to-go first, then been-there by `visitedAt` desc
- [ ] Trip-completion detector: fires once per trip (persisted flag), not on every launch

Widget:

- [ ] Places list: sections order, empty states per section, check-tap moves row
- [ ] Map view: renders N pins with right icon per status (pump with fake tile provider — **never hit OSM network in tests**)
- [ ] Bulk-complete sheet: partial selection applies correctly

Golden:

- [ ] Wishlist row, visited row, pin widgets, place bottom-card — light + dark

Integration:

- [ ] Full loop: create trip → add 2 places to it → mark 1 visited from list → end-date trip in past (inject clock) → relaunch → bulk-complete sheet → accept → both gray, counts correct

## Watch out for

- OSM tile usage policy: set a proper `userAgentPackageName`; no bulk prefetching
- `lat/lng` doubles: store raw doubles, format display to 4 decimals via `MonoText`
- Emulator map testing is flaky in CI — map widget tests use fake tiles; real tiles verified manually on device only
