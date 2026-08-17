import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/database/database_provider.dart';
import '../../../core/filtering/filter_sort_controller.dart';
import '../../../core/filtering/sort_spec.dart';
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
