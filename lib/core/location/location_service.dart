import 'package:geolocator/geolocator.dart';

/// Result of a single, one-shot GPS read — not live tracking. Live route
/// tracking (SPEC §3.2.2) is its own later, deliberately isolated
/// milestone (battery budget, motion-aware sampling, its own permission
/// story); this is just enough to sort an already-loaded local list by
/// distance, so it degrades to "distance sort isn't available yet" rather
/// than blocking anything (CLAUDE.md hard rule 4).
sealed class LocationFix {
  const LocationFix();
}

class LocationAvailable extends LocationFix {
  const LocationAvailable(this.lat, this.lng);

  final double lat;
  final double lng;
}

enum LocationUnavailableReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class LocationUnavailable extends LocationFix {
  const LocationUnavailable(this.reason);

  final LocationUnavailableReason reason;
}

abstract class LocationService {
  Future<LocationFix> getCurrentLocation();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationFix> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable(
          LocationUnavailableReason.serviceDisabled,
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationUnavailable(
          LocationUnavailableReason.permissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationUnavailable(
          LocationUnavailableReason.permissionDeniedForever,
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 15));
      return LocationAvailable(position.latitude, position.longitude);
    } catch (_) {
      return const LocationUnavailable(LocationUnavailableReason.error);
    }
  }
}
