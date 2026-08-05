import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../journal/presentation/journal_providers.dart';
import '../domain/place.dart';
import 'place_providers.dart';

/// Marks [place] visited/un-visited, and — only when marking visited —
/// ensures it has a linked journal entry (Place<->JournalEntry
/// correlation: an entry IS a visited place). Un-visiting never touches
/// an existing linked entry (entries are user content, never
/// auto-deleted). Idempotent: toggling visited on/off/on never creates a
/// second stub entry, via [JournalRepository.hasEntryForPlace].
///
/// A place with no [Place.tripId] can't get a trip-scoped entry — the
/// visited flag still updates, stub creation is silently skipped.
Future<void> markPlaceVisited(
  WidgetRef ref,
  Place place, {
  required bool visited,
}) async {
  final placeRepo = ref.read(placeRepositoryProvider);
  final clock = ref.read(clockProvider);
  final journalRepo = ref.read(journalRepositoryProvider);
  final visitedOn = visited ? clock() : null;
  await placeRepo.setVisited(place.id, visited: visited, visitedOn: visitedOn);
  if (!visited || place.tripId == null) return;

  if (await journalRepo.hasEntryForPlace(place.id)) return;
  await journalRepo.createEntry(
    tripId: place.tripId!,
    summary: '',
    loggedAt: visitedOn,
    lat: place.lat,
    lng: place.lng,
    placeName: place.name,
    placeId: place.id,
  );
}

/// Bulk form of [markPlaceVisited] — used by the trip-completion prompt,
/// which marks several wishlist places visited at once. Same
/// idempotency and no-tripId-skip rules apply per place.
Future<void> markPlacesVisited(
  WidgetRef ref,
  List<Place> places,
  DateTime visitedOn,
) async {
  final placeRepo = ref.read(placeRepositoryProvider);
  final journalRepo = ref.read(journalRepositoryProvider);
  await placeRepo.bulkMarkVisited([for (final p in places) p.id], visitedOn);

  for (final place in places) {
    if (place.tripId == null) continue;
    if (await journalRepo.hasEntryForPlace(place.id)) continue;
    await journalRepo.createEntry(
      tripId: place.tripId!,
      summary: '',
      loggedAt: visitedOn,
      lat: place.lat,
      lng: place.lng,
      placeName: place.name,
      placeId: place.id,
    );
  }
}
