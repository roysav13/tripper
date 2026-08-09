import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../places/presentation/map_style.dart';
import '../domain/journal_entry.dart';

// Every dot below is baked into a fixed-pixel-size bitmap and placed via
// a screen-space Marker rather than a real-world-meter Circle. A meters-
// based radius looks fine at one zoom/latitude and either balloons into a
// washed-out blob or shrinks to nothing at another (see dot_misplace.png)
// — a Marker icon stays the same on-screen size at every zoom, which is
// what actually makes this match journal_globe.dart's own zoom-
// compensated native Points (halo glow, solid border ring, core fill/
// photo) instead of merely gesturing at the same three layers.
const _haloAlpha = 0.28;

// Plain (photo-less) dot: halo, paper-colored border ring, accent core —
// the flat-canvas equivalent of the globe's plain Point layering. Built
// once (no per-entry data) and reused for every plain entry.
const _dotCoreRadius = 9.0;
const _dotBorderRadius = 13.0;
const _dotHaloRadius = 21.0;
const _dotHaloBlur = 6.0;
const _dotCanvasSize = 56.0;

// Photo dot: halo, paper-colored ring, drop shadow, the photo itself,
// accent stroke — mirrors the globe's own layering of a native halo +
// border Point behind _PhotoDot's widget (which has its own accent
// border and BoxShadow).
const _photoImageRadius = 30.0;
const _photoStrokeWidth = 3.0;
const _photoRingRadius = 39.0;
const _photoHaloRadius = 55.0;
const _photoHaloBlur = 8.0;
const _photoShadowBlur = 3.0;
const _photoCanvasSize = 128.0;

/// Google Maps needs a platform view, which widget tests can't render.
/// Tests pass `renderMap: false` to get the same non-rendering scaffold as
/// PlacesMapView (SPEC: no network, no platform channels in tests).
///
/// Each located entry is a fixed-size layered-dot [Marker]; entries with a
/// photo render larger, as the photo itself, once its bitmap decodes (a
/// plain dot shows in the meantime). Located entries are connected with a
/// [Polyline] in chronological (loggedAt ascending) order to show trip
/// progression.
class JournalMapView extends StatefulWidget {
  const JournalMapView({
    super.key,
    required this.entries,
    this.renderMap = true,
  });

  final List<JournalEntry> entries;
  final bool renderMap;

  @override
  State<JournalMapView> createState() => _JournalMapViewState();
}

class _JournalMapViewState extends State<JournalMapView> {
  GoogleMapController? _controller;

  /// Keyed by entry id, populated asynchronously as photos decode.
  final Map<String, BitmapDescriptor> _photoMarkers = {};

  /// The shared plain-dot bitmap — built once (it carries no per-entry
  /// data) and reused for every located entry without a photo, plus as a
  /// transient stand-in for photo entries whose bitmap hasn't decoded yet.
  BitmapDescriptor? _plainDotBitmap;

  List<JournalEntry> get _located {
    final located = widget.entries.where((e) => e.hasLocation).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return located;
  }

  bool _initialized = false;

  // Not initState: _loadMarkerBitmaps reads context.colors (a Theme
  // lookup), and establishing an InheritedWidget dependency before
  // initState() completes throws. didChangeDependencies is the first safe
  // point, and runs before the first build.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.renderMap && !_initialized) {
      _initialized = true;
      _loadMarkerBitmaps();
    }
  }

  @override
  void didUpdateWidget(JournalMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.renderMap && widget.entries != oldWidget.entries) {
      _loadMarkerBitmaps();
      _fitToPins();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadMarkerBitmaps() async {
    final colors = context.colors;
    if (_plainDotBitmap == null) {
      final bitmap = await _plainDotMarkerBitmap(
        accentColor: colors.accent,
        paperColor: colors.surface,
      );
      if (mounted) setState(() => _plainDotBitmap = bitmap);
    }
    for (final entry in _located) {
      if (!entry.hasPhotos || _photoMarkers.containsKey(entry.id)) continue;
      final path = entry.photos.first.filePath;
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final bitmap = await _photoMarkerBitmap(
          await file.readAsBytes(),
          accentColor: colors.accent,
          paperColor: colors.surface,
          shadowColor: colors.inkPrimary,
        );
        if (mounted) setState(() => _photoMarkers[entry.id] = bitmap);
      } catch (_) {
        // Corrupt/unreadable photo: entry falls back to the plain dot.
      }
    }
  }

  Future<void> _fitToPins() async {
    final controller = _controller;
    final located = _located;
    if (controller == null || located.isEmpty) return;
    if (located.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(located.single.lat!, located.single.lng!),
          12,
        ),
      );
      return;
    }
    var minLat = located.first.lat!;
    var maxLat = minLat;
    var minLng = located.first.lng!;
    var maxLng = minLng;
    for (final e in located) {
      minLat = e.lat! < minLat ? e.lat! : minLat;
      maxLat = e.lat! > maxLat ? e.lat! : maxLat;
      minLng = e.lng! < minLng ? e.lng! : minLng;
      maxLng = e.lng! > maxLng ? e.lng! : maxLng;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        48,
      ),
    );
  }

  /// One layered-dot marker per located entry — the photo bitmap once it's
  /// decoded, the shared plain-dot bitmap otherwise (including as a
  /// transient stand-in for a photo entry still decoding). Both bitmaps
  /// are fixed-pixel-size, so every dot renders identically at any zoom
  /// or latitude instead of the real-world-meter Circle approach this
  /// replaced.
  Set<Marker> _markerSet() {
    final plainDot = _plainDotBitmap;
    if (plainDot == null) return {};
    final markers = <Marker>{};
    for (final e in _located) {
      markers.add(
        Marker(
          markerId: MarkerId(e.id),
          position: LatLng(e.lat!, e.lng!),
          icon: _photoMarkers[e.id] ?? plainDot,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: e.summary),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _polylines(AppColors colors) {
    final located = _located;
    if (located.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('journal-progression'),
        points: [for (final e in located) LatLng(e.lat!, e.lng!)],
        // Same muted accent-alpha treatment as the globe's route arcs
        // (PointConnectionStyle in journal_globe.dart) — a quieter trail
        // line that doesn't compete with the halo/border/core dots.
        color: colors.accent.withValues(alpha: 0.6),
        width: 2,
        geodesic: true,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnlocated = widget.entries.any((e) => !e.hasLocation);

    if (!widget.renderMap) {
      // Test/preview scaffold: no platform view, entries as tappable rows.
      return ColoredBox(
        color: colors.paper,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final entry in _located)
              Semantics(
                label: entry.summary,
                child: Icon(
                  entry.hasPhotos ? Icons.photo_camera : Icons.circle,
                  color: colors.accent,
                ),
              ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _located.isEmpty
                ? const LatLng(25, 15)
                : LatLng(_located.first.lat!, _located.first.lng!),
            zoom: _located.isEmpty ? 2 : 11,
          ),
          style: isDark ? kMapStyleDark : kMapStyleLight,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          markers: _markerSet(),
          polylines: _polylines(colors),
          onMapCreated: (controller) {
            _controller = controller;
            _fitToPins();
          },
        ),
        if (hasUnlocated)
          PositionedDirectional(
            top: 8,
            start: 8,
            end: 8,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              // Same dark-glass pill treatment as the globe's floating
              // stats line (_GlassPill in trip_journal_tab.dart) — mono
              // metadata type, translucent ink backdrop — instead of a
              // plain opaque Material card.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.inkPrimary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: MonoText(
                    l10n.journalMapLocationHint,
                    color: colors.surface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Builds the shared plain (photo-less) dot bitmap: halo, paper-colored
/// border ring, accent core — the flat-canvas equivalent of
/// journal_globe.dart's plain-Point layering (halo Point, border-ring
/// Point, core Point). Carries no per-entry data, so callers build this
/// once and reuse it.
Future<BitmapDescriptor> _plainDotMarkerBitmap({
  required Color accentColor,
  required Color paperColor,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(_dotCanvasSize / 2, _dotCanvasSize / 2);

  canvas.drawCircle(
    center,
    _dotHaloRadius,
    Paint()
      ..color = accentColor.withValues(alpha: _haloAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _dotHaloBlur),
  );
  canvas.drawCircle(center, _dotBorderRadius, Paint()..color = paperColor);
  canvas.drawCircle(center, _dotCoreRadius, Paint()..color = accentColor);

  final picture = recorder.endRecording();
  final rendered =
      await picture.toImage(_dotCanvasSize.toInt(), _dotCanvasSize.toInt());
  final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    byteData!.buffer.asUint8List(),
    width: _dotCanvasSize,
    height: _dotCanvasSize,
  );
}

/// Decodes [bytes] and draws them circle-clipped ("cover" crop, centered)
/// with a soft halo, a paper-colored ring, a drop shadow, and an
/// [accentColor] stroke around the photo — the flat-canvas equivalent of
/// journal_globe.dart's halo/border Points behind _PhotoDot's own accent
/// border + BoxShadow lift off the background.
Future<BitmapDescriptor> _photoMarkerBitmap(
  Uint8List bytes, {
  required Color accentColor,
  required Color paperColor,
  required Color shadowColor,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(_photoCanvasSize / 2, _photoCanvasSize / 2);
  const strokeRadius = _photoImageRadius + _photoStrokeWidth / 2;

  canvas.drawCircle(
    center,
    _photoHaloRadius,
    Paint()
      ..color = accentColor.withValues(alpha: _haloAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _photoHaloBlur),
  );
  // Drop shadow, drawn before the opaque ring/photo paint over it —
  // unclipped, so its blur can spread past the ring's edge.
  canvas.drawCircle(
    center.translate(0, 2),
    _photoRingRadius,
    Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _photoShadowBlur),
  );
  canvas.drawCircle(center, _photoRingRadius, Paint()..color = paperColor);

  canvas.save();
  canvas.clipPath(
    Path()..addOval(Rect.fromCircle(center: center, radius: _photoImageRadius)),
  );
  final srcSize = image.width < image.height
      ? image.width.toDouble()
      : image.height.toDouble();
  final srcRect = Rect.fromCenter(
    center: Offset(image.width / 2, image.height / 2),
    width: srcSize,
    height: srcSize,
  );
  canvas.drawImageRect(
    image,
    srcRect,
    Rect.fromCircle(center: center, radius: _photoImageRadius),
    Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high,
  );
  canvas.restore();

  canvas.drawCircle(
    center,
    strokeRadius,
    Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _photoStrokeWidth,
  );

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(
    _photoCanvasSize.toInt(),
    _photoCanvasSize.toInt(),
  );
  final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    byteData!.buffer.asUint8List(),
    width: _photoCanvasSize,
    height: _photoCanvasSize,
  );
}
