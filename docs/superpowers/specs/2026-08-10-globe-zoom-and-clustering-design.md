# Globe deeper zoom + reduced marker collisions (dot tuning + clustering)

Status: approved, not yet implemented. Follow-up to
`2026-08-09-globe-tiered-zoom-texture-design.md` (shipped) — that feature
made the globe's texture sharp enough at higher zoom to make "how far can
I actually zoom" and "entries logged close together are unreadable" the
next visible issues.

## Problem

1. `maxZoom: 3.5` (~11x) is the same cap chosen when the base texture was
   4000×2000; the shipped 8000×4000 tier supports meaningfully deeper
   zoom before texture softening becomes the limiting factor again.
2. Journal entries logged close together (e.g. several stops in the same
   city on the same trip) render as native `Point`s at a constant
   on-screen size (`journal_globe.dart`'s `_handleZoomChanged`
   compensates for the package's built-in zoom-scaling specifically to
   keep dots a *constant* apparent size — see that method's doc comment).
   At rest zoom, geographically close entries end up only a few screen
   pixels apart, so their dots/halos visually merge and only the
   topmost one is reliably tappable.

## Design

### 1. Zoom range

`_buildController`'s `maxZoom: 3.5` → `5` (~32x). `minZoom` (zoom-out)
unchanged. Chosen as a moderate bump matched to the 8000×4000 tier's
actual detail ceiling, not pushed to the point of visible softening —
same tuning philosophy already documented in this method's `maxZoom`
comment for the base tier.

### 2. Dot-size tuning (complementary, not a fix on its own)

Shrink the halo sizes specifically — the halo (a soft, low-alpha, larger
circle behind the core dot, see `_addPoints`'s layering comment) is the
largest element and the main driver of *perceived* overlap even before
the core dots themselves touch:

- `_haloDotSize`: `7.0` → `5.0`
- `_photoHaloDotSize`: `9.0` → `7.0`

Core dot size (`_plainDotSize`), border sizes, and photo dot diameter are
unchanged — they're the actual tap targets, and shrinking them risks a
hit-testing/accessibility regression for a purely cosmetic gain. Like
every other dot-visual constant in this file, these are starting values
for on-device tuning, not derived precisely.

This alone doesn't solve entries that are genuinely close together (a few
city blocks apart at rest zoom will still visually collide at almost any
reasonable dot size) — it reduces how often clustering has to kick in,
it doesn't replace it.

### 3. Clustering

**Algorithm.** A new pure function in `lib/features/journal/domain/journal_entry_queries.dart`
(alongside the existing `groupEntriesByDay`, matching its shape and
location):

```dart
List<List<JournalEntry>> groupEntriesByProximity(
  List<JournalEntry> entries,
  double zoom,
);
```

Located entries within a distance threshold of each other are grouped
into the same cluster; unlocated entries and single-entry clusters both
still appear in the output (a cluster of size 1 is today's existing
single-dot case — this function's output replaces the current
`for (final entry in widget.entries)` loop in `_addPoints`/`_handleZoomChanged`
wholesale, not just the "clustered" subset). Distance is great-circle
(haversine) distance between two `(lat, lng)` pairs — no existing
utility for this in the codebase, so this feature adds a small private
haversine helper alongside the new function, no new package dependency
(the formula is ~10 lines).

**Threshold curve.** `clusterThresholdKm = 50 * pow(2, -zoom)` — chosen to
track the same `2^zoom` scaling already used everywhere else in this file
for keeping on-screen sizes consistent across zoom (see
`_handleZoomChanged`'s `compensation = 1 / math.pow(2, zoom)`), so the
cluster threshold's *apparent* on-screen size stays roughly constant as
you zoom, exactly like dot sizing does — entries cluster if they'd
visually collide at the current zoom, not based on a fixed geographic
distance. At `zoom: 0` (rest), ~50km (roughly "same metro area"); at
`zoom: 5` (new max), ~1.5km. `50` is a starting value for on-device
tuning like every other constant in this section.

**Grouping is transitive-closure, not pairwise.** If A is within
threshold of B, and B is within threshold of C, all three land in one
cluster even if A and C alone exceed the threshold — matches how visual
overlap actually chains (A's halo overlapping B's overlapping C's reads
as one blob, not two separate near-misses). Implementation: for each
located entry not yet assigned to a cluster, start a new cluster and
breadth-first absorb any not-yet-assigned entry within threshold of *any*
entry already in the cluster, repeating until no more absorb.

**Cluster position.** The arithmetic mean of the cluster's member
lat/lngs (a simple centroid) — sufficient at cluster-scale distances
(tens of km at most, given the threshold curve above); no need for the
more careful spherical-centroid math that would matter at continental
scale, since points that far apart never cluster together in the first
place.

### 4. Cluster marker rendering

`_addPoints` (and `_syncPoints`'s corresponding removal loop) iterate
`groupEntriesByProximity(widget.entries, controller.zoom)` instead of
`widget.entries` directly:

- **Cluster of size 1:** unchanged — today's existing halo + border +
  dot/photo-dot rendering, using that one entry's own coordinates.
- **Cluster of size N > 1:** one marker at the cluster's centroid —
  reuses the existing halo/border layering, with the core replaced by a
  small `_ClusterDot` widget (new, in this same file, following
  `_PhotoDot`'s pattern) showing a count badge (`N`) instead of a photo
  or plain dot. `onTap` opens the presentation sheet for the whole
  cluster (see below) instead of firing `widget.onEntryTap` for a single
  entry.

Point `id`s for a cluster use a stable key derived from its sorted
member entry ids (e.g. joined with a separator) so `_syncPoints`'s
diffing (remove points from the previous entry list, add points for the
new one) keeps working the same way it does today — a cluster's identity
is "this exact set of entries," so if the set changes (an entry added,
removed, or moved out of range), the old cluster point is removed and a
new one added, same as today's per-entry add/remove.

### 5. Cluster tap interaction

Reuses `showJournalEntryPresentationSheet` unchanged — it already accepts
`entries: List<JournalEntry>` and `initialIndex` (this is exactly how
day-grouped gallery cards already open multiple entries in one sheet, see
`trip_journal_tab.dart`'s `onTapDay`). A cluster tap calls it with that
cluster's member entries and `initialIndex: 0`. No new UI surface, no
changes to `journal_entry_presentation_sheet.dart`.

### 6. Recompute triggers

`groupEntriesByProximity` is pure (entries + zoom in, clusters out), so
it's cheap to recompute — no caching needed at this scale (trips
realistically have low tens of entries, and clustering is O(n²) in the
worst case for the pairwise-distance step, trivial at that size).
Recomputed in `_syncPoints` (already triggered by `didUpdateWidget` when
entries change, via `_sameEntryIds`) and from `_handleZoomChanged` when
`zoom` crosses into a different clustering "band" — not on every
zoom-changed callback (which fires continuously during a pinch gesture),
to avoid rebuilding the points list every frame. A clustering band is a
small fixed set of zoom breakpoints (e.g. matching where the threshold
curve halves: every 1.0 zoom step) rather than recomputing on every
fractional zoom delta.

## Error handling

Unlocated entries (`!entry.hasLocation`) are excluded from clustering
input, same as today's existing `if (!entry.hasLocation) continue;` guard
in `_addPoints` — no change to that behavior. A cluster can never be
empty (it's only ever constructed by absorbing at least the entry that
started it).

## Testing

`groupEntriesByProximity` is a pure function over plain data (`JournalEntry`
list + a `double`) — unit-testable without any GPU/widget dependency,
same seam as `groupEntriesByDay`'s existing tests (if any) and this
session's `shouldRequestHighResGlobeSurface`. Cases to cover: entries far
apart never cluster regardless of zoom; entries within threshold at low
zoom but not high zoom split apart as zoom increases; transitive chaining
(A-B-C where only adjacent pairs are within threshold); unlocated entries
excluded; empty input; single entry.

The actual marker rendering (`_ClusterDot`, halo/border layering, tap
routing to the presentation sheet) stays manual-verification-only,
consistent with every other GPU-rendering-dependent change in this file.

## Out of scope

- Screen-space (pixel-accurate) clustering using the vendored package's
  internal per-frame point positions (`RotatingGlobeState._pointRenderData`)
  — rejected in favor of geographic-distance clustering to avoid a second
  dependency on non-public package internals; revisit only if the
  geographic approximation looks visually wrong on-device (see
  brainstorm discussion).
- Any change to `flutter_earth_globe`'s vendored source.
- A "spread apart" (non-clustering) alternative for entries that are
  genuinely coincident (identical or near-identical coordinates) — those
  still cluster like any other close pair; spreading only makes sense if
  clustering is rejected as an approach, which it wasn't.
