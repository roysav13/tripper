import 'package:flutter/foundation.dart';

import 'place.dart';
import 'place_sort.dart';

/// One result from a Google Places `searchNearby` call — a transient
/// discovery signal, never persisted as-is (CLAUDE.md hard rule: local
/// data is the source of truth). Adding a result creates a normal [Place]
/// via [PlaceRepository]; rating/userRatingCount/primaryType are not
/// carried onto it.
@immutable
class NearbyPlaceResult {
  const NearbyPlaceResult({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.userRatingCount,
    this.primaryType,
  });

  final String placeId;
  final String name;
  final double lat;
  final double lng;
  final double rating;
  final int userRatingCount;

  /// Raw Google type (e.g. "restaurant"). Kept separate from the mapped
  /// [PlaceCategory] so [nearbyCategoryFor] stays a pure, independently
  /// testable function.
  final String? primaryType;
}

/// A handful of common Google types mapped to the existing wishlist
/// category set; anything unmapped is null (uncategorized) — never a
/// guess, mirroring how [Place.category] treats pre-category rows.
const _typeToCategory = <String, PlaceCategory>{
  'restaurant': PlaceCategory.restaurant,
  'cafe': PlaceCategory.coffeeShop,
  'bar': PlaceCategory.bar,
  'museum': PlaceCategory.museum,
  'tourist_attraction': PlaceCategory.attraction,
  'lodging': PlaceCategory.hotel,
  'amusement_park': PlaceCategory.amusementPark,
  'beach': PlaceCategory.beach,
  'shopping_mall': PlaceCategory.shopping,
  'park': PlaceCategory.nature,
};

PlaceCategory? nearbyCategoryFor(String? primaryType) =>
    primaryType == null ? null : _typeToCategory[primaryType];

const _minRating = 4.0;
const _minRatingCount = 5;

/// "High rated" filter + sort, applied client-side after parsing — a fixed
/// threshold and order, not configurable in v1. Sorts by rating
/// descending, then distance from [lat]/[lng] ascending as a tiebreak.
List<NearbyPlaceResult> filterAndSortNearbyResults(
  List<NearbyPlaceResult> results, {
  required double lat,
  required double lng,
}) {
  final filtered = results
      .where((r) => r.rating >= _minRating && r.userRatingCount >= _minRatingCount)
      .toList();
  filtered.sort((a, b) {
    final byRating = b.rating.compareTo(a.rating);
    if (byRating != 0) return byRating;
    final da =
        distanceBetweenKm(lat1: lat, lng1: lng, lat2: a.lat, lng2: a.lng);
    final db =
        distanceBetweenKm(lat1: lat, lng1: lng, lat2: b.lat, lng2: b.lng);
    return da.compareTo(db);
  });
  return filtered;
}
