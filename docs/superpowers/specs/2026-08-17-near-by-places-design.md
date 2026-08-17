# Near By places

Status: approved, not yet implemented. Implements `docs/plans/M5-phase2a.md`
§5.10 ("Nearby POI / restaurants / sights — configurable, cost-guarded"),
filling in the technical detail that plan left open, plus a small, explicitly
minimal revival of day-tagging (see §5 — not a return of the withdrawn Plan
tab, see `docs/adr/ADR-001-itinerary-redesign.md`).

## Problem

Places currently only enter the wishlist by manual text search
(`AddPlaceScreen`) or a shared Maps link. There's no way to ask "what's
good and close by" — either to the user's current position or to a place
they've already saved (e.g. a hotel) — to help fill out a day of a trip.
§5.10 already decided the cost/privacy shape of this (off by default,
pull-based, capped, no new persisted entity for suggestions); this spec
decides the API, the UI, and the data model addition needed to actually
build it.

## Design

### 1. Settings: toggle + call counter

`lib/core/settings/settings_service.dart` gains, following the exact shape
of the existing `NotificationsMasterController`/`DocExpiryNoticeDaysController`
pattern (`SharedPreferences`-backed `Notifier`):

- `nearbyPlacesEnabledProvider` (`bool`, key `nearby_places_enabled`,
  **default `false`**) — the master gate. Every other piece of this
  feature checks this before doing anything network-shaped, not just the
  UI that shows/hides the entry point.
- `nearbyApiCallCountProvider` (`int`, key `nearby_api_call_count`,
  default `0`) — incremented by exactly one per real `searchNearby` HTTP
  call (never on a cache hit). No reset action in v1 — it's a lifetime
  "N calls this install" counter, matching the "visible before a surprise
  bill" requirement in §5.10.

Settings screen gets a new section (near the other feature toggles):
switch bound to `nearbyPlacesEnabledProvider`, with a subtitle showing the
current call count. If `kGoogleMapsApiKey` is empty, the switch renders
disabled with explanatory copy ("Requires a Maps API key to be configured")
instead of silently no-opping — Nominatim has no usable rating data, so
this feature has no keyless fallback, unlike search/geocoding.

### 2. Data source: Google Places API (New) `searchNearby`

New file `lib/features/places/data/nearby_places_service.dart`, structured
like `google_places_geocoder.dart` (same key, same HTTP client, same
exception/timeout conventions):

```dart
abstract interface class NearbyPlacesFetcher {
  Future<List<NearbyPlaceResult>> searchNearby({
    required double lat,
    required double lng,
  });
}

@immutable
class NearbyPlaceResult {
  const NearbyPlaceResult({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.userRatingCount,
    this.primaryType,
  });
  final String placeId;
  final String name;
  final double lat;
  final double lng;
  final double rating;
  final int userRatingCount;
  final String? primaryType; // raw Google type, mapped to PlaceCategory in the UI layer
}
```

`GoogleNearbyPlacesFetcher` POSTs to
`https://places.googleapis.com/v1/places:searchNearby` with a minimal
field mask (`places.id,places.displayName,places.location,places.rating,
places.userRatingCount,places.primaryType`) to stay in the cheapest SKU
tier, `maxResultCount: 20`, a fixed **2km** radius (no radius picker in
v1 — easy follow-up, not built now), and no `includedTypes` restriction
(all types together, per the approved design). Same `.timeout(8s)` /
`GeocodingException`-style wrapping as the existing geocoder — a pure
`parseSearchNearby(String body)` parser, unit-tested against fixture JSON,
separate from the HTTP call itself.

**"High rated" filter**, applied client-side after parsing:
`rating >= 4.0 && userRatingCount >= 5`, then sorted by rating descending,
distance ascending as tiebreaker (reusing the haversine helper already in
`domain/place_sort.dart` — `placeDistanceFromKm` takes a `Place`, so a
small overload/adjacent function taking raw lat/lng is added there for
`NearbyPlaceResult`, not duplicated logic).

**Category mapping**: a `nearbyCategoryFor(String? primaryType) ->
PlaceCategory?` pure function (`domain/place_sort.dart` or a new
`domain/nearby_place.dart`) maps a handful of common Google types
(`restaurant`, `cafe`, `bar`, `museum`, `tourist_attraction`, `lodging`,
`amusement_park`, `beach`, `shopping_mall`, `park`) to the existing
`PlaceCategory` enum; anything unmapped is `null` (uncategorized), never
a guess.

### 3. Cache

A session-scoped, in-memory cache in a new
`nearbyPlacesCacheProvider` (plain `Provider` holding a
`Map<String, ({DateTime fetchedAt, List<NearbyPlaceResult> results})>`,
keyed by lat/lng rounded to 3 decimal places, ~110m — fine-grained enough
that "near me" and "near this hotel" don't collide, coarse enough that GPS
jitter within the same spot still hits). TTL **1 hour**, checked before
calling `searchNearby`; a hit returns the cached list without touching
the network or the call counter. Deliberately **not persisted** —
SharedPreferences/Drift would add real complexity (serialization,
eviction) for a guard whose job is "don't double-charge a browsing
session," which an in-memory cache already does; a killed-and-reopened
app is a fresh session and a fresh budget, same as today's `Provider`-based
`placesMapModeProvider`.

### 4. Entry point & anchor picking

Both `PlacesScreen` and `TripPlacesTab` get a new `IconButton`
(`Icons.travel_explore`, tooltip "Find nearby") in the existing
`AppBar.actions` row (next to the map-toggle/filter/add buttons already
there), **only rendered when `nearbyPlacesEnabledProvider` is true**.
Tapping it opens a bottom sheet (new `showNearbyAnchorSheet`,
`lib/features/places/presentation/nearby_anchor_sheet.dart`) with two
tiles:

- **"Near me"** — uses `currentLocationProvider` (already fetched
  proactively on these screens); if unavailable
  (`LocationUnavailable`/still loading), the tile is disabled with the
  same denial-reason copy `PlaceDistanceSortStatus` already renders
  elsewhere, not duplicated new strings.
- **"Near a saved place"** — opens a second, simple list sheet of the
  current screen's places filtered to `hasLocation` (that trip's places
  for `TripPlacesTab`, all places for `PlacesScreen`); tapping one is the
  anchor.

Either choice pushes `NearbyPlacesScreen(anchorLat, anchorLng, tripId:
trip?.id)` (new file, `presentation/nearby_places_screen.dart`).

### 5. Results screen, detail sheet, and adding

`NearbyPlacesScreen`: an `AppBar` plus a pull-based "Find nearby" primary
button (explicit, per §5.10 — no auto-fetch on screen open, no
refetch-on-anything). On tap: checks cache, else calls
`NearbyPlacesFetcher.searchNearby` (incrementing the call counter),
applies the rating filter/sort, and renders results as `PaperCard` rows
(name, category icon via `nearbyCategoryFor`, star rating +
`userRatingCount`, distance via the shared haversine helper). States:
loading (inline spinner, button disabled), empty results (`EmptyState`,
"No highly-rated places found nearby"), network/offline failure
(`ErrorState` with retry) — never a hanging spinner, per CLAUDE.md hard
rule 4.

Tapping a row opens a detail bottom sheet (name, category, rating,
distance, plus an editable name field and, when the trip has dates, the
day picker from §6 below). On open, it lazily calls
`placeSummaryFetcherProvider.fetchSummary(name: ..., lat: ..., lng: ...)`
— the same `WikipediaPlaceSummaryFetcher` already used by the manual add
flow, no new fetcher or network boundary. While pending: a small inline
spinner under the rating row. If it resolves to `null` (offline, no
match) that section simply doesn't render — no error copy, matching the
fetcher's existing "never surfaces as an error" contract.

"Add to wishlist" button in the same sheet calls
`PlaceRepository.createPlace(...)` (status defaults to `wantToGo`,
`tripId` passed through when the anchor sheet was opened from
`TripPlacesTab`) — a normal `Place`, exactly like the manual flow, and
**no rating/`primaryType` is persisted onto `Place`** (transient
discovery signal, not wishlist data — avoids a schema/domain change
beyond what §6 already adds). Then:

- if the Wikipedia summary already resolved while the sheet was open,
  `repo.setSummary(id, summary: thatValue)` is called directly —
  no duplicate fetch;
- otherwise the existing `unawaited(fetchAndStorePlaceSummary(...))`
  fire-and-forget call (same as `AddPlaceScreen._save()`) runs instead.

### 6. Day tag (minimal — not a revival of the withdrawn Plan tab)

`Place` gains one new nullable field, `plannedDate` (`DateTime?`) —
**no time, no ordering, no derived anchors, no new tab.** Schema:
`Places` table gets `DateTimeColumn get plannedDate =>
dateTime().nullable()()`, `schemaVersion` **14 → 15**, `onUpgrade` gets
one `addColumn` step following the exact v12/v14 pattern already in
`app_database.dart`. `places_migration_test.dart` gets a v14→v15 case
(old-shaped table survives, existing rows read back `plannedDate ==
null`) plus a multi-version-jump case, mirroring
`expenses_migration_test.dart`'s structure.

`Place.plannedDate` flows through `copyWith`/`==`/`hashCode` like every
other nullable field; `PlaceRepository.createPlace` gains an optional
`DateTime? plannedDate` parameter; `updatePlace` passes it through
(`Value(place.plannedDate)`), same as `visitedAt`.

**Only surfaced in the nearby-add detail sheet (§5) in this round** —
not in `AddPlaceScreen` or the general place editor. Shown only when
`trip != null && trip.startDate != null && trip.endDate != null`: a date
picker clamped to `[startDate, endDate]`. Display: wherever a place row
already renders (`PlaceRowCard`), a small mono chip reading `DAY N` when
`plannedDate` is set, computed as
`plannedDate!.difference(trip.startDate!).inDays + 1` (needs the owning
trip's `startDate`, already loaded wherever `PlaceRowCard` is used via
`tripId`/`tripNames`/`trip`). Editing or clearing the tag from the
general place editor, and exposing it for manually-added places, are
natural follow-ups, deliberately out of scope here.

## Error handling

- `nearbyPlacesEnabledProvider` off ⇒ the entry-point button is not
  rendered **and** `NearbyPlacesFetcher`/the settings-gated call sites
  never construct a real HTTP call — tested at both layers so "off"
  is a real guarantee, not just a hidden button (§5.10's own callout).
- No `MAPS_API_KEY` configured ⇒ settings switch disabled with
  explanatory copy; the entry-point button therefore never appears
  (gated on the same provider).
- `searchNearby` network/HTTP failure ⇒ `ErrorState` with retry, no
  partial/garbage list rendered.
- No results after the rating filter ⇒ distinct `EmptyState`, not
  conflated with the error case.
- Wikipedia summary failure ⇒ silent, no UI signal beyond the section
  not appearing (existing contract, unchanged).
- `plannedDate` day-picker is only offered when the trip has both dates;
  no dead-end control for undated trips.

## Testing

- `parseSearchNearby`: fixture-based parser test (well-formed response,
  missing/malformed fields, empty `places` array).
- Rating filter + sort: pure function test (`rating>=4.0 &&
  userRatingCount>=5`, sort order, empty input).
- `nearbyCategoryFor`: mapping table test, including the unmapped→`null`
  case.
- Cache: hit within 1h avoids a second fetcher call and doesn't
  increment the call counter; miss after 1h (injected clock) does both;
  different rounded coordinates are distinct cache keys.
- Call counter: increments once per real fetch, persists across a
  provider rebuild (backed by the same `SharedPreferences` fake used for
  every other settings test).
- Toggle gating: with `nearbyPlacesEnabledProvider` false, the entry
  button is absent from both `PlacesScreen` and `TripPlacesTab`, and a
  direct call into the nearby-fetch code path is a no-op/short-circuits
  before any HTTP call (mocked client asserts zero invocations).
- `NearbyPlacesScreen` widget states: initial (button, no list), loading,
  results rendered with rating/distance, empty-results, error+retry,
  offline.
- Detail sheet: Wikipedia summary loading → shown / loading → nothing
  found / not fetched until the sheet opens; adding after the summary
  already loaded calls `setSummary` directly and does **not** invoke the
  fetcher a second time (mock call-count assertion); adding before it
  resolves falls back to the existing fire-and-forget path.
- Anchor sheet: "Near me" disabled when location unavailable; "Near a
  saved place" list is scoped correctly per screen (trip-only vs. all).
- `plannedDate`: v14→v15 migration test (incl. multi-version jump); day
  picker only appears with a fully-dated trip and stays clamped to
  `[startDate, endDate]`; `PlaceRowCard` renders the `DAY N` chip
  correctly (including the boundary day-1/day-N cases) and renders
  nothing when unset.
- No test in this suite makes a real network call — `NearbyPlacesFetcher`
  and `PlaceSummaryFetcher` are both mocked at their interface boundary,
  per CLAUDE.md hard rule 5.

## Out of scope this round

- Radius selection (fixed 2km).
- Category filter chips on the nearby results screen (all types
  together, per the approved design).
- Persisting/exposing `rating`/`userRatingCount` on the saved `Place`.
- Any revival of the withdrawn Plan tab, drag-reordering, or derived
  document/place anchors — §6 is a single nullable date field and a
  read-only chip, nothing else.
- Editing or clearing `plannedDate` from `AddPlaceScreen` or the general
  place editor, or setting it for manually-added places.
- A radius/result-count picker in Settings, or a reset button for the
  call counter.
- Persisting the nearby-results cache across app restarts.
