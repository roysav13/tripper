import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/database/database_provider.dart';
import '../../../core/filtering/filter_sort_controller.dart';
import '../../../core/filtering/sort_spec.dart';
import '../../../core/settings/settings_service.dart'
    show nearbyApiCallCountProvider;
import '../data/google_places_geocoder.dart' show kGoogleMapsApiKey;
import '../data/nearby_places_cache.dart';
import '../data/nearby_places_service.dart';
import '../data/place_repository.dart';
import '../data/place_summary_service.dart';
import '../data/places_dao.dart';
import '../domain/place.dart';
import '../domain/place_sort.dart';

final placesDaoProvider =
    Provider<PlacesDao>((ref) => ref.watch(databaseProvider).placesDao);

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => DriftPlaceRepository(
    ref.watch(placesDaoProvider),
    ref.watch(clockProvider),
  ),
);

/// Wikipedia — free and keyless, unlike the Google Places summary fields
/// this replaced (which sat behind a paid SKU and silently returned
/// nothing for most non-flagship places).
final placeSummaryFetcherProvider = Provider<PlaceSummaryFetcher>(
  (ref) => WikipediaPlaceSummaryFetcher(http.Client()),
);

/// Separate instance from [placeSummaryFetcherProvider] (same underlying
/// class, different interface) — deliberately not derived from it via a
/// cast, so overriding one in a test never silently affects the other.
/// See design spec §5.6.
final placeLocationSummaryFetcherProvider =
    Provider<PlaceLocationSummaryFetcher>(
  (ref) => WikipediaPlaceSummaryFetcher(http.Client()),
);

final placeListProvider = StreamProvider<List<Place>>(
  (ref) => ref.watch(placeRepositoryProvider).watchAll(),
);

final tripPlacesProvider = StreamProvider.family<List<Place>, String>(
  (ref, tripId) => ref.watch(placeRepositoryProvider).watchForTrip(tripId),
);

/// Set by "View on map" (place actions sheet) so `PlacesScreen` knows which
/// pin to fly the camera to and pop the info window for. Cleared once
/// `PlacesMapView` has consumed it.
final selectedPlaceIdProvider = StateProvider<String?>((ref) => null);

/// List <-> map toggle on the Places tab, session-scoped. "View on map"
/// flips this to true from anywhere a place row appears.
final placesMapModeProvider = StateProvider<bool>((ref) => false);

/// List <-> map toggle on a trip's own Places tab — one per trip, and
/// independent of [placesMapModeProvider] (the aggregate Places tab's
/// toggle), same "independent surfaces keep independent selections"
/// reasoning as [placeFilterSortProvider]'s scope. Toggling map mode while
/// looking at one trip must not silently flip the aggregate tab too.
final tripPlacesMapModeProvider =
    StateProvider.family<bool, String>((ref, tripId) => false);

/// One filter+sort state per scope (`'places'` for the app-wide tab,
/// `'trip:<id>'` for a trip's tab) — independent surfaces keep independent
/// selections without either screen writing its own notifier.
final placeFilterSortProvider = NotifierProvider.family<
    FilterSortController<PlaceSortField>,
    FilterSortState<PlaceSortField>,
    String>(
  () => FilterSortController<PlaceSortField>(
    const SortSpec(PlaceSortField.recommended, SortDirection.ascending),
  ),
);

/// Constructing this never touches the network by itself — the real HTTP
/// call only happens inside `searchNearby`, gated at the call site by
/// `nearbyPlacesEnabledProvider` (settings + entry-point UI).
final nearbyPlacesFetcherProvider = Provider<NearbyPlacesFetcher>(
  (ref) => GoogleNearbyPlacesFetcher(http.Client(), apiKey: kGoogleMapsApiKey),
);

/// Session-scoped (not autoDispose) — deliberately survives navigating
/// away from the results screen and back, for the same reason it isn't
/// persisted to disk: the cache's job is "don't double-charge a browsing
/// session," and the session is the whole app run.
final nearbyPlacesCacheProvider =
    Provider<NearbyPlacesCache>((ref) => NearbyPlacesCache());

final nearbyPlacesServiceProvider = Provider<NearbyPlacesService>(
  (ref) => NearbyPlacesService(
    ref.watch(nearbyPlacesFetcherProvider),
    ref.watch(nearbyPlacesCacheProvider),
    ref.watch(clockProvider),
    () => ref.read(nearbyApiCallCountProvider.notifier).increment(),
  ),
);
