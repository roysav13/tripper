import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';

import '../../../core/theme/app_colors.dart';
import '../../places/domain/place.dart';

/// flutter_earth_globe renders via GPU fragment shaders, which widget tests
/// can't render. Tests pass `renderGlobe: false` to get tappable place-icon
/// scaffolding without ever constructing `FlutterEarthGlobeController`
/// (SPEC: no GPU/platform dependency in tests) — same seam as
/// PlacesMapView's `renderMap: false`.
///
/// Texture is a locally bundled asset (assets/globe/earth_day.jpg) — no
/// network fetch to render (offline rule, SPEC §3.1.2). Points are this
/// trip's visited Places, not journal-entry locations (design decision).
class JournalGlobe extends StatefulWidget {
  const JournalGlobe({
    super.key,
    required this.places,
    this.onPlaceTap,
    this.renderGlobe = true,
  });

  final List<Place> places;
  final void Function(Place place)? onPlaceTap;
  final bool renderGlobe;

  @override
  State<JournalGlobe> createState() => _JournalGlobeState();
}

class _JournalGlobeState extends State<JournalGlobe> {
  FlutterEarthGlobeController? _controller;
  bool _initialized = false;

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
    if (!widget.renderGlobe || _samePlaceIds(oldWidget.places)) return;
    _syncPoints(oldWidget.places);
  }

  bool _samePlaceIds(List<Place> previous) {
    if (previous.length != widget.places.length) return false;
    for (var i = 0; i < previous.length; i++) {
      if (previous[i].id != widget.places[i].id) return false;
    }
    return true;
  }

  // Diffed in place via addPoint/removePoint — never dispose+recreate the
  // controller here. flutter_earth_globe's own FlutterEarthGlobe widget
  // disposes controller.rotationController itself when unmounted; disposing
  // it again ourselves double-frees the same AnimationController and
  // crashes ("AnimationController.dispose() called more than once").
  void _syncPoints(List<Place> previous) {
    final controller = _controller;
    if (controller == null) return;
    for (final place in previous) {
      if (place.hasLocation) controller.removePoint(place.id);
    }
    _addPoints(controller);
  }

  void _addPoints(FlutterEarthGlobeController controller) {
    final colors = context.colors;
    for (final place in widget.places) {
      if (!place.hasLocation) continue;
      controller.addPoint(
        Point(
          id: place.id,
          coordinates: GlobeCoordinates(place.lat!, place.lng!),
          label: place.name,
          style: PointStyle(color: colors.accent),
          onTap: widget.onPlaceTap == null
              ? null
              : () => widget.onPlaceTap!(place),
        ),
      );
    }
  }

  FlutterEarthGlobeController _buildController() {
    final controller = FlutterEarthGlobeController(
      rotationSpeed: 0.05,
      isRotating: true,
      isDayNightCycleEnabled: false,
      // The package applies a simulated directional light to the sphere
      // shader independent of isDayNightCycleEnabled — defaults to a strong
      // hemisphere-darkening effect that reads as a night side. Disable it
      // so the whole globe renders evenly lit.
      surfaceLightingEnabled: false,
      surface: const AssetImage('assets/globe/earth_day.jpg'),
    );
    controller.onLoaded = () => _addPoints(controller);
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!widget.renderGlobe) {
      // Test/preview scaffold: no shader surface, places as tappable icons.
      return ColoredBox(
        color: colors.paper,
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final place in widget.places)
                Semantics(
                  button: widget.onPlaceTap != null,
                  label: place.name,
                  child: IconButton(
                    icon: Icon(Icons.public, color: colors.accent),
                    onPressed: widget.onPlaceTap == null
                        ? null
                        : () => widget.onPlaceTap!(place),
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
