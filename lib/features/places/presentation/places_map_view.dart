import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';
import 'map_style.dart';

// Layered-dot bitmap markers: halo, ring, core — the same three-layer
// technique and proportions journal_map_view.dart's plain dot already
// established for the Journal map (matching "the globe's dot language"
// per the redesign spec, §6). Only the want-to-go state gets the glowing
// halo; been-there stays a plain ring+core, so the two pin states read as
// "glowing" vs. "quiet" at a glance without needing a second hue
// (component rule 5: "coral+glow = want-to-go, muted parchment/grey =
// been-there").
const _dotCanvasSize = 56.0;
const _dotCoreRadius = 9.0;
const _dotBorderRadius = 13.0;
const _dotHaloRadius = 21.0;
const _dotHaloBlur = 6.0;
const _haloAlpha = 0.28;

/// Dots are regenerated at a smaller scale as the camera zooms out, so a
/// cluster of nearby places doesn't turn into a solid blob of full-size
/// circles at the world/country zoom levels — the world is smaller on
/// screen, so the dots marking it should be too. Bucketed rather than
/// continuous: regenerating the bitmaps is real (if cheap) async work, so
/// this only fires on a zoom-tier crossing, not on every camera frame.
double markerScaleForZoom(double zoom) {
  if (zoom <= 4) return 0.5;
  if (zoom <= 7) return 0.65;
  if (zoom <= 10) return 0.8;
  if (zoom <= 13) return 0.9;
  return 1.0;
}

/// Google Maps needs a platform view, which widget tests can't render.
/// Tests pass `renderMap: false` to get the pin/label scaffolding without
/// the native surface (SPEC: no network, no platform channels in tests).
///
/// Styling is the app's own authored light/dark palette (`map_style.dart`,
/// Phase 3 — supersedes the 2026-07-23 "stock Google Maps look" decision):
/// custom colors/labels, but standard Google chrome (zoom controls, map
/// toolbar, my-location button + blue dot), and default markers are
/// replaced with custom layered-dot bitmaps (see `_dotMarkerBitmap` below)
/// — a hybrid of "our palette" and "familiar map UX".
class PlacesMapView extends StatefulWidget {
  const PlacesMapView({
    super.key,
    required this.places,
    this.onPlaceTap,
    this.renderMap = true,
    this.focusPlaceId,
    this.onFocusHandled,
  });

  final List<Place> places;
  final void Function(Place place)? onPlaceTap;
  final bool renderMap;

  /// Set from "View on map" on a list row: fly the camera to this place
  /// and pop its info window instead of the generic fit-to-all-pins.
  final String? focusPlaceId;

  /// Called once the focus above has been applied, so the caller can clear
  /// its selection (a StateProvider, typically) and avoid re-focusing on
  /// every rebuild.
  final VoidCallback? onFocusHandled;

  @override
  State<PlacesMapView> createState() => _PlacesMapViewState();
}

class _PlacesMapViewState extends State<PlacesMapView> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;

  /// Synchronous flag to guard against concurrent _loadMarkerBitmaps calls
  /// during the async bitmap generation window. Set to true immediately
  /// before the first await, preventing re-entrancy if didChangeDependencies
  /// fires again (e.g., theme/locale change).
  bool _markersInitialized = false;

  /// Built once per widget lifetime at the default (full) scale (they
  /// carry no per-place data) and reused for every marker of that state
  /// until [_regenerateMarkersForZoom] rebuilds them at a new zoom tier.
  BitmapDescriptor? _wantMarker;
  BitmapDescriptor? _beenMarker;

  /// The zoom-tier scale the current [_wantMarker]/[_beenMarker] were
  /// drawn at — `null` until the first generation completes. Compared
  /// against [markerScaleForZoom] on every camera-idle so bitmaps are
  /// only regenerated on an actual tier crossing, not on every frame of a
  /// pinch gesture.
  double? _markerScale;

  List<Place> get _located =>
      widget.places.where((p) => p.hasLocation).toList();

  // Not initState: _loadMarkerBitmaps reads context.colors (a Theme
  // lookup), and establishing an InheritedWidget dependency before
  // initState() completes throws — same reasoning as
  // journal_map_view.dart's didChangeDependencies override.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.renderMap && !_markersInitialized) {
      _markersInitialized = true;
      _loadMarkerBitmaps(1);
    }
  }

  Future<void> _loadMarkerBitmaps(double scale) async {
    final colors = context.colors;
    final want = await _dotMarkerBitmap(
      coreColor: colors.accent,
      ringColor: colors.surface,
      glow: true,
      scale: scale,
    );
    final been = await _dotMarkerBitmap(
      coreColor: colors.inkMuted,
      ringColor: colors.surface,
      glow: false,
      scale: scale,
    );
    if (!mounted) return;
    setState(() {
      _wantMarker = want;
      _beenMarker = been;
      _markerScale = scale;
    });
  }

  /// Reads the live camera zoom and, only if it crossed into a different
  /// [markerScaleForZoom] tier since the markers were last drawn,
  /// regenerates them at the new scale. Called once right after the map
  /// is created (before any camera animation has necessarily run) and
  /// again on every `onCameraIdle`.
  Future<void> _regenerateMarkersForZoom() async {
    final controller = _controller;
    if (controller == null) return;
    final zoom = await controller.getZoomLevel();
    if (!mounted) return;
    final scale = markerScaleForZoom(zoom);
    if (scale == _markerScale) return;
    await _loadMarkerBitmaps(scale);
  }

  @override
  void didUpdateWidget(PlacesMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusPlaceId != null &&
        widget.focusPlaceId != oldWidget.focusPlaceId) {
      _focusOn(widget.focusPlaceId!);
    } else if (widget.places.length != oldWidget.places.length) {
      _fitToPins();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
    for (final p in located) {
      minLat = p.lat! < minLat ? p.lat! : minLat;
      maxLat = p.lat! > maxLat ? p.lat! : maxLat;
      minLng = p.lng! < minLng ? p.lng! : minLng;
      maxLng = p.lng! > maxLng ? p.lng! : maxLng;
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

  Future<void> _focusOn(String placeId) async {
    final controller = _controller;
    if (controller == null) return;
    Place? place;
    for (final p in _located) {
      if (p.id == placeId) {
        place = p;
        break;
      }
    }
    if (place != null) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(place.lat!, place.lng!), 15),
      );
      await controller.showMarkerInfoWindow(MarkerId(placeId));
    }
    widget.onFocusHandled?.call();
  }

  IconData get _layersIcon {
    switch (_mapType) {
      case MapType.hybrid:
        return Icons.satellite_alt;
      case MapType.terrain:
        return Icons.terrain;
      case MapType.normal:
      default:
        return Icons.layers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.renderMap) {
      // Test/preview scaffold: no platform view, pins as tappable rows.
      return ColoredBox(
        color: colors.paper,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final place in _located)
              Semantics(
                button: widget.onPlaceTap != null,
                label: '${place.name}, '
                    '${place.isVisited ? "visited" : "want to go"}',
                child: IconButton(
                  icon: Icon(
                    place.isVisited ? Icons.check_circle : Icons.place,
                    color: place.isVisited ? colors.inkMuted : colors.accent,
                  ),
                  onPressed: widget.onPlaceTap == null
                      ? null
                      : () => widget.onPlaceTap!(place),
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
          mapType: _mapType,
          style: isDark ? kMapStyleDark : kMapStyleLight,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: true,
          zoomControlsEnabled: true,
          markers: {
            for (final place in _located)
              Marker(
                markerId: MarkerId(place.id),
                position: LatLng(place.lat!, place.lng!),
                icon: (place.isVisited ? _beenMarker : _wantMarker) ??
                    BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                infoWindow: InfoWindow(
                  title: place.name,
                  snippet: [
                    place.isVisited
                        ? l10n.placesBeenSection
                        : l10n.placesWantSection,
                    if (place.city.isNotEmpty) place.city,
                    if (place.country.isNotEmpty) place.country,
                  ].join(' · '),
                  onTap: widget.onPlaceTap == null
                      ? null
                      : () => widget.onPlaceTap!(place),
                ),
                onTap: widget.onPlaceTap == null
                    ? null
                    : () => widget.onPlaceTap!(place),
              ),
          },
          onMapCreated: (controller) {
            _controller = controller;
            final focusId = widget.focusPlaceId;
            if (focusId != null) {
              _focusOn(focusId);
            } else {
              _fitToPins();
            }
            _regenerateMarkersForZoom();
          },
          onCameraIdle: _regenerateMarkersForZoom,
        ),
        // Soften the hard edge where the app bar / bottom nav meet the map
        // — a quiet ink-tinted fade, not a new accent (built from
        // ink.primary at low alpha, matches Google Maps' own top-shadow
        // treatment). Purely decorative, so it must never eat map gestures.
        _EdgeShadow(alignment: Alignment.topCenter, colors: colors),
        _EdgeShadow(alignment: Alignment.bottomCenter, colors: colors),
        // Stock Google Maps layers button — opens a Default/Satellite/
        // Terrain picker, same as the real app's layers panel.
        PositionedDirectional(
          end: 8,
          bottom: 88,
          child: Material(
            color: colors.surface,
            shape: const CircleBorder(),
            elevation: 2,
            child: PopupMenuButton<MapType>(
              tooltip: l10n.mapLayersButton,
              icon: Icon(_layersIcon, color: colors.inkPrimary),
              initialValue: _mapType,
              onSelected: (type) => setState(() => _mapType = type),
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: MapType.normal,
                  checked: _mapType == MapType.normal,
                  child: Text(l10n.mapLayerNormal),
                ),
                CheckedPopupMenuItem(
                  value: MapType.hybrid,
                  checked: _mapType == MapType.hybrid,
                  child: Text(l10n.mapLayerSatellite),
                ),
                CheckedPopupMenuItem(
                  value: MapType.terrain,
                  checked: _mapType == MapType.terrain,
                  child: Text(l10n.mapLayerTerrain),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A quiet gradient strip pinned to the top or bottom edge of the map,
/// fading from a faint ink tint down to nothing — dims the seam where the
/// app bar / bottom nav meet the map instead of a flat hard cut.
class _EdgeShadow extends StatelessWidget {
  const _EdgeShadow({required this.alignment, required this.colors});

  final Alignment alignment;
  final AppColors colors;

  static const _height = 28.0;
  static const _peakAlpha = 0.10;

  @override
  Widget build(BuildContext context) {
    final atTop = alignment == Alignment.topCenter;
    return PositionedDirectional(
      top: atTop ? 0 : null,
      bottom: atTop ? null : 0,
      start: 0,
      end: 0,
      height: _height,
      // Decorative only — never intercepts map pan/zoom/marker taps.
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: atTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: atTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                colors.inkPrimary.withValues(alpha: _peakAlpha),
                colors.inkPrimary.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a halo/ring/core dot to a fixed-pixel-size PNG and wraps it as a
/// [BitmapDescriptor] — the flat-canvas equivalent of journal_globe.dart's
/// native Point layering, matching journal_map_view.dart's own
/// `_plainDotMarkerBitmap` proportions so map pins and journal dots read
/// as the same visual language. [glow] off skips the halo layer entirely
/// (the been-there / "quiet" state) rather than drawing it at zero alpha.
Future<BitmapDescriptor> _dotMarkerBitmap({
  required Color coreColor,
  required Color ringColor,
  required bool glow,
  required double scale,
}) async {
  final canvasSize = _dotCanvasSize * scale;
  final coreRadius = _dotCoreRadius * scale;
  final borderRadius = _dotBorderRadius * scale;
  final haloRadius = _dotHaloRadius * scale;
  final haloBlur = _dotHaloBlur * scale;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(canvasSize / 2, canvasSize / 2);

  if (glow) {
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..color = coreColor.withValues(alpha: _haloAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, haloBlur),
    );
  }
  canvas.drawCircle(center, borderRadius, Paint()..color = ringColor);
  canvas.drawCircle(center, coreRadius, Paint()..color = coreColor);

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(
    canvasSize.round(),
    canvasSize.round(),
  );
  final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    byteData!.buffer.asUint8List(),
    width: canvasSize,
    height: canvasSize,
  );
}
