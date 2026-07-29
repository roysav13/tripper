import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/trip_providers.dart';
import '../data/place_repository.dart';
import '../data/places_dao.dart';
import '../domain/place.dart';

final placesDaoProvider =
    Provider<PlacesDao>((ref) => ref.watch(databaseProvider).placesDao);

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => DriftPlaceRepository(
    ref.watch(placesDaoProvider),
    ref.watch(clockProvider),
  ),
);

final placeListProvider = StreamProvider<List<Place>>(
  (ref) => ref.watch(placeRepositoryProvider).watchAll(),
);

final tripPlacesProvider = StreamProvider.family<List<Place>, String>(
  (ref, tripId) => ref.watch(placeRepositoryProvider).watchForTrip(tripId),
);

/// Trophy-case numbers. `days` (M5.6) is derived from trips rather than
/// places — it lives here because it shares the one stats header.
final placeStatsProvider =
    Provider<({int countries, int visited, int days})>((ref) {
  final places = ref.watch(placeListProvider).valueOrNull ?? const <Place>[];
  final trips = ref.watch(tripListProvider).valueOrNull ?? const <Trip>[];
  final stats = visitedStats(places);
  return (
    countries: stats.countries,
    visited: stats.visited,
    days: daysTraveled(trips, ref.watch(clockProvider)()),
  );
});

/// Set by "View on map" (place actions sheet) so `PlacesScreen` knows which
/// pin to fly the camera to and pop the info window for. Cleared once
/// `PlacesMapView` has consumed it.
final selectedPlaceIdProvider = StateProvider<String?>((ref) => null);

/// List <-> map toggle on the Places tab, session-scoped. "View on map"
/// flips this to true from anywhere a place row appears.
final placesMapModeProvider = StateProvider<bool>((ref) => false);
