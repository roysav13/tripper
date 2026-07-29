import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'place_tables.dart';

part 'places_dao.g.dart';

@DriftAccessor(tables: [Places])
class PlacesDao extends DatabaseAccessor<AppDatabase> with _$PlacesDaoMixin {
  PlacesDao(super.db);

  Stream<List<PlaceRow>> watchAll() =>
      (select(places)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();

  Stream<List<PlaceRow>> watchForTrip(String tripId) =>
      (select(places)..where((p) => p.tripId.equals(tripId))).watch();

  Future<PlaceRow?> getById(String id) =>
      (select(places)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<void> insertPlace(PlaceRow row) => into(places).insert(row);

  Future<void> updatePlace(PlaceRow row) => update(places).replace(row);

  Future<void> deletePlace(String id) =>
      (delete(places)..where((p) => p.id.equals(id))).go();

  Future<void> setStatus(String id, int status, DateTime? visitedAt) {
    return (update(places)..where((p) => p.id.equals(id))).write(
      PlacesCompanion(
        status: Value(status),
        visitedAt: Value(visitedAt),
      ),
    );
  }

  Future<void> bulkSetStatus(
    List<String> ids,
    int status,
    DateTime? visitedAt,
  ) {
    return (update(places)..where((p) => p.id.isIn(ids))).write(
      PlacesCompanion(
        status: Value(status),
        visitedAt: Value(visitedAt),
      ),
    );
  }
}
