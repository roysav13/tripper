import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/trip.dart';
import 'trips_dao.dart';

/// Widget tests mock at this boundary (testing rules).
abstract interface class TripRepository {
  Stream<List<Trip>> watchTrips();
  Future<Trip?> getTrip(String id);
  Future<String> createTrip({
    required String name,
    required List<String> destinations,
    DateTime? startDate,
    DateTime? endDate,
    required int colorTag,
  });
  Future<void> updateTrip(Trip trip);
  Future<void> setArchived(String id, {required bool archived});
  Future<void> markCompletionPromptShown(String id);
  Future<void> deleteTrip(String id);
}

class DriftTripRepository implements TripRepository {
  DriftTripRepository(this._dao, this._clock);

  final TripsDao _dao;
  final DateTime Function() _clock;
  final _uuid = const Uuid();

  @override
  Stream<List<Trip>> watchTrips() =>
      _dao.watchAll().map((rows) => rows.map(_toDomain).toList());

  @override
  Future<Trip?> getTrip(String id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<String> createTrip({
    required String name,
    required List<String> destinations,
    DateTime? startDate,
    DateTime? endDate,
    required int colorTag,
  }) async {
    final id = _uuid.v4();
    await _dao.insertTrip(
      TripRow(
        id: id,
        name: name.trim(),
        startDate: startDate,
        endDate: endDate,
        colorTag: colorTag,
        archived: false,
        completionPromptShown: false,
        createdAt: _clock(),
      ),
      _destinationRows(id, destinations),
    );
    return id;
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    final existing = await _dao.getById(trip.id);
    if (existing == null) return;
    await _dao.updateTrip(
      existing.trip.copyWith(
        name: trip.name.trim(),
        startDate: Value(trip.startDate),
        endDate: Value(trip.endDate),
        colorTag: trip.colorTag,
        archived: trip.archived,
      ),
      _destinationRows(trip.id, trip.destinations),
    );
  }

  @override
  Future<void> setArchived(String id, {required bool archived}) =>
      _dao.setArchived(id, archived);

  @override
  Future<void> markCompletionPromptShown(String id) =>
      _dao.setCompletionPromptShown(id);

  @override
  Future<void> deleteTrip(String id) => _dao.deleteTrip(id);

  List<TripDestinationRow> _destinationRows(
    String tripId,
    List<String> destinations,
  ) {
    final cleaned =
        destinations.map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    return [
      for (var i = 0; i < cleaned.length; i++)
        TripDestinationRow(
          id: _uuid.v4(),
          tripId: tripId,
          name: cleaned[i],
          orderIndex: i,
        ),
    ];
  }

  Trip _toDomain(TripWithDestinations row) => Trip(
        id: row.trip.id,
        name: row.trip.name,
        destinations: [for (final d in row.destinations) d.name],
        startDate: row.trip.startDate,
        endDate: row.trip.endDate,
        colorTag: row.trip.colorTag,
        archived: row.trip.archived,
        completionPromptShown: row.trip.completionPromptShown,
      );
}
