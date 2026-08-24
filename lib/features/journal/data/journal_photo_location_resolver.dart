import 'package:flutter/foundation.dart';

import '../../places/data/geocoding_service.dart';
import '../../places/data/place_summary_service.dart';

/// Names a journal photo's EXIF-tagged coordinates — same cascade as
/// [resolvePlaceCandidate] (design spec §5.6), run in reverse: there's no
/// candidate name here, just a pin, so Wikipedia geosearch's nearest
/// article is tried first and a reverse geocode (Google Places or
/// Nominatim, via [geocoder]) fills in whenever Wikipedia has nothing
/// nearby. Best-effort throughout — any failure degrades toward `null`,
/// never throws (CLAUDE.md hard rule 4), so this can never block the entry
/// form it prefills.
Future<String?> resolveJournalPhotoLocationName({
  required double lat,
  required double lng,
  required NearbyArticleFetcher wikipedia,
  required Geocoder geocoder,
}) async {
  try {
    final title = await wikipedia.nearestArticleTitle(lat, lng);
    if (title != null) return title;
  } catch (e) {
    debugPrint('[journal] photo location wikipedia lookup failed: $e');
  }
  try {
    final hit = await geocoder.reverse(lat, lng);
    return hit?.name;
  } catch (e) {
    debugPrint('[journal] photo location reverse geocode failed: $e');
    return null;
  }
}
