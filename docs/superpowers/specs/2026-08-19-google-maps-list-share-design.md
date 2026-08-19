# Google Maps list share

Status: approved, not yet implemented.

## Problem

Sharing a Google Maps link into Tripper only ever produces one place
(`MapsLinkService.expand` → `MapsLink` → `AddPlaceScreen`, prefilled). When
the shared link is actually a Google Maps **list** (a saved collection —
"Want to go", "Japan", any custom list, shared via Maps' "Share list"),
today's parser either mis-parses it as a single place or drops its content
entirely — only the first place a user manually adds from it survives.

Confirmed against a real shared list link during design: a list share's
short link (`maps.app.goo.gl/...`) resolves via HTTP redirect to
`https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2!2s<opaque-id>!3e3` —
an opaque share token, not coordinates. Unlike a single place (whose
resolved URL embeds `@lat,lng` directly, parseable with a pure HTTP client),
a list's contents only exist once Google Maps' JavaScript runs and fetches
them client-side — confirmed by fetching that URL with a plain HTTP client
(both a mobile and a desktop User-Agent): no place data is present in the
raw HTML either way. Loading the same URL in a real browser shows the
places (name, rating, category) rendered into the sidebar, but the list is
virtualized — only ~20 of a 43-place list render before scrolling — and no
per-item link or DOM attribute carries coordinates, only name/rating/type
text.

This spec covers reading all of a shared list's places into Tripper, not
just the first one.

## Design

### 1. Detection (`lib/core/sharing/maps_link.dart`)

A list share is distinguishable immediately after redirect resolution, with
no rendering required: a single-place redirect lands on
`/maps/place/<name>/@lat,lng,z`; a list redirect lands on
`/maps/@/data=!...!11m2!2s<id>!3e3!...` — no `/place/` segment.

```dart
bool isMapsListShareUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return uri.path.startsWith('/maps/@/data=') &&
      uri.path.contains('!11m2!2s') &&
      uri.path.contains('!3e3');
}
```

`MapsLinkService.expand(String text)` changes return type from
`Future<MapsLink?>` to `Future<MapsShareResult?>`, a sealed result:

```dart
sealed class MapsShareResult {}

class MapsPlaceShare extends MapsShareResult {
  MapsPlaceShare(this.link);
  final MapsLink link;
}

class MapsListShare extends MapsShareResult {
  MapsListShare({required this.url, this.nameGuess});
  final String url;          // resolved list URL, handed to the scraper
  final String? nameGuess;   // surrounding share text, e.g. "Check out my list! <link>" — best-effort, often null
}
```

`expand()` keeps its existing short-link redirect-following and offline
fallback exactly as today, then checks `isMapsListShareUrl` on whatever URL
it ends up with (resolved short link, or the original URL if it wasn't
short) before doing today's coordinate/name parsing. A list match returns
`MapsListShare` immediately, skipping coordinate extraction (there are
none to find). Everything else returns `MapsPlaceShare(existing MapsLink
logic, unchanged)`.

Callers (`app_shell.dart`, the new paste dialog in §5) switch on the
sealed result to route to the right screen.

### 2. Scraping (new `lib/core/sharing/maps_list_scraper.dart`)

Behind an interface, matching the existing fake-at-the-boundary pattern
(`Geocoder`, `PlaceRepository`):

```dart
abstract interface class MapsListScraper {
  Future<ScrapedMapsList?> scrape(String listUrl);
}

@immutable
class ScrapedMapsList {
  const ScrapedMapsList({required this.title, required this.placeNames});
  final String? title;
  final List<String> placeNames;
}
```

`WebViewMapsListScraper` (real implementation, adds the `webview_flutter`
dependency — not currently in `pubspec.yaml`):

- Appends/replaces `hl=en` on the list URL before navigating, so scraped
  text is in Latin script regardless of the user's Google account locale.
- Needs a mounted `WebViewWidget` to run (Flutter/Android constraint — a
  WebView cannot execute off-tree). Implementation hosts it on a transient,
  fully-transparent, non-interactive route pushed just for the scrape and
  popped as soon as it finishes or times out — never visible to the user,
  no navigation-stack side effect beyond its own push/pop.
- After `onPageFinished`, runs an injected JS scroll-and-collect loop
  against the place-list panel: scroll, read currently-visible place name
  text nodes, dedupe into a running set, repeat. Stops when two consecutive
  iterations add nothing new, or at a 30-iteration / 20-second cap,
  whichever comes first — the cap exists so a layout Google ships that
  breaks the selectors degrades to "found fewer than expected" or "found
  none" rather than spinning.
- Google's DOM structure is unstable/obfuscated and not a stable contract
  Tripper can rely on long-term. The JS must be defensive (never throw on
  a missing element) and the Dart side treats any exception, timeout, or
  empty result as scrape failure (`null`), not a crash — this is explicitly
  the most fragile piece of the feature.
- List title comes from `document.title`, trimmed of Google's known
  " - Google Maps" suffix (present because of the forced `hl=en`); falls
  back to `nameGuess` from `MapsListShare`, then to a generic "Imported
  list" string if both are empty.

### 3. Geocoding

Neither geocoding backend this app uses supports batching distinct
queries into one HTTP call — confirmed during design: the public
Nominatim API explicitly disables its batch-query mode (self-hosted-only
feature), and Google's Geocoding/Places APIs are one-address-per-request.
A third-party bulk geocoder (Geoapify, Stadia Maps) would fix that, but
means a new provider/key/pricing model — out of scope here, given the
existing `Geocoder` abstraction is deliberately keyless-Nominatim-first.

So calls stay one-per-place, with one free optimization applied first:
scraped names are **deduplicated** (case-insensitive trim) before
geocoding — a list with repeated entries only geocodes each unique name
once, and every place row sharing that name reuses the single result.

The (deduplicated) names are then resolved through the **existing**
`Geocoder.search()` — the same call `AddPlaceScreen`'s manual search
already makes — run sequentially (not in parallel: Nominatim's usage
policy forbids bursts) with a small inter-call delay. The import screen
(§4) shows live progress ("12 / 43 located") while this runs
synchronously, since a large list takes real time — an explicit progress
state, not a spinner masking a long wait. Cancelling mid-geocode writes
nothing, per Error handling below.

A name that fails to geocode (offline, no match, ambiguous) is still
imported — name-only, no coordinates — matching the existing "locate
later" precedent for an offline single-place short-link share. It does not
block the rest of the batch.

### 4. Import UI (new `lib/features/places/presentation/maps_list_import_screen.dart`)

`MapsListImportScreen(url, nameGuess)`:

- On open, calls `MapsListScraper.scrape(url)`. States: scraping (progress
  copy, e.g. "Reading list…"), failed/empty (message + close — see §6),
  success (review UI below).
- Review UI: scraped title as an editable text field (becomes the new
  collection's name), a checklist of scraped place names — all checked by
  default, each removable — and an optional trip picker (same `ChoiceChip`
  row pattern as `AddPlaceScreen`), applied to every place in the batch.
- Confirming ("Import N places"): geocodes the checked names (§3, with
  progress), creates each via the existing `PlaceRepository.createPlace`
  (`tripId` from the picker, empty notes — no provenance text; see "Out of
  scope this round"), then creates one new `PlaceCollection` via the
  existing `PlaceCollectionRepository.createCollection(name: <edited
  title>)` and calls `setCollectionsForPlace` for every created place —
  reusing the Lists feature already visible in `AddPlaceScreen` and the
  Places tab, not a new concept.
- Cancel at any point writes nothing — no partial collection, no partial
  places.

### 5. Manual entry point (`places_screen.dart`)

The "+" `IconButton` in `PlacesScreen`'s `AppBar.actions` (today: single
tap → `AddPlaceScreen.open`) becomes a `PopupMenuButton` with two items:

- **Add place** — today's behavior, unchanged.
- **Import Google Maps list…** — opens a small dialog with one URL text
  field. Submitting runs the pasted text through the same
  `MapsLinkService.expand()` → `MapsShareResult` pipeline the share-intent
  flow uses (§1): a pasted single-place link opens `AddPlaceScreen`
  prefilled exactly as today; a pasted list link opens
  `MapsListImportScreen`. No parsing logic is duplicated between the
  share-intent and paste paths.

### 6. Wiring (`app_shell.dart`)

The share listener's text-share branch, currently:
`MapsLinkService.expand()` → enrich → `AddPlaceScreen.open`, becomes a
switch on the sealed `MapsShareResult`:

- `MapsPlaceShare` → today's enrich-and-open-`AddPlaceScreen` path,
  unchanged.
- `MapsListShare` → `navigationShell.goBranch(2)` then push
  `MapsListImportScreen(share.url, share.nameGuess)`.

## Error handling

- Non-maps text/links: unchanged (`expand()` still returns `null`).
- List scrape failure, timeout, or zero places found: `MapsListImportScreen`
  shows a message ("Couldn't read this list from Google Maps — try sharing
  individual places instead") with a close action — never a hanging
  spinner, per CLAUDE.md hard rule 4.
- Individual geocode failure inside an otherwise-successful scrape: that
  one place imports name-only; the rest of the batch is unaffected.
- Cancelling the import screen at any stage (during scrape, during review,
  during geocode/create) writes nothing to the database.
- Offline for the entire flow: scraping requires network (it's loading a
  live Google page) — offline surfaces as the same "couldn't read this
  list" failure state, immediately rather than after a long timeout where
  detectable (WebView navigation error), otherwise after the existing
  20s/30-iteration cap.

## Testing

- `isMapsListShareUrl`: unit tests against the real captured example
  (`/maps/@/data=!3m1!4b1!4m3!11m2!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3`),
  a single-place URL (must be `false`), and non-maps URLs.
- `MapsLinkService.expand()`: existing single-place test cases updated to
  match on `MapsPlaceShare`; new cases for a list-shaped redirect target
  (mocked via the same `MockClient.streaming` pattern already in
  `maps_link_test.dart`) returning `MapsListShare` with the resolved URL.
- `MapsListImportScreen` and the geocode-and-create flow: widget-tested
  against a `FakeMapsListScraper` (canned `ScrapedMapsList`) and a mocked
  `Geocoder`/`PlaceRepository`/`PlaceCollectionRepository`, per CLAUDE.md
  hard rule 5 (repository-boundary mocking). Covers: scraping state,
  failure/empty state, review checklist (toggle items, edit title), import
  progress, successful create (right places, right trip, right new
  collection with all imported places as members), and cancel-writes-nothing
  at each stage.
- Dedupe: a scraped list with repeated (including differently-cased/
  whitespace-padded) names calls the mocked `Geocoder` exactly once per
  unique name, and every matching place row gets that result.
- Manual paste dialog: submitting a single-place URL routes to
  `AddPlaceScreen`; submitting a list URL routes to `MapsListImportScreen`;
  submitting garbage text shows an inline error, no navigation.
- `app_shell.dart` share-listener routing: a `MapsPlaceShare` share still
  opens `AddPlaceScreen` (regression coverage for the existing behavior);
  a `MapsListShare` share opens `MapsListImportScreen` on the Places tab.
- **Not unit-testable**: `WebViewMapsListScraper`'s real JS-injection
  scraping against a live Google Maps page. This is flagged explicitly, not
  silently skipped — verified manually only, consistent with this
  project's existing "Claude cannot run Flutter" constraint (CLAUDE.md
  Verification section). The interface boundary (§2) exists specifically
  so everything else in this feature stays unit/widget-testable without it.

## Out of scope this round

- Any provenance marker on imported places beyond collection membership —
  no notes text, no schema change.
- Editing which places are in the auto-created collection after import
  completes (use the existing Lists UI for that afterwards).
- Merging into an existing collection instead of always creating a new one.
- Retrying a failed/partial scrape automatically, or resuming a
  partially-reviewed import.
- Any caching of scraped list contents (a re-share or re-paste always
  re-scrapes).
- Handling Google Maps lists shared via any mechanism other than the
  `maps.app.goo.gl` / `google.com/maps` link shape already covered by
  `_isMapsHost`.
