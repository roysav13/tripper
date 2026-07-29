import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'trip_tables.dart';

part 'trips_dao.g.dart';

class TripWithDestinations {
  const TripWithDestinations(this.trip, this.destinations);

  final TripRow trip;

  /// Ordered by orderIndex.
  final List<TripDestinationRow> destinations;
}

@DriftAccessor(tables: [Trips, TripDestinations])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(super.db);

  Stream<List<TripWithDestinations>> watchAll() {
    final query =
        (select(trips)..orderBy([(t) => OrderingTerm.asc(t.startDate)])).join([
      leftOuterJoin(
        tripDestinations,
        tripDestinations.tripId.equalsExp(trips.id),
      ),
    ]);
    return query.watch().map(_group);
  }

  Future<TripWithDestinations?> getById(String id) async {
    final query = (select(trips)..where((t) => t.id.equals(id))).join([
      leftOuterJoin(
        tripDestinations,
        tripDestinations.tripId.equalsExp(trips.id),
      ),
    ]);
    final grouped = _group(await query.get());
    return grouped.isEmpty ? null : grouped.single;
  }

  Future<void> insertTrip(
    TripRow trip,
    List<TripDestinationRow> destinations,
  ) {
    return transaction(() async {
      await into(trips).insert(trip);
      for (final d in destinations) {
        await into(tripDestinations).insert(d);
      }
    });
  }

  Future<void> updateTrip(
    TripRow trip,
    List<TripDestinationRow> destinations,
  ) {
    return transaction(() async {
      await update(trips).replace(trip);
      await (delete(tripDestinations)..where((d) => d.tripId.equals(trip.id)))
          .go();
      for (final d in destinations) {
        await into(tripDestinations).insert(d);
      }
    });
  }

  Future<void> setCompletionPromptShown(String id) {
    return (update(trips)..where((t) => t.id.equals(id)))
        .write(const TripsCompanion(completionPromptShown: Value(true)));
  }

  Future<void> setArchived(String id, bool archived) {
    return (update(trips)..where((t) => t.id.equals(id)))
        .write(TripsCompanion(archived: Value(archived)));
  }

  Future<void> deleteTrip(String id) {
    // Destinations cascade via FK.
    return (delete(trips)..where((t) => t.id.equals(id))).go();
  }

  List<TripWithDestinations> _group(List<TypedResult> rows) {
    final order = <String>[];
    final tripById = <String, TripRow>{};
    final destsById = <String, List<TripDestinationRow>>{};
    for (final row in rows) {
      final trip = row.readTable(trips);
      if (!tripById.containsKey(trip.id)) {
        order.add(trip.id);
        tripById[trip.id] = trip;
        destsById[trip.id] = [];
      }
      final dest = row.readTableOrNull(tripDestinations);
      if (dest != null) destsById[trip.id]!.add(dest);
    }
    return [
      for (final id in order)
        TripWithDestinations(
          tripById[id]!,
          destsById[id]!..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
        ),
    ];
  }
}
