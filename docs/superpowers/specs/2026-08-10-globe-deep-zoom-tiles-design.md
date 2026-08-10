# Globe real deep zoom via network-fetched satellite tiles

Status: approved, not yet implemented. Follow-up to
`2026-08-09-globe-tiered-zoom-texture-design.md` and
`2026-08-10-globe-zoom-and-clustering-design.md` (both shipped) — those
established a safe 2-tier bundled-texture ladder (4000×2000 base,
8000×4000 past `zoom > 1.5`) and pushed `maxZoom` to 5. This spec is
about going meaningfully further: genuine close-up detail, not just a
sharper whole-Earth image.

## Problem

At `maxZoom: 5` the sphere renders at ~113x its resting size. For the
current 8000px-wide texture to stay crisp at that zoom needs roughly one
texture pixel per screen pixel — which works out to a texture around
22000×11000px (~240MP), almost exactly the resolution of the 21600×10800
source that already proved undecodable on-device earlier this session
(never finishes decoding, globe silently never renders — see
`third_party/flutter_earth_globe/PATCHES.md`). A single bundled
whole-Earth image sharp enough for real close-up zoom is fundamentally in
the same size range that already crashed this app once.

Getting genuinely more detail — not just avoiding that crash, but
actually seeing more than today's 8000×4000 texture contains — requires
more source resolution than any single practical bundled file can safely
hold, at any zoom level. That's what real tile-based imagery is for: a
huge total dataset (this design uses ~3.7 gigapixels of source data), of
which only a small covering piece is ever decoded at once.

## Why network, not bundled tiles

NASA's public Blue Marble "Full Resolution (500m)" imagery — the same
public-domain family this app's existing textures are sourced from (see
`assets/globe/README.md`) — is published as 8 tiles (a 4×2 grid, A1–D1 /
A2–D2), each 21600×21600px. Combined, that's ~86400×43200px of source
detail, more than the entire local storage budget a normal app can
reasonably claim. Bundling any meaningful fraction of it offline was
considered and rejected: even a modestly-downsampled full-globe subset
doesn't get close to genuine close-up detail without ballooning the
APK far past what's reasonable for a travel app people install on a
whim.

The alternative — and what this design uses — is **NASA's own GIBS
service**, a free, public, no-API-key WMTS tile server that already
serves exactly this imagery in standard `{z}/{x}/{y}` tile form, in
EPSG:4326 (plain lat/lon), matching this app's shader's equirectangular
UV mapping directly — no Mercator reprojection needed. This means: no
image processing pipeline for us to build, no tile hosting/CDN for us to
stand up and maintain, no giant one-time download. We fetch exactly the
small piece currently needed, at runtime, from an existing NASA-run
service.

**Open verification item, first implementation task:** the EPSG:3857
Blue Marble layer name (`BlueMarble_ShadedRelief_Bathymetry`) and URL
pattern were confirmed directly
(`https://gibs-{s}.earthdata.nasa.gov/wmts/epsg3857/best/BlueMarble_ShadedRelief_Bathymetry/default//EPSG3857_500m/{z}/{y}/{x}.jpeg`).
EPSG:4326 support is confirmed to exist at GIBS generally
(`https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/{Layer}/default/{Time}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.{Ext}`,
extent `-180,-90` to `180,90`, WGS84), but the exact layer identifier and
`TileMatrixSet` name for Blue Marble under EPSG:4326 specifically was
not confirmed — GIBS's full capabilities XML is too large to reliably
parse via a documentation fetch. The first implementation task fetches
the live `GetCapabilities` document (or probes a candidate tile URL
directly) and locks in the exact identifier before anything else is
built against it. If Blue Marble specifically isn't available under
EPSG:4326, the nearest equivalent true-color basemap layer GIBS does
offer under EPSG:4326 is an acceptable substitute — the rest of this
design doesn't depend on the exact layer name.

## CLAUDE.md compliance (explicit design constraint, not an afterthought)

This is the first network call in the app's history that isn't
search/geocoding/parsing-adjacent, so it's worth being explicit about
how it satisfies rule 4 (local data is always the source of truth;
network may enhance a core flow but never gate access to data already on
the device, and must degrade visibly and gracefully):

- The globe's bundled tiers (4000×2000, 8000×4000) remain fully
  sufficient on their own — nothing about the globe's core function
  (showing this trip's entries, at up to `maxZoom: 5`) depends on
  network access. Deep-zoom tiles only ever add detail on top of an
  already-fully-functional globe.
- Trip/journal data itself — the actual thing rule 4 is protecting — is
  entirely untouched by this feature. This only touches decorative
  background imagery past a zoom level most sessions will never reach.
- Every failure mode (no connection, timeout, GIBS unavailable, a decode
  error) results in silently keeping whatever texture is already
  loaded — never a spinner, never an error state, never a retry loop
  the user can get stuck in. The user sees either "sharper" or "the same
  as before," never "broken" or "waiting."
- Per rule 5, network calls go through a boundary abstraction that
  integration tests mock explicitly — no test in this codebase will ever
  hit a real GIBS endpoint.

## Design

### 1. Trigger

`maxZoom` raised from `5` to `8` (~256x). A new
`tileZoomThreshold = 6.0` gates deep-zoom tile fetching — chosen to sit
above the existing `highResGlobeZoomThreshold` (1.5) and the existing
`maxZoom` (5) that was tuned for the bundled 8000×4000 tier's own
softening point, so bundled tiers still cover the whole range they were
designed for; tiles only kick in past where that tier's own detail runs
out. Starting value for on-device tuning, like every other zoom constant
in this file.

### 2. Viewport → tile coordinates

A new pure function, `List<TileCoordinate> tilesCoveringView({required double centerLat, required double centerLng, required int gibsZoomLevel})`, computing which GIBS tile row/columns cover a small grid around the given center at the given GIBS zoom level (standard WMTS tile-matrix math: at zoom level Z, the EPSG:4326 tile grid is `2 * 2^Z` columns × `2^Z` rows covering the full `-180..180` / `-90..90` extent — GIBS's EPSG:4326 tile matrix is 2 tiles wide at Z=0, consistent with the 2:1 aspect ratio of an equirectangular projection). Fetches a small grid (e.g. 2×2 or 3×3) centered on the view, not just the single containing tile, so the composited patch has margin before the next re-fetch is needed. Globe zoom (`controller.zoom`, range up to 8) maps to a GIBS `TileMatrix` level via a simple, documented formula tying the two zoom scales together (exact mapping finalized once the real TileMatrixSet's level count/resolution is confirmed — see the open verification item above).

Pure function, no network/IO — unit-testable directly.

### 3. Fetch

`GlobeTileFetcher` (new class) wraps `package:http`'s `Client` behind an
interface (`GlobeTileSource`) the compositor depends on, so tests inject
a fake instead of a real `http.Client`. Fetches each needed tile's JPEG
bytes with a bounded timeout (e.g. 5 seconds) — a slow connection fails
fast into the fallback path rather than hanging.

### 4. Local disk cache (this round's addition — keep fetched tiles for reuse)

Before fetching anything over network, check a local cache first;
after a successful fetch, write the tile bytes there before using them.
Cache location: `getTemporaryDirectory()` (via `path_provider`, already
a dependency) — the same "OS-clearable, disposable, re-derivable"
semantics already used for OCR scratch data in
`document_ocr_service.dart`, appropriate here since every cached tile is
trivially re-fetchable and holds no user data. Cache key: the tile's
`{layer}/{z}/{x}/{y}.jpg` path, mirrored as a subdirectory structure
under the cache dir. A capped total size (e.g. 200MB) with simple
least-recently-used eviction (track last-access time per file,
sweep-and-delete oldest when the cap is exceeded) keeps this bounded
across a long-lived app installation without needing a database —
re-visiting a previously-viewed region works fully offline the second
time, matching the ask directly ("keep the tiles locally for reuse
without exhausting my data").

### 5. Composite

Once the covering tiles (from cache or freshly fetched) are decoded,
draw them onto a canvas sized and positioned to match their equirect
coordinates, sampling/blending with the currently-loaded base texture
where the new tiles don't fully cover the frame, producing one `ui.Image`
— fed through the *existing* `FlutterEarthGlobeController.loadSurface()`
call, the exact mechanism the 2-tier system already uses. No shader
changes needed; from the rendering pipeline's perspective this is just
another `loadSurface()` call with a differently-sourced image.

### 6. Re-trigger on pan/rotate, not just zoom

Unlike the existing 2-tier system (which only reacts to `zoom` crossing
a threshold), tiles depend on *where* the camera is centered, not just
how far zoomed. Re-composite is triggered when the centered lat/lng
drifts far enough from the last-fetched center (a simple distance
threshold, reusing the haversine helper already added for
`groupEntriesByProximity` in `journal_entry_queries.dart`) — not on
every rotation frame, to avoid re-fetching/re-compositing continuously
during an active drag gesture.

## Error handling

Every step (cache read, network fetch, decode, composite) is wrapped so
a failure anywhere in the chain falls back to silently keeping whatever
texture is currently loaded — consistent with the CLAUDE.md compliance
section above. Failures are `debugPrint`-logged (matching this session's
established pattern for surfacing otherwise-silent failures during
development) but never surfaced to the user as an error state.

## Testing

- Tile-coordinate math (`tilesCoveringView` and the zoom-level mapping)
  is pure — unit-tested directly, no network/IO dependency.
- The cache's eviction logic (given a set of files with known
  last-access times and a size cap, which ones get deleted) is pure
  enough to unit-test against a temp directory fixture.
- Fetch+composite behavior is tested against a fake `GlobeTileSource` —
  covering both the success path (fake returns tile bytes, verify the
  resulting composite request reaches `loadSurface`) and the failure
  path (fake throws/times out, verify the existing texture is left
  untouched, no exception propagates) — per CLAUDE.md rule 5, no test
  hits a real GIBS endpoint.
- The actual visual/GPU result (does the composited patch look right on
  the sphere) is manual-verification-only, consistent with every other
  GPU-rendering-dependent change in this file.

## Out of scope this round

- CPU-fallback rendering path support for deep-zoom tiles (GPU path
  only — the CPU fallback already has its own established limitations
  documented in `PATCHES.md`, and is a smaller slice of real devices).
- Continuous pan-following prefetch / smooth cross-fade between tile
  updates (start with fetch-on-settle: re-composite once the camera
  stops moving past the drift threshold, not a continuously-streaming
  view).
- Other GIBS layers (seasonal variation, night lights, weather overlays)
  — base true-color imagery only.
- A user-facing setting to disable tile fetching (e.g. "Wi-Fi only") —
  worth considering later if the local cache alone doesn't feel
  sufficiently data-conscious in practice, but not blocking this round.
