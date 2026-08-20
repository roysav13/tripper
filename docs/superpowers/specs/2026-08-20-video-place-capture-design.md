# Video place capture — design

**Status:** proposed, pending user review
**Depends on:** M3 (places — search, save flow, Wikipedia summary), core sharing (`share_intent_service.dart`, `maps_link.dart`)

## 1. What this is

Share a TikTok video to Tripper → pick a frame where the on-screen text
names a place → OCR that frame → resolve the place (Wikipedia first,
Google Places fills whatever Wikipedia didn't have) → review → save as
a wishlist place, exactly like any other place in the app.

## 2. Scope

**v1 covers TikTok only.** Instagram Reels' public pages increasingly
require a logged-in session even to view, making the extraction step
far less reliable; TikTok's public video pages embed the data needed
without a login wall. Instagram is deliberately deferred to a later
pass once the TikTok pipeline is proven, not built in parallel with
it.

**Non-goals for v1:**
- Instagram or any platform besides TikTok
- Saving the source video itself into the app (vault or otherwise) —
  only a single still frame is ever kept, and only transiently until
  OCR runs
- Trimming/editing the video
- Any change to the existing manual add-place or Maps-link-share
  flows — this is a new, parallel entry point into the same save path

## 3. Risk context (read before implementing)

A related feature — importing a shared Google Maps **list** by
scraping its page via a `webview_flutter` WebView — was fully built
and then fully reverted (`84ac975`, 2026-08-20) after repeated
on-device failures: the WebView unpredictably hit Android's offline
page instead of the real site, and separately the share-link detection
that was supposed to route into it silently failed to match a real
captured link. The lesson recorded from that effort: don't re-apply
"scrape a third-party page" as a design without treating it as
inherently fragile — isolate it, expect it to fail often, and never
let its failure cascade into anything else breaking.

This feature repeats that same category of risk deliberately, with
eyes open (a fully offline-safe alternative — using TikTok's official
`oembed` endpoint for caption text + one cover thumbnail, no scraping
— was considered and explicitly declined in favor of full video
scrubbing). The design below leans hard on isolating the fragile part
into one small, replaceable service with no callers depending on its
internals, per §5.2.

## 4. Pipeline

```
Share sheet (TikTok link)
  → TikTok link detected (text share, new alongside Maps-link detection)
  → TikTokVideoLinkService: resolve short link → real video page →
     extract direct .mp4 URL from the page's embedded JSON
  → download .mp4 to a temp file
  → VideoFrameCaptureScreen: video_player scrub bar, pause anywhere,
     "Capture" grabs a still frame via video_thumbnail at that position
  → OCR the still frame (google_mlkit_text_recognition, already a
     dependency) → recognized text shown in an editable field
  → user edits/confirms candidate place name text
  → PlaceCandidateResolver:
      1. Wikipedia lookup by name (existing WikipediaPlaceSummaryFetcher,
         extended to also read the `coordinates` field the REST summary
         response already carries when present)
      2. Whatever Wikipedia didn't supply is filled from Google Places:
         - Wikipedia had coordinates but no city/country → reverse-geocode
           those coordinates (existing GooglePlacesGeocoder.reverse)
         - Wikipedia had no coordinates → forward-search Places by name
           (existing GooglePlacesGeocoder.search + .details)
         - Wikipedia found nothing → Places is the sole source
  → Review card: name, summary, resolved location — user's actual
    decision point ("only if I decide to add")
  → Confirm → same save path every place already uses (Place.summary/
    summaryFetchedAt, lat/lng, city, country — no schema change)
```

## 5. Components

### 5.1 Share-intent routing (small, safe)
`share_intent_service.dart`'s existing text-share path currently only
recognizes Maps links. Add a TikTok URL matcher (`tiktok.com`,
`vm.tiktok.com`, `vt.tiktok.com` hosts) alongside `isShortMapsLink`,
routing to the new capture screen instead of `AddPlaceScreen`. Pure
function, unit-tested the same way `parseMapsShare` is.

### 5.2 `TikTokVideoLinkService` — the fragile, isolated part
Resolves a shared link to a direct, downloadable `.mp4` URL:
1. Follow redirects for short links (`vt.tiktok.com`/`vm.tiktok.com`),
   reusing the same redirect-following approach as
   `MapsLinkService._resolveRedirects`, including a browser-like
   `User-Agent` header (same precedent — TikTok's page rendering
   depends on client type same as Google's does).
2. Fetch the resolved video page's HTML.
3. Extract the `__UNIVERSAL_DATA_FOR_REHYDRATION__` (or equivalent)
   embedded JSON script tag and pull the playable video URL out of it.

This is undocumented and will break whenever TikTok changes its page
structure — that's accepted (§3). Isolation contract: this service has
exactly one method (`Future<Uri?> resolveVideoUrl(String sharedText)`,
returns `null` on any failure — bad markup, missing fields, network
error, non-200 — never throws) and nothing downstream knows *why* a
capture failed, only that it did. No other component parses TikTok's
page shape.

### 5.3 Video download
Plain `http.Client` GET to a temp file (`path_provider` temp dir,
same pattern as PDF rasterization in `PdfxPageRasterizer`). Streamed
to disk rather than held in memory — Reels-length video, not huge, but
no reason to buffer fully in RAM.

### 5.4 `VideoFrameCaptureScreen`
New dependencies: `video_player` (scrub/playback) and `video_thumbnail`
(actual frame rasterization — `video_player` has no frame-grab API, so
"capture" re-derives a still image from the local file at the
controller's current position via `video_thumbnail`, decoupled from
the live player widget but pointed at the same timestamp). UI: a
standard video scrub bar (play/pause/seek), a "Capture this frame"
button. No trimming, no multi-frame capture — one still image per
attempt, re-capturable if OCR comes back empty or wrong.

### 5.5 OCR
Reuses `google_mlkit_text_recognition` (already a dependency via the
document-OCR path, M5.4) against the captured still image. New thin
service mirroring `DocumentTextRecognizer`'s interface pattern —
recognition failure degrades to `''`, never an error. Output goes into
a plain editable `TextField`, pre-filled but never auto-submitted —
same "double-check before saving" precedent M5.4 established, and
arguably more important here: burned-in video captions are a harder
OCR target (motion blur, stylized fonts, busy backgrounds) than the
document scans M5.4 already found unreliable for non-passport text.

### 5.6 `PlaceCandidateResolver`
New orchestration function, distinct from the existing
`fetchAndStorePlaceSummary` (which runs post-save, fire-and-forget,
for every place regardless of entry path). This one runs **before**
save, synchronously from the user's perspective (with a loading
state), because its output has to be reviewable before the user
decides whether to add.

Extends `WikipediaPlaceSummaryFetcher`/`PlaceSummaryFetcher`: the REST
`page/summary` response already carries a `coordinates: {lat, lon}`
field when the article has one; `parseWikipediaSummary` today discards
everything but `extract`. Add a sibling parse (or broaden the return
type to a small record `{summary, lat, lon}`) so one Wikipedia call
yields both pieces without a second request. `NoopPlaceSummaryFetcher`
gets the equivalent no-op extension so tests/offline stay unchanged.

Fallback rules exactly as in §4 — Places only fills fields Wikipedia
didn't provide, never overwrites what Wikipedia already resolved.

### 5.7 Review card → save
Shows resolved name, summary, and location (map pin or "no location
found" state) with a confirm/cancel choice. On confirm, saves via the
same repository path every other place uses — `Place.summary` /
`summaryFetchedAt` are set directly from the already-fetched Wikipedia
result (no redundant re-fetch on save, unlike the manual/Maps-link
paths which fetch post-save because they never had this data
pre-save).

## 6. Data model

**No schema changes.** Every field this feature produces
(name/summary/summaryFetchedAt/lat/lng/city/country) already exists on
`Place`. This is purely a new input path into existing storage.

## 7. Error handling & offline (CLAUDE.md hard rule 4)

| Step | Failure mode | Behavior |
|---|---|---|
| Link resolve / video-URL extraction | TikTok page shape changed, redirect chain broken, offline | Plain "couldn't fetch this video" state, no retry loop; user can still add the place manually via the normal Places tab |
| Video download | Network drop mid-download | Same as above; partial temp file discarded |
| OCR | Recognizer failure/no text found | Editable field stays empty — user can retype or re-capture a different frame; never blocks |
| Wikipedia lookup | Offline, no match, malformed response | Silently yields no summary/coordinates — falls through to Google Places exactly as if Wikipedia had nothing (same code path, not a special case) |
| Google Places lookup | Offline, no API key configured, no match | Review card shows whatever was resolved (possibly just the name) with an explicit "no location found" state — same pattern `AddPlaceScreen` already uses for "add without location" |

Every network step in this pipeline is enhancement over a manual
fallback that already exists (type the name yourself in the normal
Places tab) — none of it gates access to anything the app already
has.

## 8. Testing

- `TikTokVideoLinkService`: unit tests against a fake `http.Client`
  with fixture HTML (real-shaped extraction, malformed/changed JSON,
  redirect loop, non-200, offline) — mirrors how
  `google_places_geocoder_test.dart`/`maps_link_test.dart` test their
  own parsers today
- Share-intent TikTok-link detection: pure function unit tests
  alongside the existing `parseMapsShare` tests
- `PlaceCandidateResolver`: unit tests over fakes for both fetchers —
  Wikipedia-has-both / Wikipedia-coords-only / Wikipedia-nothing /
  both-fail cases, asserting Places is never called for a field
  Wikipedia already supplied
- Extended Wikipedia coordinate parsing: fixture-JSON unit tests
  alongside the existing `parseWikipediaSummary` tests
- `VideoFrameCaptureScreen` / OCR service: widget tests mock both the
  video-fetch and OCR boundaries — never a real plugin or network call
  in tests, consistent with every other ML-Kit/plugin test in the repo
- Review card: widget tests for all-resolved / partial / nothing-
  resolved render states, and that confirm saves via the same
  repository call every other place-save path uses

## 9. Open questions / explicitly deferred

- Instagram support — separate pass once TikTok's pipeline is proven
  on real devices (§2)
- No retry/backoff policy for the TikTok extractor beyond "fail once,
  let the user try sharing again" — revisit only if real usage shows
  it's worth it, per YAGNI
- Whether to cache a successfully-resolved `.mp4` URL (same shared
  link, re-opened) — not needed for v1, each share is a fresh capture
