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

const _markerPx = 96;
const _markerSize = 96.0;
const _markerBorderWidth = 4.0;
// Reserved, unclipped canvas margin around the photo circle so its drop
// shadow (see _photoMarkerBitmap) has room to blur outward instead of
// being cut off at the bitmap's edge.
const _markerShadowMargin = 8.0;

// Halo / border / core radii (real-world meters, so they scale with the
// map's own zoom) — the flat-map equivalent of journal_globe.dart's
// three-layer native Point treatment (halo glow, solid border ring, core
// fill), carried over so a trip's route reads the same way in both
// views. Photo entries get a larger footprint, matching the globe's
// larger photo-dot sizing relative to its plain dots.
const _haloAlpha = 0.28;
const _plainCoreRadiusMeters = 40.0;
const _plainBorderRadiusMeters = 60.0;
const _plainHaloRadiusMeters = 110.0;
// Only used as a transient fallback while a photo entry's marker bitmap
// is still decoding — see _circles below.
const _photoCoreRadiusMeters = 90.0;
const _photoBorderRadiusMeters = 120.0;
const _photoHaloRadiusMeters = 200.0;

/// Google Maps needs a platform view, which widget tests can't render.
/// Tests pass `renderMap: false` to get the same non-rendering scaffold as
/// PlacesMapView (SPEC: no network, no platform channels in tests).
///
/// Each located entry is a small [Circle]; entries with a photo render
/// larger, as the photo itself via a custom [Marker] bitmap once decoded.
/// Located entries are connected with a [Polyline] in chronological
/// (loggedAt ascending) order to show trip progression.
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

  List<JournalEntry> get _located {
    final located = widget.entries.where((e) => e.hasLocation).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return located;
  }

  bool _initialized = false;

  // Not initState: _loadPhotoMarkers reads context.colors (a Theme lookup),
  // and establishing an InheritedWidget dependency before initState()
  // completes throws. didChangeDependencies is the first safe point, and
  // runs before the first build.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.renderMap && !_initialized) {
      _initialized = true;
      _loadPhotoMarkers();
    }
  }

  @override
  void didUpdateWidget(JournalMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.renderMap && widget.entries != oldWidget.entries) {
      _loadPhotoMarkers();
      _fitToPins();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadPhotoMarkers() async {
    final colors = context.colors;
    for (final entry in _located) {
      if (!entry.hasPhotos || _photoMarkers.containsKey(entry.id)) continue;
      final path = entry.photos.first.filePath;
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final bitmap = await _photoMarkerBitmap(
          await file.readAsBytes(),
          colors.accent,
          colors.inkPrimary,
        );
        if (mounted) setState(() => _photoMarkers[entry.id] = bitmap);
      } catch (_) {
        // Corrupt/unreadable photo: entry falls back to a plain circle.
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

  Set<Circle> _circles(AppColors colors) {
    final circles = <Circle>{};
    for (final e in _located) {
      final hasMarker = e.hasPhotos && _photoMarkers.containsKey(e.id);
      // Halo renders for every located entry, marker or not — same as the
      // globe, where the halo sits behind a photo dot rather than being
      // replaced by it.
      circles.add(
        Circle(
          circleId: CircleId('${e.id}-halo'),
          center: LatLng(e.lat!, e.lng!),
          radius: e.hasPhotos ? _photoHaloRadiusMeters : _plainHaloRadiusMeters,
          fillColor: colors.accent.withValues(alpha: _haloAlpha),
          strokeColor: Colors.transparent,
          strokeWidth: 0,
          zIndex: 0,
        ),
      );
      if (hasMarker)
        continue; // border + core are baked into the marker bitmap.
      circles.add(
        Circle(
          circleId: CircleId('${e.id}-border'),
          center: LatLng(e.lat!, e.lng!),
          radius:
              e.hasPhotos ? _photoBorderRadiusMeters : _plainBorderRadiusMeters,
          fillColor: colors.surface,
          strokeColor: Colors.transparent,
          strokeWidth: 0,
          zIndex: 1,
        ),
      );
      circles.add(
        Circle(
          circleId: CircleId(e.id),
          center: LatLng(e.lat!, e.lng!),
          radius: e.hasPhotos ? _photoCoreRadiusMeters : _plainCoreRadiusMeters,
          fillColor: colors.accent,
          strokeColor: Colors.transparent,
          strokeWidth: 0,
          zIndex: 2,
        ),
      );
    }
    return circles;
  }

  Set<Marker> get _photoMarkerSet {
    final markers = <Marker>{};
    for (final e in _located) {
      final bitmap = _photoMarkers[e.id];
      if (bitmap == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId(e.id),
          position: LatLng(e.lat!, e.lng!),
          icon: bitmap,
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
          circles: _circles(colors),
          markers: _photoMarkerSet,
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

/// Decodes [bytes] and draws them circle-clipped ("cover" crop, centered)
/// with a [borderColor] ring and a soft [shadowColor] drop shadow,
/// returning a marker bitmap for GoogleMap — the flat-canvas equivalent of
/// journal_globe.dart's _PhotoDot (accent border + BoxShadow lift off the
/// background).
Future<BitmapDescriptor> _photoMarkerBitmap(
  Uint8List bytes,
  Color borderColor,
  Color shadowColor,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = _markerSize;
  final rect = Rect.fromLTWH(0, 0, size, size);
  // The photo itself sits inside this radius; the border stroke sits just
  // outside it. _markerShadowMargin keeps both, plus the shadow's blur,
  // clear of the bitmap's raster edge.
  final imageRadius = size / 2 - _markerBorderWidth - _markerShadowMargin;
  final borderRadius = imageRadius + _markerBorderWidth / 2;

  // Drop shadow, drawn first so the opaque border/photo paint over it —
  // unclipped, so its blur can spread past the border ring's edge.
  canvas.drawCircle(
    rect.center.translate(0, 2),
    borderRadius,
    Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  canvas.save();
  canvas.clipPath(
    Path()..addOval(Rect.fromCircle(center: rect.center, radius: imageRadius)),
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
    Rect.fromCircle(center: rect.center, radius: imageRadius),
    Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high,
  );
  canvas.restore();

  canvas.drawCircle(
    rect.center,
    borderRadius,
    Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _markerBorderWidth,
  );

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(_markerPx, _markerPx);
  final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    byteData!.buffer.asUint8List(),
    width: _markerSize,
    height: _markerSize,
  );
}
