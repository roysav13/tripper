import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../places/presentation/map_style.dart';
import '../domain/journal_entry.dart';

const _markerPx = 96;
const _markerSize = 96.0;
const _markerBorderWidth = 4.0;
const _plainCircleRadiusMeters = 40.0;
const _photoCircleRadiusMeters = 90.0;

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
      if (e.hasPhotos && _photoMarkers.containsKey(e.id)) {
        continue; // rendered as a photo Marker instead.
      }
      circles.add(
        Circle(
          circleId: CircleId(e.id),
          center: LatLng(e.lat!, e.lng!),
          // Radius is real-world meters, so it scales with zoom — chosen to
          // read clearly at typical trip/city zoom levels.
          radius:
              e.hasPhotos ? _photoCircleRadiusMeters : _plainCircleRadiusMeters,
          fillColor: colors.accent.withValues(alpha: e.hasPhotos ? 0.35 : 0.55),
          strokeColor: colors.accent,
          strokeWidth: 1,
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
        color: colors.accent,
        width: 3,
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
            child: Material(
              color: colors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  l10n.journalMapLocationHint,
                  style: TextStyle(color: colors.inkMuted, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Decodes [bytes] and draws them circle-clipped ("cover" crop, centered)
/// with a [borderColor] ring, returning a marker bitmap for GoogleMap.
Future<BitmapDescriptor> _photoMarkerBitmap(
  Uint8List bytes,
  Color borderColor,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = _markerSize;
  final rect = Rect.fromLTWH(0, 0, size, size);

  canvas.clipPath(
    Path()..addOval(rect.deflate(_markerBorderWidth)),
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
    rect,
    Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high,
  );
  canvas.drawCircle(
    rect.center,
    size / 2 - _markerBorderWidth / 2,
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
