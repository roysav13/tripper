import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_service.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

/// One-shot current-location fetch, shared across every widget that
/// watches it — Places fetches this proactively as soon as its screen
/// opens (rather than waiting for "Distance" to be tapped in the sort
/// sheet) so the sort feels instant once picked. `autoDispose` so leaving
/// Places and coming back re-fetches — a stale fix (or a stale denial,
/// if the user has since granted the permission in Settings) shouldn't
/// stick around for the rest of the app session.
final currentLocationProvider = FutureProvider.autoDispose<LocationFix>(
  (ref) => ref.watch(locationServiceProvider).getCurrentLocation(),
);
