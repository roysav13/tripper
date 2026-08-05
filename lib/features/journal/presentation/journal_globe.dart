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

const _plainDotDiameter = 11.0;
const _photoDotDiameter = 26.0;

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
    this.onEntryTap,
    this.renderGlobe = true,
  });

  final List<JournalEntry> entries;
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
    if (!widget.renderGlobe || _sameEntryIds(oldWidget.entries)) return;
    _syncPoints(oldWidget.entries);
    _maybeFocusLatest();
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
      if (entry.hasLocation) controller.removePoint(entry.id);
    }
    _addPoints(controller);
  }

  void _addPoints(FlutterEarthGlobeController controller) {
    for (final entry in widget.entries) {
      if (!entry.hasLocation) continue;
      final diameter = entry.hasPhotos ? _photoDotDiameter : _plainDotDiameter;
      final onTap =
          widget.onEntryTap == null ? null : () => widget.onEntryTap!(entry);
      controller.addPoint(
        Point(
          id: entry.id,
          coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
          label: entry.placeName ?? entry.summary,
          // Every point renders entirely through labelBuilder now (below)
          // — size 0 means the package's own GPU-native dot draws
          // nothing, so it can never peek out from behind the widget.
          style: const PointStyle(size: 0),
          isLabelVisible: true,
          // Centers a diameter-square widget exactly on the point: the
          // package positions labelBuilder output at
          // `left = pos.dx - labelOffset.dx - width/2`,
          // `top = pos.dy - labelOffset.dy - height`.
          labelOffset: Offset(0, -diameter / 2),
          labelBuilder: (context, point, isHovering, isVisible) =>
              entry.hasPhotos
                  ? _PhotoDot(
                      filePath: entry.photos.first.filePath,
                      onTap: onTap,
                    )
                  : _PlainDot(onTap: onTap),
          // Point.onTap is intentionally left unset. The package's own
          // globe-level GestureDetector hit-tests taps against each
          // point's native (now zero-size) hit region separately from
          // whatever labelBuilder renders, and would call Point.onTap
          // itself if set — double-firing onEntryTap for any tap that
          // happens to land within that residual ~8x8px native region,
          // on top of the tap our own widget's GestureDetector below
          // already handles. Routing taps only through the widget avoids
          // this entirely.
        ),
      );
    }
    for (final (start, end) in journeyConnections(widget.entries)) {
      controller.addPointConnection(
        PointConnection(
          id: '${start.id}->${end.id}',
          start: GlobeCoordinates(start.lat!, start.lng!),
          end: GlobeCoordinates(end.lat!, end.lng!),
          style: PointConnectionStyle(
            color: context.colors.accent.withValues(alpha: 0.6),
            lineWidth: 1.5,
          ),
        ),
      );
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
      surface: const AssetImage('assets/globe/earth_day.jpg'),
    );
    controller.onLoaded = () {
      _addPoints(controller);
      _maybeFocusLatest(animate: false);
    };
    return controller;
  }

  /// Opens on the most recent entry rather than a fixed default, and
  /// re-focuses (animated) only when the latest entry actually changes —
  /// not on every unrelated edit to some other entry.
  void _maybeFocusLatest({bool animate = true}) {
    final controller = _controller;
    if (controller == null || !controller.isReady) return;
    final latest = latestLocatedEntry(widget.entries);
    if (latest == null || latest.id == _focusedEntryId) return;
    _focusedEntryId = latest.id;
    controller.focusOnCoordinates(
      GlobeCoordinates(latest.lat!, latest.lng!),
      animate: animate,
      duration: const Duration(milliseconds: 600),
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
          child: FlutterEarthGlobe(controller: _controller!, radius: radius),
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

/// A small solid-color dot for a located entry with no photo — same
/// labelBuilder/GestureDetector technique as _PhotoDot, so it's immune
/// to the GPU painter's zoom-based size scaling the same way _PhotoDot
/// already was (see the design spec for why this is the fix, not a
/// PointStyle.size tweak — the scaling factor is an internal,
/// undocumented package constant).
class _PlainDot extends StatelessWidget {
  const _PlainDot({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: _plainDotDiameter,
        height: _plainDotDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.accent,
          border: Border.all(color: colors.surface, width: 1.5),
        ),
      ),
    );
  }
}
