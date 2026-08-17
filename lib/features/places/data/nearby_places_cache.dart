import '../domain/nearby_place.dart';

/// Session-scoped, in-memory TTL cache — deliberately not persisted
/// (SharedPreferences/Drift would add real complexity for a guard whose
/// job is "don't double-charge a browsing session"; a killed-and-reopened
/// app is a fresh session and a fresh budget). Keyed by lat/lng rounded to
/// 3 decimal places (~110m) — fine-grained enough that "near me" and "near
/// this hotel" don't collide, coarse enough that GPS jitter within the
/// same spot still hits.
class NearbyPlacesCache {
  final _entries =
      <String, ({DateTime fetchedAt, List<NearbyPlaceResult> results})>{};

  static const ttl = Duration(hours: 1);

  String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

  List<NearbyPlaceResult>? lookup(double lat, double lng, DateTime now) {
    final entry = _entries[_key(lat, lng)];
    if (entry == null) return null;
    if (now.difference(entry.fetchedAt) > ttl) return null;
    return entry.results;
  }

  void store(
    double lat,
    double lng,
    List<NearbyPlaceResult> results,
    DateTime now,
  ) {
    _entries[_key(lat, lng)] = (fetchedAt: now, results: results);
  }
}
