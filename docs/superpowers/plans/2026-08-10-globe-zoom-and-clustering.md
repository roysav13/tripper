# Globe deeper zoom + marker clustering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise the globe's max zoom, shrink halo sizes to reduce collision frequency, and cluster geographically-close journal entries into a single tappable marker that splits apart as the user zooms in.

**Architecture:** A new pure function, `groupEntriesByProximity`, groups located entries by great-circle distance with a threshold that shrinks as zoom increases (matching the existing `2^zoom` scaling convention already used for dot sizing in this file). `journal_globe.dart`'s point-rendering methods (`_addPoints`, `_syncPoints`, `_handleZoomChanged`) are rewritten to iterate clusters instead of raw entries — a cluster of size 1 renders exactly as a single entry does today (same point IDs, same styles, zero behavior change); a cluster of size N>1 renders one new marker (halo + border + a `_ClusterDot` count-badge widget) at the cluster's centroid. Tapping a cluster reuses the existing multi-entry presentation sheet (`showJournalEntryPresentationSheet`), the same one gallery day-cards already use.

**Tech Stack:** Flutter, `dart:math` (haversine distance — no new package dependency).

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart` — all new colors go through `context.colors`.
- Tests land in the same commit as the feature.
- Widget/GPU-dependent rendering changes stay manual-verification-only in this codebase (established pattern — see `PATCHES.md` and this file's own history); pull decision/grouping logic into plain, unit-testable functions instead of trying to test the GPU path itself.
- Every constant introduced for visual tuning (sizes, thresholds) is a documented starting value for on-device tuning, not a precisely-derived number — match the existing comment style for `_haloDotSize` etc.

---

### Task 1: `groupEntriesByProximity` (TDD, no GPU dependency)

**Files:**
- Modify: `lib/features/journal/domain/journal_entry_queries.dart`
- Modify: `test/unit/journal/journal_entry_queries_test.dart` (existing file — uses an `_e(String id, DateTime loggedAt, {double? lat, double? lng})` helper already defined at the top; add new tests using that same helper)

**Interfaces:**
- Produces: `List<List<JournalEntry>> groupEntriesByProximity(List<JournalEntry> entries, double zoom)` — top-level, in `journal_entry_queries.dart`. Each returned cluster is sorted ascending by `loggedAt`. Task 2 consumes this exact signature.

- [ ] **Step 1: Write the failing tests**

Add to `test/unit/journal/journal_entry_queries_test.dart` (append a new `group('groupEntriesByProximity', ...)` block; the file already imports what's needed and defines `_e`):

```dart
  group('groupEntriesByProximity', () {
    test('returns empty list for empty input', () {
      expect(groupEntriesByProximity([], 0), isEmpty);
    });

    test('a single located entry is its own cluster', () {
      final entries = [_e('a', DateTime(2026, 1, 1), lat: 40.0, lng: -74.0)];
      final clusters = groupEntriesByProximity(entries, 0);
      expect(clusters, hasLength(1));
      expect(clusters.single.map((e) => e.id), ['a']);
    });

    test('unlocated entries are excluded from every cluster', () {
      final entries = [
        _e('a', DateTime(2026, 1, 1), lat: 40.0, lng: -74.0),
        _e('unlocated', DateTime(2026, 1, 2)),
      ];
      final clusters = groupEntriesByProximity(entries, 0);
      expect(clusters, hasLength(1));
      expect(clusters.single.map((e) => e.id), ['a']);
    });

    test('entries far apart never cluster regardless of zoom', () {
      final entries = [
        _e('nyc', DateTime(2026, 1, 1), lat: 40.7, lng: -74.0),
        _e('tokyo', DateTime(2026, 1, 2), lat: 35.7, lng: 139.7),
      ];
      // zoom: -1 gives the largest possible threshold (100km) — even then,
      // two points on opposite sides of the planet must not cluster.
      final clusters = groupEntriesByProximity(entries, -1);
      expect(clusters, hasLength(2));
    });

    test('entries within threshold at low zoom cluster, and split apart '
        'once zoom shrinks the threshold below their distance', () {
      // ~15km apart (0.135 degrees latitude at this longitude).
      final entries = [
        _e('a', DateTime(2026, 1, 1), lat: 40.000, lng: -74.000),
        _e('b', DateTime(2026, 1, 2), lat: 40.135, lng: -74.000),
      ];
      // zoom 0: threshold 50km — within range, one cluster.
      final atRest = groupEntriesByProximity(entries, 0);
      expect(atRest, hasLength(1));
      expect(atRest.single, hasLength(2));

      // zoom 3: threshold 6.25km — 15km apart exceeds it, two clusters.
      final zoomedIn = groupEntriesByProximity(entries, 3);
      expect(zoomedIn, hasLength(2));
    });

    test('transitive chaining: A-C exceeds the threshold directly but '
        'both are within threshold of B, so all three cluster together',
        () {
      // Collinear along longitude, ~15km between consecutive points
      // (0.135 degrees latitude each step), ~30km between the ends.
      final entries = [
        _e('a', DateTime(2026, 1, 3), lat: 40.000, lng: -74.000),
        _e('b', DateTime(2026, 1, 1), lat: 40.135, lng: -74.000),
        _e('c', DateTime(2026, 1, 2), lat: 40.270, lng: -74.000),
      ];
      // zoom 1: threshold 25km. a-b ~15km (in range), b-c ~15km (in
      // range), a-c ~30km (out of range directly) — must still merge
      // into one cluster via b.
      final clusters = groupEntriesByProximity(entries, 1);
      expect(clusters, hasLength(1));
      expect(clusters.single, hasLength(3));
    });

    test('each cluster is sorted ascending by loggedAt regardless of '
        'input order', () {
      final entries = [
        _e('later', DateTime(2026, 1, 10), lat: 40.0, lng: -74.0),
        _e('earlier', DateTime(2026, 1, 1), lat: 40.001, lng: -74.001),
      ];
      final clusters = groupEntriesByProximity(entries, 0);
      expect(clusters, hasLength(1));
      expect(clusters.single.map((e) => e.id), ['earlier', 'later']);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/journal/journal_entry_queries_test.dart`
Expected: FAIL — `groupEntriesByProximity` is undefined.

- [ ] **Step 3: Implement `groupEntriesByProximity` and its haversine helper**

In `lib/features/journal/domain/journal_entry_queries.dart`, add the import and the new code (append after the existing `groupEntriesByDay`):

```dart
import 'dart:math' as math;

import 'journal_entry.dart';
```

```dart
// Earth's mean radius in km — used to convert the haversine formula's
// angular distance into a real-world distance for the clustering
// threshold below.
const _earthRadiusKm = 6371.0;

double _degToRad(double deg) => deg * math.pi / 180;

/// Great-circle (haversine) distance between two lat/lng points, in km.
double _haversineDistanceKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusKm * c;
}

/// Groups [entries] into clusters by geographic closeness, for the
/// globe's marker rendering — entries logged close together (e.g.
/// several stops in the same city) collapse into one marker instead of
/// rendering as visually-overlapping, hard-to-tap individual dots.
///
/// Unlocated entries never appear in any cluster (same exclusion as the
/// globe's own `if (!entry.hasLocation) continue` elsewhere). A cluster
/// of size 1 is the common case — most entries aren't close to any
/// other. Each returned cluster is sorted ascending by [JournalEntry.loggedAt]
/// so callers (the globe's cluster-tap → presentation-sheet flow) get a
/// sensible chronological swipe order, matching [groupEntriesByDay]'s
/// existing ordering guarantee.
///
/// The clustering threshold shrinks as [zoom] increases — `50 *
/// pow(2, -zoom)` km — deliberately using the same `2^zoom` scaling this
/// file's caller (`journal_globe.dart`'s `_handleZoomChanged`) already
/// uses to keep dot sizes visually consistent across zoom, so a
/// cluster's *apparent* on-screen size stays roughly constant as you
/// zoom rather than being a fixed geographic distance: entries cluster
/// because they'd visually collide at the current zoom, and split apart
/// once zooming in would give them enough screen space to be
/// individually tappable. `50` (km, at zoom 0) is a starting value for
/// on-device tuning, not precisely derived — see this file's `PATCHES.md`-
/// adjacent design doc for the reasoning.
///
/// Grouping is transitive: if A is within threshold of B, and B is
/// within threshold of C, all three land in one cluster even if A and C
/// alone exceed the threshold — matches how visual overlap actually
/// chains (A's halo overlapping B's overlapping C's reads as one blob).
/// O(n²) worst case; fine at the scale a single trip's entries actually
/// reach (realistically low tens).
List<List<JournalEntry>> groupEntriesByProximity(
  List<JournalEntry> entries,
  double zoom,
) {
  final located = entries.where((e) => e.hasLocation).toList();
  final thresholdKm = (50.0 * math.pow(2, -zoom)).toDouble();
  final clusters = <List<JournalEntry>>[];
  final assigned = <String>{};
  for (final seed in located) {
    if (assigned.contains(seed.id)) continue;
    final cluster = <JournalEntry>[seed];
    assigned.add(seed.id);
    var frontier = <JournalEntry>[seed];
    while (frontier.isNotEmpty) {
      final next = <JournalEntry>[];
      for (final member in frontier) {
        for (final candidate in located) {
          if (assigned.contains(candidate.id)) continue;
          final distance = _haversineDistanceKm(
            member.lat!,
            member.lng!,
            candidate.lat!,
            candidate.lng!,
          );
          if (distance <= thresholdKm) {
            cluster.add(candidate);
            assigned.add(candidate.id);
            next.add(candidate);
          }
        }
      }
      frontier = next;
    }
    cluster.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    clusters.add(cluster);
  }
  return clusters;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/journal/journal_entry_queries_test.dart`
Expected: PASS — all tests, including the pre-existing ones for `latestLocatedEntry`/`journeyConnections`/`groupEntriesByDay`.

- [ ] **Step 5: Run `flutter analyze`**

Run: `flutter analyze lib/features/journal/domain/journal_entry_queries.dart test/unit/journal/journal_entry_queries_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/journal/domain/journal_entry_queries.dart test/unit/journal/journal_entry_queries_test.dart
git commit -m "feat(journal): add groupEntriesByProximity for globe marker clustering

Pure, unit-tested function — not yet wired into the globe's rendering.
Zoom-scaled great-circle-distance threshold, transitive grouping,
chronologically sorted output."
```

---

### Task 2: Cluster-aware point rendering in the globe

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`

**Interfaces:**
- Consumes: `groupEntriesByProximity(List<JournalEntry> entries, double zoom)` from Task 1.
- Produces: a new `onClusterTap: void Function(List<JournalEntry> entries)?` parameter on `JournalGlobe`, consumed by Task 3.

This task has no automated test — GPU-rendering-dependent, manual-verification-only, consistent with every other rendering change in this file (see the plan's Global Constraints).

- [ ] **Step 1: Bump `maxZoom` and shrink halo sizes**

In `lib/features/journal/presentation/journal_globe.dart`:

Change `const _haloDotSize = 7.0;` (line ~37) to:
```dart
const _haloDotSize = 5.0;
```

Change `const _photoHaloDotSize = 9.0;` (line ~39) to:
```dart
const _photoHaloDotSize = 7.0;
```

In `_buildController` (around line 439), change `maxZoom: 3.5,` to `maxZoom: 5,` and update the comment immediately above it (currently explains why `3.5` was chosen) to also note the range increase:

```dart
      // Default is 2.5 (~5.7x, radius = baseRadius * 2^zoom). A prior
      // round raised this to 5 (~32x) for legibility, but that pushes far
      // past what the bundled 4000x2000 earth_day.jpg (base tier) texture
      // actually has detail for — the sphere is rasterized by resampling
      // that fixed-resolution texture (see RotatingGlobeState.buildSphere),
      // so zooming past its native detail only blurs pre-existing pixels
      // larger, it doesn't reveal anything sharper. 3.5 (~11x) was chosen
      // to sit close to where a 4000px-wide equirectangular texture's own
      // texel density starts to noticeably soften under this package's
      // per-pixel bilinear resampling. That was about the BASE tier's
      // softening point only — a higher-resolution tier
      // (earth_day_high.jpg, 8000x4000) now loads automatically past
      // highResGlobeZoomThreshold, moving the practical softening point
      // out further, so maxZoom is raised to 5 (~32x) to actually use
      // that tier's extra headroom instead of capping the range at the
      // base tier's old limit.
      maxZoom: 5,
```

- [ ] **Step 2: Add cluster-marker constants**

Add these alongside the other size constants near the top of the file (after `const _photoHaloDotSize = 7.0;`):

```dart
// A cluster marker (multiple close-together entries collapsed into one
// tappable dot) is deliberately sized between a plain dot and a photo
// dot — big enough to read as "this is a group, not a single entry" via
// its count badge, without being as visually heavy as a photo thumbnail.
// Starting values for on-device tuning, same as every other size
// constant in this file.
const _clusterDotDiameter = 30.0;
const _clusterHaloSize = 11.0;
const _clusterBorderSize = 17.0;
```

- [ ] **Step 3: Add the `onClusterTap` parameter to `JournalGlobe`**

In the `JournalGlobe` class (around line 98-125), add the field and constructor parameter:

```dart
class JournalGlobe extends StatefulWidget {
  const JournalGlobe({
    super.key,
    required this.entries,
    this.selectedEntryId,
    this.liveFollowEntryId,
    this.onEntryTap,
    this.onClusterTap,
    this.renderGlobe = true,
  });

  final List<JournalEntry> entries;

  /// Set by the coordinating parent (TripJournalTab) when an entry is
  /// selected — from tapping this same globe's own dot, or from tapping
  /// a gallery card. A changed, non-null value takes priority over the
  /// "focus on the latest entry" default and animates the globe there.
  final String? selectedEntryId;

  /// Set continuously by the coordinating parent as the gallery strip
  /// scrolls — whichever entry is currently centered in the visible
  /// viewport, NOT a tap. A changed, non-null value snaps the globe
  /// there instantly (no easing animation — the scroll gesture itself
  /// already supplies the perceived motion; stacking a separate eased
  /// pan on top would fight it and look laggy, not smooth).
  final String? liveFollowEntryId;

  final void Function(JournalEntry entry)? onEntryTap;

  /// Fired when a cluster marker (multiple geographically-close entries
  /// collapsed into one dot — see groupEntriesByProximity) is tapped,
  /// with that cluster's member entries in chronological order. Distinct
  /// from [onEntryTap], which only ever fires for a single, unclustered
  /// entry's own dot.
  final void Function(List<JournalEntry> entries)? onClusterTap;

  final bool renderGlobe;

  @override
  State<JournalGlobe> createState() => _JournalGlobeState();
}
```

- [ ] **Step 4: Add cluster-tracking state and helper methods**

In `_JournalGlobeState`, add new fields alongside the existing `_focusedEntryId` (around line 134):

```dart
  String? _focusedEntryId;

  /// The clusters (see groupEntriesByProximity) actually rendered as
  /// points right now — the source of truth for which point IDs to
  /// remove on the next resync. Rebuilt every time _addPoints runs.
  List<List<JournalEntry>> _lastClusters = [];

  /// The zoom "band" (see _clusterBandFor) as of the last time clusters
  /// were recomputed. A changed band means the same entries may now
  /// group differently, so _handleZoomChanged triggers a full
  /// remove-and-re-add instead of just rescaling existing points in
  /// place. Set once _addPoints first runs (see controller.onLoaded
  /// below); null beforehand.
  int? _lastClusterBand;
```

Add these new private helper methods (placed near `_rescalePoint`, since they serve the same point-management role):

```dart
  /// A stable identifier for a cluster's points, built from its member
  /// entry ids sorted ascending — deterministic regardless of the
  /// cluster's own internal (chronological) order, so the same set of
  /// entries always maps to the same point IDs across rebuilds. A
  /// cluster of size 1 never uses this — it keeps using that entry's own
  /// id directly, identical to pre-clustering behavior.
  String _clusterKey(List<JournalEntry> cluster) =>
      (cluster.map((e) => e.id).toList()..sort()).join('+');

  /// The simple arithmetic-mean centroid of a cluster's coordinates —
  /// sufficient at cluster scale (tens of km at most, given
  /// groupEntriesByProximity's threshold curve); points that far apart
  /// never cluster together in the first place, so this never needs to
  /// handle continental-scale spans where a naive mean would misbehave.
  (double, double) _clusterCentroid(List<JournalEntry> cluster) {
    var latSum = 0.0;
    var lngSum = 0.0;
    for (final entry in cluster) {
      latSum += entry.lat!;
      lngSum += entry.lng!;
    }
    return (latSum / cluster.length, lngSum / cluster.length);
  }

  /// Which zoom "band" a given zoom falls into, for deciding when
  /// clustering needs to be recomputed (see _lastClusterBand) — each
  /// whole zoom step is its own band, matching groupEntriesByProximity's
  /// threshold curve halving roughly every 1.0 zoom step.
  int _clusterBandFor(double zoom) => zoom.floor();

  void _removeClusterPoints(
    FlutterEarthGlobeController controller,
    List<JournalEntry> cluster,
  ) {
    if (cluster.length == 1) {
      final entry = cluster.single;
      controller.removePoint(entry.id);
      controller.removePoint('${entry.id}-halo');
      controller.removePoint('${entry.id}-border');
    } else {
      final key = _clusterKey(cluster);
      controller.removePoint(key);
      controller.removePoint('$key-halo');
      controller.removePoint('$key-border');
    }
  }
```

- [ ] **Step 5: Rewrite `_syncPoints` to use `_lastClusters` instead of a `previous` parameter**

Replace the existing `_syncPoints` method (around line 220):

```dart
  void _syncPoints() {
    final controller = _controller;
    if (controller == null) return;
    for (final connection in controller.connections.toList()) {
      controller.removePointConnection(connection.id);
    }
    for (final cluster in _lastClusters) {
      _removeClusterPoints(controller, cluster);
    }
    _addPoints(controller);
  }
```

Update its call site in `didUpdateWidget` (around line 183) from `_syncPoints(oldWidget.entries);` to `_syncPoints();`.

- [ ] **Step 6: Rewrite `_addPoints` to iterate clusters**

Replace the existing `_addPoints` method (around line 236) in full:

```dart
  void _addPoints(FlutterEarthGlobeController controller) {
    final colors = context.colors;
    // Points added while already zoomed in (e.g. an entry's location is
    // edited mid-session) must start at the CURRENT zoom's compensated
    // size — otherwise they'd render at the raw, uncompensated base size
    // until the next zoom gesture happens to fire onZoomChanged.
    final compensation = 1 / math.pow(2, controller.zoom);
    final clusters = groupEntriesByProximity(widget.entries, controller.zoom);
    for (final cluster in clusters) {
      if (cluster.length == 1) {
        final entry = cluster.single;
        final onTap = widget.onEntryTap == null
            ? null
            : () => widget.onEntryTap!(entry);
        // Halo, then border ring, then the dot/photo widget itself —
        // three native layers (halo and border both native points; the
        // photo case's actual "dot" is the labelBuilder widget below,
        // not a native point) added in back-to-front order so they
        // paint (and therefore sit) correctly stacked — this needs
        // on-device confirmation like every other dot-visual change in
        // this file; the package's actual draw order isn't guaranteed
        // by its public API, only inferred from insertion order +
        // depth-tie stability.
        controller.addPoint(
          Point(
            id: '${entry.id}-halo',
            coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
            style: PointStyle(
              size: (entry.hasPhotos ? _photoHaloDotSize : _haloDotSize) *
                  compensation,
              color: colors.accent.withValues(alpha: _haloAlpha),
            ),
            // The halo's hit-rect is strictly larger than the core
            // dot's and is tested first (added first, same coordinates
            // so depth ties, and the package's sort is only stable for
            // small point counts) — the package marks a click "handled"
            // on the first hit regardless of whether that point has a
            // handler, so a halo with no onTap silently swallows taps
            // meant for the dot below it. Left null for photo entries —
            // _PhotoDot's own GestureDetector handles those; wiring
            // both would double-fire.
            onTap: entry.hasPhotos ? null : onTap,
          ),
        );
        // Border ring: PointStyle has no border/stroke property, so a
        // solid, slightly-larger circle painted directly behind the
        // core (or, for a photo entry, just past the photo widget's own
        // edge) simulates an outline — giving the flat dot definition
        // against the globe's own busy, variable-brightness texture
        // instead of just a soft color blob.
        controller.addPoint(
          Point(
            id: '${entry.id}-border',
            coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
            style: PointStyle(
              size: (entry.hasPhotos ? _photoBorderSize : _plainBorderSize) *
                  compensation,
              color: colors.surface,
            ),
            onTap: entry.hasPhotos ? null : onTap,
          ),
        );
        if (entry.hasPhotos) {
          controller.addPoint(
            Point(
              id: entry.id,
              coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
              label: entry.placeName ?? entry.summary,
              // Photo dots stay widget-rendered — the package has no
              // native way to show an image on a point. size: 0
              // suppresses the (otherwise pointless) native dot
              // underneath it.
              style: const PointStyle(size: 0),
              isLabelVisible: true,
              // Centers a _photoDotDiameter-square widget exactly on
              // the point: the package positions labelBuilder output at
              // `left = pos.dx - labelOffset.dx - width/2`,
              // `top = pos.dy - labelOffset.dy - height`.
              labelOffset: const Offset(0, -_photoDotDiameter / 2),
              labelBuilder: (context, point, isHovering, isVisible) =>
                  _PhotoDot(
                filePath: entry.photos.first.filePath,
                onTap: onTap,
              ),
              // Point.onTap is intentionally left unset — see
              // _PhotoDot's own GestureDetector. Setting both would
              // double-fire onEntryTap for taps landing in the native
              // point's small residual hit region.
            ),
          );
        } else {
          controller.addPoint(
            Point(
              id: entry.id,
              coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
              label: entry.placeName ?? entry.summary,
              // Native GPU-rendered dot: cheap, and perfectly in sync
              // with the sphere's rotation every frame by construction
              // (the shader paints it — no separate widget-position
              // recompute pass, unlike the labelBuilder path above). A
              // prior round made every dot widget-rendered instead,
              // purely to dodge the package's built-in zoom-scaling,
              // and that made rotation noticeably less smooth (every
              // dot's position became a real widget rebuild on every
              // animation frame). _handleZoomChanged counteracts the
              // zoom-scaling directly instead, so this can stay
              // native/cheap AND zoom-stable.
              style: PointStyle(
                size: _plainDotSize * compensation,
                color: colors.accent,
              ),
              // No labelBuilder for this one, so tap must be wired
              // directly on the Point — the package's own native
              // hit-testing (sized from PointStyle.size) drives it.
              onTap: onTap,
            ),
          );
        }
      } else {
        final key = _clusterKey(cluster);
        final (centroidLat, centroidLng) = _clusterCentroid(cluster);
        final onTap = widget.onClusterTap == null
            ? null
            : () => widget.onClusterTap!(cluster);
        controller.addPoint(
          Point(
            id: '$key-halo',
            coordinates: GlobeCoordinates(centroidLat, centroidLng),
            style: PointStyle(
              size: _clusterHaloSize * compensation,
              color: colors.accent.withValues(alpha: _haloAlpha),
            ),
            // No onTap here — same reasoning as the photo-dot halo
            // above: _ClusterDot's own GestureDetector (via the
            // labelBuilder below) handles the tap; wiring both would
            // double-fire.
          ),
        );
        controller.addPoint(
          Point(
            id: '$key-border',
            coordinates: GlobeCoordinates(centroidLat, centroidLng),
            style: PointStyle(
              size: _clusterBorderSize * compensation,
              color: colors.surface,
            ),
          ),
        );
        controller.addPoint(
          Point(
            id: key,
            coordinates: GlobeCoordinates(centroidLat, centroidLng),
            label: '${cluster.length} entries',
            // Widget-rendered, same reasoning as the photo dot: the
            // package has no native way to show a count badge on a
            // point. size: 0 suppresses the native dot underneath it.
            style: const PointStyle(size: 0),
            isLabelVisible: true,
            labelOffset: const Offset(0, -_clusterDotDiameter / 2),
            labelBuilder: (context, point, isHovering, isVisible) =>
                _ClusterDot(count: cluster.length, onTap: onTap),
          ),
        );
      }
    }
    _lastClusters = clusters;
    for (final (start, end) in journeyConnections(widget.entries)) {
      controller.addPointConnection(
        PointConnection(
          id: '${start.id}->${end.id}',
          start: GlobeCoordinates(start.lat!, start.lng!),
          end: GlobeCoordinates(end.lat!, end.lng!),
          curveScale: _arcCurveScale,
          style: PointConnectionStyle(
            color: colors.accent.withValues(alpha: 0.6),
            lineWidth: 1.5,
          ),
        ),
      );
    }
  }
```

- [ ] **Step 7: Rewrite `_handleZoomChanged` to be cluster-aware and trigger a full resync on a band change**

Replace the existing `_handleZoomChanged` method (around line 371) in full:

```dart
  void _handleZoomChanged(double zoom) {
    final controller = _controller;
    if (controller == null) return;
    if (shouldRequestHighResGlobeSurface(
      zoom: zoom,
      alreadyRequested: _highResRequested,
    )) {
      _highResRequested = true;
      controller.loadSurface(const AssetImage(_highResGlobeTexture));
    }
    final band = _clusterBandFor(zoom);
    if (band != _lastClusterBand) {
      // Crossing into a different clustering band means the same
      // entries may now group differently (a cluster might split apart,
      // or two clusters might merge) — a full remove-and-re-add is
      // needed, not just a resize of the existing points, since the
      // set of point IDs itself can change (see _clusterKey).
      _lastClusterBand = band;
      _syncPoints();
      return;
    }
    final compensation = 1 / math.pow(2, zoom);
    for (final cluster in _lastClusters) {
      if (cluster.length == 1) {
        final entry = cluster.single;
        final haloBase = entry.hasPhotos ? _photoHaloDotSize : _haloDotSize;
        final borderBase =
            entry.hasPhotos ? _photoBorderSize : _plainBorderSize;
        _rescalePoint(controller, '${entry.id}-halo', haloBase * compensation);
        _rescalePoint(
          controller,
          '${entry.id}-border',
          borderBase * compensation,
        );
        if (!entry.hasPhotos) {
          _rescalePoint(controller, entry.id, _plainDotSize * compensation);
        }
      } else {
        final key = _clusterKey(cluster);
        _rescalePoint(
          controller,
          '$key-halo',
          _clusterHaloSize * compensation,
        );
        _rescalePoint(
          controller,
          '$key-border',
          _clusterBorderSize * compensation,
        );
      }
    }
  }
```

- [ ] **Step 8: Set `_lastClusterBand` once the first points are rendered**

In `_buildController`'s `controller.onLoaded` callback (around line 441), add one line right after `_addPoints(controller);`:

```dart
    controller.onLoaded = () {
      _addPoints(controller);
      _lastClusterBand = controller.zoom.floor();
      if (widget.selectedEntryId != null) {
        _maybeFocusSelected();
      } else {
        _maybeFocusLatest(instant: true);
      }
    };
```

- [ ] **Step 9: Add the `_ClusterDot` widget**

Add this new class near `_PhotoDot` (after it, at the end of the file), following its exact structural pattern:

```dart
/// A circular, filled marker with a count badge, rendered at a cluster's
/// centroid via Point.labelBuilder (the package has no built-in way to
/// show text on a point) — the multi-entry equivalent of a plain native
/// dot. Wraps itself in a GestureDetector — see the comment on
/// Point.onTap in _addPoints for why tap handling lives here instead of
/// on the Point itself.
class _ClusterDot extends StatelessWidget {
  const _ClusterDot({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: _clusterDotDiameter,
        height: _clusterDotDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.accent,
          border: Border.all(color: colors.surface, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: colors.inkPrimary.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Center(
          child: MonoText('$count', color: colors.surface),
        ),
      ),
    );
  }
}
```

- [ ] **Step 10: Run the existing widget test suite for this file**

Run: `flutter test test/widget/journal/journal_globe_test.dart`
Expected: PASS — the `renderGlobe: false` scaffold this test exercises doesn't use clustering (it renders one icon per located entry directly, unchanged by this task), so nothing here should regress.

- [ ] **Step 11: Run `flutter analyze`**

Run: `flutter analyze lib/features/journal/presentation/journal_globe.dart`
Expected: No issues found.

- [ ] **Step 12: Manual on-device verification**

GPU-rendering-dependent, cannot be automated (see CLAUDE.md's Verification section). Run `flutter run` on a real device, open a trip with several journal entries logged close together (or temporarily add test entries with nearby coordinates if the current trip data doesn't have any), and confirm:
- Entries far apart still render as individual dots, tappable exactly as before (no regression on the common case).
- Entries close together at rest zoom render as a single marker with a count badge.
- Tapping that marker opens the presentation sheet with all of that cluster's entries.
- Zooming in causes the cluster to split apart into individual dots once they'd have enough screen space (don't expect an exact pixel-perfect threshold — just confirm it visibly happens somewhere in the zoom range, not never and not immediately).
- Zooming past the previous `maxZoom: 3.5` point still works (the range actually extends to 5 now) and doesn't visibly break anything.
- Halo sizes look smaller than before but dots are still comfortably tappable.

Report back the observed behavior before proceeding to commit.

- [ ] **Step 13: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart
git commit -m "feat(journal): cluster close-together globe entries, raise maxZoom to 5

Entries within a zoom-scaled distance threshold (groupEntriesByProximity)
now render as one marker with a count badge instead of overlapping
individual dots; splits apart as the user zooms in. Also shrinks halo
sizes (7->5, 9->7) to reduce how often clustering is needed in the first
place. Manually verified on-device per
docs/superpowers/plans/2026-08-10-globe-zoom-and-clustering.md."
```

---

### Task 3: Wire `onClusterTap` to the presentation sheet

**Files:**
- Modify: `lib/features/journal/presentation/trip_journal_tab.dart`

**Interfaces:**
- Consumes: `JournalGlobe.onClusterTap` from Task 2; `showJournalEntryPresentationSheet(BuildContext, {required String tripId, required List<JournalEntry> entries, required int initialIndex, void Function(int)? onPageChanged})` (existing, unchanged API — already used by this same file's `onTapDay` for the gallery timeline's day cards).

- [ ] **Step 1: Find the current `JournalGlobe` usage and `onTapDay` pattern to mirror**

In `lib/features/journal/presentation/trip_journal_tab.dart`, locate the `JournalGlobe(...)` constructor call (inside the `Positioned.fill` in `build()`) and the `JournalGalleryTimeline`'s `onTapDay` callback a bit further down in the same `build()` method — `onTapDay` is the exact pattern to mirror, since a cluster tap is structurally the same situation (multiple entries, open the sheet, keep gallery selection in sync).

- [ ] **Step 2: Add `onClusterTap` to the `JournalGlobe` call**

Change:

```dart
              : JournalGlobe(
                  entries: entries,
                  selectedEntryId: _selectedEntryId,
                  liveFollowEntryId: _liveFollowEntryId,
                  onEntryTap: (entry) =>
                      setState(() => _selectedEntryId = entry.id),
                  renderGlobe: widget.renderGlobe,
                ),
```

to:

```dart
              : JournalGlobe(
                  entries: entries,
                  selectedEntryId: _selectedEntryId,
                  liveFollowEntryId: _liveFollowEntryId,
                  onEntryTap: (entry) =>
                      setState(() => _selectedEntryId = entry.id),
                  onClusterTap: (clusterEntries) {
                    setState(() => _selectedEntryId = clusterEntries.first.id);
                    showJournalEntryPresentationSheet(
                      context,
                      tripId: widget.trip.id,
                      entries: clusterEntries,
                      initialIndex: 0,
                      onPageChanged: (index) => setState(
                        () => _selectedEntryId = clusterEntries[index].id,
                      ),
                    );
                  },
                  renderGlobe: widget.renderGlobe,
                ),
```

- [ ] **Step 3: Run the existing widget test suite for this file**

Run: `flutter test test/widget/journal/trip_journal_tab_test.dart`
Expected: PASS — this wiring is only reachable through a real cluster tap on the GPU-rendered globe, which these widget tests (via `renderGlobe: false`) don't exercise, so nothing here should regress.

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze lib/features/journal/presentation/trip_journal_tab.dart`
Expected: No issues found.

- [ ] **Step 5: Manual on-device verification**

Covered by Task 2's Step 12 (tapping a cluster marker and confirming the presentation sheet opens with the right entries) — no separate device pass needed here, but if Task 2's verification is done before this task lands, re-confirm the cluster tap specifically opens the sheet (not just that the marker renders).

- [ ] **Step 6: Commit**

```bash
git add lib/features/journal/presentation/trip_journal_tab.dart
git commit -m "feat(journal): open the presentation sheet on a globe cluster tap

Mirrors the gallery timeline's existing onTapDay pattern — same sheet,
same multi-entry API, just triggered from a cluster marker instead of a
day card."
```

---

## Self-Review Notes

- **Spec coverage:** Zoom range bump (Task 2 Step 1), dot-size tuning (Task 2 Step 1), clustering algorithm (Task 1), cluster marker rendering (Task 2 Steps 2-9), cluster tap interaction (Task 2 Step 6 + Task 3), recompute triggers (Task 2 Steps 5-8), error handling for unlocated entries (Task 1's function excludes them; Task 2 no longer needs its own `hasLocation` guard since clusters already exclude them), testing (Task 1 fully automated, Task 2/3 manual-verification-only per this codebase's established pattern for GPU rendering). "Out of scope" items (screen-space clustering, vendored package changes, spread-apart alternative) — none introduced.
- **Placeholder scan:** No TBD/TODO; every step has complete code, not descriptions of code.
- **Type consistency:** `groupEntriesByProximity(List<JournalEntry> entries, double zoom)` defined in Task 1, consumed identically in Task 2 Step 6 (`groupEntriesByProximity(widget.entries, controller.zoom)`). `onClusterTap: void Function(List<JournalEntry> entries)?` defined on `JournalGlobe` in Task 2 Step 3, consumed with a matching signature in Task 3 Step 2. `_clusterKey`/`_clusterCentroid`/`_clusterBandFor`/`_removeClusterPoints` are defined once in Task 2 Step 4 and reused consistently across `_addPoints`, `_syncPoints`, and `_handleZoomChanged` in later steps of the same task — no drift between definition and use since they're all in one task's diff.
