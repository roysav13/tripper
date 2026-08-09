import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_entry_queries.dart';

// Base sizes — what the dot/halo should look like at zoom 0. The package
// scales every native PointStyle.size by `radius/150` (radius already
// includes zoom: radius = baseRadius * 2^zoom), so without correction
// these balloon linearly with zoom — a halo sized here for a comfortable
// look at zoom 0 becomes a room-filling blob at high zoom. _handleZoomChanged
// below counteracts that every time zoom changes, keeping the on-screen
// size roughly what it was at zoom 0 (the one look this was ever actually
// tuned for) — the same way a map pin stays a constant screen size as you
// zoom a real map, rather than growing into the streets it's marking.
const _plainDotSize = 2.5;
// A ring between the halo and the core, giving the flat native dot a
// visible outline — PointStyle has no border property, so this is a
// second, larger, opaque circle painted directly behind the core (see
// the layering comment in _addPoints).
const _plainBorderSize = 4.0;
const _haloDotSize = 5.0;
// Monochrome teal — CLAUDE.md's two-accents rule (teal for actions/
// places, rust reserved for warnings only) means the halo has to be a
// low-alpha version of the same accent, not a new hue.
const _haloAlpha = 0.28;

// A cluster marker (multiple close-together entries collapsed into one
// tappable dot) is deliberately sized between a plain dot and a photo
// dot — big enough to read as "this is a group, not a single entry" via
// its count badge, without being as visually heavy as a photo thumbnail.
// Starting values for on-device tuning, same as every other size
// constant in this file.
const _clusterDotDiameter = 30.0;
const _clusterHaloSize = 11.0;
const _clusterBorderSize = 17.0;

// Globe.GL-style arcs default the curve height (via the point_connection
// package's own curveScale=1.5 default) to something that reads as a
// steep, ballistic arc — closer to a flight path than a route line on the
// same globe you're standing on. This flattens the arc noticeably closer
// to the sphere's surface.
const _arcCurveScale = 0.4;

// The zoom level past which the globe swaps to a higher-resolution
// surface texture (see _buildController's maxZoom comment for why the
// base texture softens at high zoom — this routes more real detail into
// view instead of just resampling the same fixed-resolution source
// larger). zoom's range is [minZoom (-1.0 default), maxZoom (5)]; 1.5
// sits closer to the bottom of that zoom-in range than "partway"
// suggests (maxZoom was later raised from 3.5 to 5 by a separate task,
// stretching the range without this threshold being revisited) — chosen
// so the swap happens early, well before the base texture's softening
// becomes very visible, rather than only near the top of the range.
const highResGlobeZoomThreshold = 1.5;

// The two locally bundled texture tiers (see the class doc comment above
// for why both are bundled rather than fetched). Named constants so the
// two call sites (_buildController's initial surface, and
// _handleZoomChanged's tier-2 load) can't drift out of sync with a typo.
const _baseGlobeTexture = 'assets/globe/earth_day.jpg';
const _highResGlobeTexture = 'assets/globe/earth_day_high.jpg';

/// Whether [JournalGlobe] should request the higher-resolution surface
/// texture — true exactly once, the first time [zoom] crosses
/// [highResGlobeZoomThreshold], given the caller already tracks whether
/// that request has been made ([alreadyRequested]) so it isn't repeated
/// on every subsequent zoom-changed callback above the threshold. A
/// top-level, GPU-independent function so this decision is unit-testable
/// without a real FlutterEarthGlobeController — see
/// test/unit/journal/journal_globe_zoom_test.dart.
@visibleForTesting
bool shouldRequestHighResGlobeSurface({
  required double zoom,
  required bool alreadyRequested,
}) {
  return !alreadyRequested && zoom > highResGlobeZoomThreshold;
}

/// flutter_earth_globe renders via GPU fragment shaders, which widget tests
/// can't render. Tests pass `renderGlobe: false` to get tappable
/// entry-icon scaffolding without ever constructing
/// `FlutterEarthGlobeController` (SPEC: no GPU/platform dependency in
/// tests) — same seam as PlacesMapView's `renderMap: false`.
///
/// Texture is a locally bundled asset — the base tier
/// (assets/globe/earth_day.jpg) at rest, swapped for a higher-resolution
/// tier (assets/globe/earth_day_high.jpg) once zoom crosses
/// highResGlobeZoomThreshold. Both are bundled in the app, never fetched
/// over the network (offline rule, SPEC §3.1.2). Points are this trip's
/// located journal entries — an entry IS a visited place (see
/// place_visit_actions.dart) — not read from Places directly.
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

class _JournalGlobeState extends State<JournalGlobe> {
  FlutterEarthGlobeController? _controller;
  bool _initialized = false;
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

  /// Set once _handleZoomChanged has requested the higher-res surface
  /// texture (see shouldRequestHighResGlobeSurface) — guards against
  /// re-requesting it on every subsequent zoom-changed callback past
  /// highResGlobeZoomThreshold. Deliberately never reset: once loaded,
  /// the higher-res texture stays active for the lifetime of this
  /// widget's mount even if the user zooms back out (approved design:
  /// avoids repeated ~32MP decodes from ordinary zoom in/out fiddling).
  /// Leaving and re-entering the trip's Journal tab tears down this
  /// State (see didChangeDependencies/_initialized) and builds a fresh
  /// FlutterEarthGlobeController, resetting this flag and re-triggering
  /// the decode on the next threshold crossing — an accepted cost of the
  /// simpler design, not cross-mount caching.
  bool _highResRequested = false;

  /// True once the sphere has actually decoded its surface texture and has
  /// something real to paint — driven by
  /// [FlutterEarthGlobeController.onSphereReady], NOT [onLoaded] (which
  /// fires on mount, before the texture is anywhere near ready — see
  /// PATCHES.md). Until this flips, the sphere either isn't drawn yet or
  /// briefly flashes an unlit/blank frame, so [_GlobeLoadingIndicator]
  /// covers that gap.
  bool _isLoaded = false;

  // Not initState: building the controller reads context.colors (a Theme
  // lookup), and establishing an InheritedWidget dependency before
  // initState() completes throws. didChangeDependencies is the first safe
  // point, and runs before the first build.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.renderGlobe && !_initialized) {
      _initialized = true;
      _controller = _buildController();
    }
  }

  @override
  void didUpdateWidget(JournalGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.renderGlobe) return;
    if (widget.liveFollowEntryId != oldWidget.liveFollowEntryId) {
      _maybeFollowLive();
    }
    if (widget.selectedEntryId != oldWidget.selectedEntryId) {
      _maybeFocusSelected();
    }
    if (!_sameEntryIds(oldWidget.entries)) {
      _syncPoints();
      if (widget.selectedEntryId == null && widget.liveFollowEntryId == null) {
        _maybeFocusLatest();
      }
    }
  }

  // Compares the fields the globe actually renders per entry — id, lat,
  // lng — not just id/order. Journal entries are edited constantly
  // (unlike the visited Places this replaced, whose coordinates rarely
  // changed), so an identity-only check would miss a location being
  // added or moved.
  bool _sameEntryIds(List<JournalEntry> previous) {
    if (previous.length != widget.entries.length) return false;
    for (var i = 0; i < previous.length; i++) {
      final prevEntry = previous[i];
      final nextEntry = widget.entries[i];
      if (prevEntry.id != nextEntry.id) return false;
      if (prevEntry.lat != nextEntry.lat) return false;
      if (prevEntry.lng != nextEntry.lng) return false;
    }
    return true;
  }

  // Diffed in place via addPoint/removePoint (and addPointConnection/
  // removePointConnection) — never dispose+recreate the controller here.
  // flutter_earth_globe's own FlutterEarthGlobe widget disposes
  // controller.rotationController itself when unmounted; disposing it
  // again ourselves double-frees the same AnimationController and
  // crashes ("AnimationController.dispose() called more than once").
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
        final onTap =
            widget.onEntryTap == null ? null : () => widget.onEntryTap!(entry);
        // Halo, then border ring, then the core dot — three native
        // layers added in back-to-front order so they paint (and
        // therefore sit) correctly stacked — this needs on-device
        // confirmation like every other dot-visual change in this file;
        // the package's actual draw order isn't guaranteed by its
        // public API, only inferred from insertion order + depth-tie
        // stability.
        controller.addPoint(
          Point(
            id: '${entry.id}-halo',
            coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
            style: PointStyle(
              size: _haloDotSize * compensation,
              color: colors.accent.withValues(alpha: _haloAlpha),
            ),
            onTap: onTap,
          ),
        );
        // Border ring: PointStyle has no border/stroke property, so a
        // solid, slightly-larger circle painted directly behind the
        // core simulates an outline — giving the flat dot definition
        // against the globe's own busy, variable-brightness texture
        // instead of just a soft color blob.
        controller.addPoint(
          Point(
            id: '${entry.id}-border',
            coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
            style: PointStyle(
              size: _plainBorderSize * compensation,
              color: colors.surface,
            ),
            onTap: onTap,
          ),
        );
        controller.addPoint(
          Point(
            id: entry.id,
            coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
            label: entry.placeName ?? entry.summary,
            // Native GPU-rendered dot: cheap, and perfectly in sync
            // with the sphere's rotation every frame by construction
            // (the shader paints it — no separate widget-position
            // recompute pass). A prior round made every dot
            // widget-rendered instead, purely to dodge the package's
            // built-in zoom-scaling, and that made rotation noticeably
            // less smooth (every dot's position became a real widget
            // rebuild on every animation frame). _handleZoomChanged
            // counteracts the zoom-scaling directly instead, so this
            // stays native/cheap AND zoom-stable.
            style: PointStyle(
              size: _plainDotSize * compensation,
              color: colors.accent,
            ),
            onTap: onTap,
          ),
        );
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

  /// Counteracts the package's built-in zoom-scaling of native
  /// PointStyle.size (see the comment on the size constants above) so
  /// dots and halos stay roughly the same on-screen size across the zoom
  /// range instead of ballooning at high zoom. Mutates the existing Point
  /// objects' style in place — cheap (no addPoint/removePoint churn), and
  /// picked up by the next paint without an explicit setState here: this
  /// only ever runs from FlutterEarthGlobe's onZoomChanged, which the
  /// package always calls synchronously just before its own setState for
  /// the same zoom change, so the mutation lands before that repaint reads
  /// it (confirmed by reading rotating_globe.dart's zoom handlers).
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
        _rescalePoint(
          controller,
          '${entry.id}-halo',
          _haloDotSize * compensation,
        );
        _rescalePoint(
          controller,
          '${entry.id}-border',
          _plainBorderSize * compensation,
        );
        _rescalePoint(controller, entry.id, _plainDotSize * compensation);
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

  void _rescalePoint(
    FlutterEarthGlobeController controller,
    String id,
    double newSize,
  ) {
    final index = controller.points.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final point = controller.points[index];
    if (point.style.size == newSize) return;
    point.style = point.style.copyWith(size: newSize);
  }

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

  FlutterEarthGlobeController _buildController() {
    final controller = FlutterEarthGlobeController(
      // Auto-rotation was disorienting (issue: "the map is spinning, a
      // headache reason") — the globe now only moves on user drag, which
      // is native to the package regardless of this flag.
      isRotating: false,
      isDayNightCycleEnabled: false,
      // The package applies a simulated directional light to the sphere
      // shader independent of isDayNightCycleEnabled — defaults to a strong
      // hemisphere-darkening effect that reads as a night side. Disable it
      // so the whole globe renders evenly lit.
      surfaceLightingEnabled: false,
      surface: const AssetImage(_baseGlobeTexture),
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
    );
    controller.onLoaded = () {
      _addPoints(controller);
      _lastClusterBand = _clusterBandFor(controller.zoom);
      if (widget.selectedEntryId != null) {
        _maybeFocusSelected();
      } else {
        _maybeFocusLatest(instant: true);
      }
    };
    controller.onSphereReady = () {
      if (mounted) setState(() => _isLoaded = true);
    };
    return controller;
  }

  /// Snaps instantly (no easing) to widget.liveFollowEntryId whenever it
  /// changes — driven by the gallery's own scroll position, not a tap.
  /// Silently does nothing if the entry has no location, same reasoning
  /// as _maybeFocusSelected.
  void _maybeFollowLive() {
    final controller = _controller;
    final liveId = widget.liveFollowEntryId;
    if (controller == null || !controller.isReady || liveId == null) {
      return;
    }
    if (liveId == _focusedEntryId) return;
    final target = widget.entries.where((e) => e.id == liveId).firstOrNull;
    if (target == null || !target.hasLocation) return;
    _focusedEntryId = liveId;
    // animate: true with a zero duration — not animate: false. The
    // package's focusOnCoordinates only disposes/replaces an in-flight
    // animation controller on the animate: true path; animate: false
    // just assigns rotation once and leaves a still-running prior
    // animation free to overwrite it on the next frame (confirmed by
    // reading rotating_globe.dart directly). Using animate: true here,
    // even for this "instant" snap, is what actually guarantees no
    // stale animation survives to fight this update.
    controller.focusOnCoordinates(
      GlobeCoordinates(target.lat!, target.lng!),
      animate: true,
      duration: Duration.zero,
    );
  }

  /// Focuses on widget.selectedEntryId if it's set, located, and not
  /// already what the globe is centered on — takes priority over the
  /// latest-entry auto-focus below, since a selection reflects a
  /// deliberate tap (this globe's own dot, or a gallery card), not a
  /// heuristic. Silently does nothing if the selected entry has no
  /// location — not every entry appears on the globe, and the selection
  /// still applies normally on the gallery side regardless.
  void _maybeFocusSelected() {
    final controller = _controller;
    final selectedId = widget.selectedEntryId;
    if (controller == null || !controller.isReady || selectedId == null) {
      return;
    }
    if (selectedId == _focusedEntryId) return;
    final selected =
        widget.entries.where((e) => e.id == selectedId).firstOrNull;
    if (selected == null || !selected.hasLocation) return;
    _focusedEntryId = selectedId;
    controller.focusOnCoordinates(
      GlobeCoordinates(selected.lat!, selected.lng!),
      animate: true,
      duration: const Duration(milliseconds: 600),
    );
  }

  /// Opens on the most recent entry rather than a fixed default, and
  /// re-focuses only when the latest entry actually changes — not on
  /// every unrelated edit to some other entry. [instant] skips the
  /// animation (used for the very first focus, on initial load); the
  /// default animates over 600ms (used when a new entry becomes the
  /// latest during an active session). Both branches still call
  /// focusOnCoordinates with animate: true — see the comment in
  /// _maybeFollowLive for why animate: false is never used in this file.
  void _maybeFocusLatest({bool instant = false}) {
    final controller = _controller;
    if (controller == null || !controller.isReady) return;
    final latest = latestLocatedEntry(widget.entries);
    if (latest == null || latest.id == _focusedEntryId) return;
    _focusedEntryId = latest.id;
    controller.focusOnCoordinates(
      GlobeCoordinates(latest.lat!, latest.lng!),
      animate: true,
      duration: instant ? Duration.zero : const Duration(milliseconds: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!widget.renderGlobe) {
      // Test/preview scaffold: no shader surface, located entries as
      // tappable plain-dot icons — mirrors JournalMapView's own
      // renderMap:false seam.
      return ColoredBox(
        color: colors.paper,
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final entry in widget.entries)
                if (entry.hasLocation)
                  Semantics(
                    button: widget.onEntryTap != null,
                    label: entry.placeName ?? entry.summary,
                    child: IconButton(
                      icon: Icon(
                        Icons.circle,
                        color: colors.accent,
                      ),
                      onPressed: widget.onEntryTap == null
                          ? null
                          : () => widget.onEntryTap!(entry),
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    // flutter_earth_globe sizes and centers itself off MediaQuery.of(context)
    // .size — the full device screen — rather than the constraints its
    // parent actually gives it. Embedded in a partial-height box (here, 70%
    // of the journal tab body), that mismatch made the sphere overflow/
    // misalign instead of filling its allotted area. Scoping a MediaQuery
    // with the real local size makes the package's internal layout math
    // match its actual box, and sizing the radius off that box keeps the
    // whole sphere visible without cropping.
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final radius = (math.min(size.width, size.height) / 2 - 12)
            .clamp(40.0, 110.0)
            .toDouble();
        return Stack(
          children: [
            // Positioned.fill is load-bearing, not decorative: a bare
            // Stack gives its non-Positioned children LOOSENED constraints
            // (0..max) regardless of what constraints this Stack itself
            // received — and flutter_earth_globe's own root widget
            // (RotatingGlobeState.build()) is *also* a bare Stack, whose
            // only non-positioned child is a hardcoded SizedBox.shrink()
            // (its unused "background" layer — we never set
            // controller.background). Under tight constraints that inner
            // Stack is forced to the full given size regardless of that
            // zero-sized child; under loose constraints (what it started
            // receiving the moment this wrapping Stack was introduced for
            // the loading indicator below) it sizes itself to the LARGEST
            // non-positioned child — which is that same zero-sized
            // SizedBox, since its actual sphere content lives in a
            // Positioned child that doesn't count toward sizing. The whole
            // globe collapsed to 0x0 and got clipped away entirely, even
            // though everything painted inside it still executed with
            // perfectly valid non-zero values throughout (confirmed via
            // extensive on-device tracing — see PATCHES.md). Positioned.fill
            // forces tight constraints again, matching the behavior this
            // had before this Stack existed.
            Positioned.fill(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: size),
                child: FlutterEarthGlobe(
                  controller: _controller!,
                  radius: radius,
                  onZoomChanged: _handleZoomChanged,
                ),
              ),
            ),
            // Fades out once the surface texture finishes decoding —
            // IgnorePointer once invisible so it doesn't eat the globe's
            // own drag/tap gestures after the fade completes.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _isLoaded,
                child: AnimatedOpacity(
                  opacity: _isLoaded ? 0 : 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  child: const _GlobeLoadingIndicator(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Covers the sphere while its surface texture is still decoding — a
/// pulsing accent-teal ring rather than Material's default
/// [CircularProgressIndicator], which reads as generic chrome against this
/// app's serif/mono/hairline visual language.
class _GlobeLoadingIndicator extends StatefulWidget {
  const _GlobeLoadingIndicator();

  @override
  State<_GlobeLoadingIndicator> createState() => _GlobeLoadingIndicatorState();
}

class _GlobeLoadingIndicatorState extends State<_GlobeLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: colors.paper,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: Tween(begin: 0.3, end: 1.0).animate(_pulse),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            MonoText(l10n.journalGlobeLoading, color: colors.inkMuted),
          ],
        ),
      ),
    );
  }
}

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
