import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';

import '../../../core/theme/app_colors.dart';
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
const _haloDotSize = 6.0;
const _photoDotDiameter = 26.0;
const _photoHaloDotSize = 8.0;
// Monochrome teal — CLAUDE.md's two-accents rule (teal for actions/
// places, rust reserved for warnings only) means the halo has to be a
// low-alpha version of the same accent, not a new hue.
const _haloAlpha = 0.28;

// Globe.GL-style arcs default the curve height (via the point_connection
// package's own curveScale=1.5 default) to something that reads as a
// steep, ballistic arc — closer to a flight path than a route line on the
// same globe you're standing on. This flattens the arc noticeably closer
// to the sphere's surface.
const _arcCurveScale = 0.4;

/// flutter_earth_globe renders via GPU fragment shaders, which widget tests
/// can't render. Tests pass `renderGlobe: false` to get tappable
/// entry-icon scaffolding without ever constructing
/// `FlutterEarthGlobeController` (SPEC: no GPU/platform dependency in
/// tests) — same seam as PlacesMapView's `renderMap: false`.
///
/// Texture is a locally bundled asset (assets/globe/earth_day.jpg) — no
/// network fetch to render (offline rule, SPEC §3.1.2). Points are this
/// trip's located journal entries — an entry IS a visited place (see
/// place_visit_actions.dart) — not read from Places directly.
class JournalGlobe extends StatefulWidget {
  const JournalGlobe({
    super.key,
    required this.entries,
    this.selectedEntryId,
    this.liveFollowEntryId,
    this.onEntryTap,
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
  final bool renderGlobe;

  @override
  State<JournalGlobe> createState() => _JournalGlobeState();
}

class _JournalGlobeState extends State<JournalGlobe> {
  FlutterEarthGlobeController? _controller;
  bool _initialized = false;
  String? _focusedEntryId;

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
      _syncPoints(oldWidget.entries);
      if (widget.selectedEntryId == null && widget.liveFollowEntryId == null) {
        _maybeFocusLatest();
      }
    }
  }

  // Compares the fields the globe actually renders per entry — id, lat,
  // lng, and the first photo's path (which decides dot-vs-thumbnail and
  // which thumbnail) — not just id/order. Journal entries are edited
  // constantly (unlike the visited Places this replaced, whose coordinates
  // rarely changed), so an identity-only check would miss a location being
  // added/moved or a first photo being added to a previously photo-less
  // entry.
  bool _sameEntryIds(List<JournalEntry> previous) {
    if (previous.length != widget.entries.length) return false;
    for (var i = 0; i < previous.length; i++) {
      final prevEntry = previous[i];
      final nextEntry = widget.entries[i];
      if (prevEntry.id != nextEntry.id) return false;
      if (prevEntry.lat != nextEntry.lat) return false;
      if (prevEntry.lng != nextEntry.lng) return false;
      final prevPhotoPath =
          prevEntry.hasPhotos ? prevEntry.photos.first.filePath : null;
      final nextPhotoPath =
          nextEntry.hasPhotos ? nextEntry.photos.first.filePath : null;
      if (prevPhotoPath != nextPhotoPath) return false;
    }
    return true;
  }

  // Diffed in place via addPoint/removePoint (and addPointConnection/
  // removePointConnection) — never dispose+recreate the controller here.
  // flutter_earth_globe's own FlutterEarthGlobe widget disposes
  // controller.rotationController itself when unmounted; disposing it
  // again ourselves double-frees the same AnimationController and
  // crashes ("AnimationController.dispose() called more than once").
  void _syncPoints(List<JournalEntry> previous) {
    final controller = _controller;
    if (controller == null) return;
    for (final connection in controller.connections.toList()) {
      controller.removePointConnection(connection.id);
    }
    for (final entry in previous) {
      if (entry.hasLocation) {
        controller.removePoint(entry.id);
        controller.removePoint('${entry.id}-halo');
      }
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
    for (final entry in widget.entries) {
      if (!entry.hasLocation) continue;
      final onTap =
          widget.onEntryTap == null ? null : () => widget.onEntryTap!(entry);
      // Halo: a larger, low-alpha native point at the same coordinates as
      // the dot below, added first so it paints (and therefore sits)
      // behind it — this needs on-device confirmation like every other
      // dot-visual change in this file; the package's actual draw order
      // isn't guaranteed by its public API.
      controller.addPoint(
        Point(
          id: '${entry.id}-halo',
          coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
          style: PointStyle(
            size: (entry.hasPhotos ? _photoHaloDotSize : _haloDotSize) *
                compensation,
            color: colors.accent.withValues(alpha: _haloAlpha),
          ),
          // The halo's hit-rect is strictly larger than the core dot's and
          // is tested first (added first, same coordinates so depth ties,
          // and the package's sort is only stable for small point counts)
          // — the package marks a click "handled" on the first hit
          // regardless of whether that point has a handler, so a halo
          // with no onTap silently swallows taps meant for the dot below
          // it. Left null for photo entries — _PhotoDot's own
          // GestureDetector handles those; wiring both would double-fire.
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
            // native way to show an image on a point. size: 0 suppresses
            // the (otherwise pointless) native dot underneath it.
            style: const PointStyle(size: 0),
            isLabelVisible: true,
            // Centers a _photoDotDiameter-square widget exactly on the
            // point: the package positions labelBuilder output at
            // `left = pos.dx - labelOffset.dx - width/2`,
            // `top = pos.dy - labelOffset.dy - height`.
            labelOffset: const Offset(0, -_photoDotDiameter / 2),
            labelBuilder: (context, point, isHovering, isVisible) =>
                _PhotoDot(filePath: entry.photos.first.filePath, onTap: onTap),
            // Point.onTap is intentionally left unset — see _PhotoDot's
            // own GestureDetector. Setting both would double-fire
            // onEntryTap for taps landing in the native point's small
            // residual hit region.
          ),
        );
      } else {
        controller.addPoint(
          Point(
            id: entry.id,
            coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
            label: entry.placeName ?? entry.summary,
            // Native GPU-rendered dot: cheap, and perfectly in sync with
            // the sphere's rotation every frame by construction (the
            // shader paints it — no separate widget-position recompute
            // pass, unlike the labelBuilder path above). A prior round
            // made every dot widget-rendered instead, purely to dodge
            // the package's built-in zoom-scaling, and that made
            // rotation noticeably less smooth (every dot's position
            // became a real widget rebuild on every animation frame).
            // _handleZoomChanged counteracts the zoom-scaling directly
            // instead, so this can stay native/cheap AND zoom-stable.
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
    }
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
    final compensation = 1 / math.pow(2, zoom);
    for (final entry in widget.entries) {
      if (!entry.hasLocation) continue;
      final haloBase = entry.hasPhotos ? _photoHaloDotSize : _haloDotSize;
      _rescalePoint(controller, '${entry.id}-halo', haloBase * compensation);
      if (!entry.hasPhotos) {
        _rescalePoint(controller, entry.id, _plainDotSize * compensation);
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
      surface: const AssetImage('assets/globe/earth_day.jpg'),
      // Default is 2.5 (~5.7x, radius = baseRadius * 2^zoom). A prior
      // round raised this to 5 (~32x) for legibility, but that pushes far
      // past what the bundled 2048x1024 earth_day.jpg texture actually
      // has detail for — the sphere is rasterized by resampling that
      // fixed-resolution texture (see RotatingGlobeState.buildSphere),
      // so zooming past its native detail only blurs pre-existing pixels
      // larger, it doesn't reveal anything sharper. 3.5 (~11x) is chosen
      // to sit close to where a 2048px-wide equirectangular texture's own
      // texel density starts to noticeably soften under this package's
      // per-pixel bilinear resampling — meaningfully closer than the
      // package's own 2.5 default, without diving deep into visible
      // blur. Revisiting this needs either a higher-resolution texture
      // asset or an on-device call on how much softening is acceptable.
      maxZoom: 3.5,
    );
    controller.onLoaded = () {
      _addPoints(controller);
      if (widget.selectedEntryId != null) {
        _maybeFocusSelected();
      } else {
        _maybeFocusLatest(instant: true);
      }
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
      // tappable icons (photo-camera for entries with a photo, plain dot
      // otherwise) — mirrors JournalMapView's own renderMap:false seam.
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
                        entry.hasPhotos ? Icons.photo_camera : Icons.circle,
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
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: size),
          child: FlutterEarthGlobe(
            controller: _controller!,
            radius: radius,
            onZoomChanged: _handleZoomChanged,
          ),
        );
      },
    );
  }
}

/// A circular, accent-bordered photo thumbnail rendered at a point's
/// screen position via Point.labelBuilder (the package has no built-in
/// image support for points). Wraps itself in a GestureDetector — see
/// the comment on Point.onTap in _addPoints for why tap handling lives
/// here instead of on the Point itself.
class _PhotoDot extends StatelessWidget {
  const _PhotoDot({required this.filePath, this.onTap});

  final String filePath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: _photoDotDiameter,
        height: _photoDotDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.accent, width: 1.5),
        ),
        child: ClipOval(
          child: Image.file(
            File(filePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(color: colors.paper),
          ),
        ),
      ),
    );
  }
}
