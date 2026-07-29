import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/trip_repository.dart';
import '../data/trips_dao.dart';
import '../domain/trip.dart';

final tripsDaoProvider =
    Provider<TripsDao>((ref) => ref.watch(databaseProvider).tripsDao);

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => DriftTripRepository(
    ref.watch(tripsDaoProvider),
    ref.watch(clockProvider),
  ),
);

final tripListProvider = StreamProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).watchTrips(),
);

/// Non-archived trips bucketed and ordered for the list screen.
final bucketedTripsProvider = Provider<Map<TripStatus, List<Trip>>>((ref) {
  final trips = ref.watch(tripListProvider).valueOrNull ?? const <Trip>[];
  final now = ref.watch(clockProvider)();
  final buckets = {
    TripStatus.active: <Trip>[],
    TripStatus.upcoming: <Trip>[],
    TripStatus.planned: <Trip>[],
    TripStatus.past: <Trip>[],
  };
  for (final trip in trips.where((t) => !t.archived)) {
    buckets[bucketTrip(trip, now)]!.add(trip);
  }
  int byStart(Trip a, Trip b) => a.startDate!.compareTo(b.startDate!);
  buckets[TripStatus.active]!.sort(byStart);
  // Upcoming: soonest first. Planned: alphabetical. Past: most recent first.
  buckets[TripStatus.upcoming]!.sort(byStart);
  buckets[TripStatus.planned]!
      .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  buckets[TripStatus.past]!.sort((a, b) => byStart(b, a));
  return buckets;
});

final archivedTripsProvider = Provider<List<Trip>>((ref) {
  final trips = ref.watch(tripListProvider).valueOrNull ?? const <Trip>[];
  return trips.where((t) => t.archived).toList();
});

/// One-shot guard so launch redirect happens once per app session.
final launchRedirectDoneProvider = StateProvider<bool>((ref) => false);

/// Guards against overlapping completion prompts while one is open.
final completionPromptActiveProvider = StateProvider<bool>((ref) => false);
