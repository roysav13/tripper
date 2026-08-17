import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/place.dart';
import 'places_dao.dart';

/// Widget tests mock at this boundary.
abstract interface class PlaceRepository {
  Stream<List<Place>> watchAll();
  Stream<List<Place>> watchForTrip(String tripId);
  Future<String> createPlace({
    required String name,
    String country,
    String city,
    double? lat,
    double? lng,
    String? tripId,
    String notes,
    PlaceCategory? category,
  });
  Future<void> updatePlace(Place place);

  /// visited = true stamps [visitedOn]; false clears the date (un-visit).
  Future<void> setVisited(
    String id, {
    required bool visited,
    DateTime? visitedOn,
  });
  Future<void> bulkMarkVisited(List<String> ids, DateTime visitedOn);
  Future<void> deletePlace(String id);

  /// Records the outcome of a summary fetch — [summary] null means the
  /// attempt found nothing (offline, no key, or Google has none for this
  /// place), still a completed attempt, not "never tried".
  Future<void> setSummary(String id, {String? summary});
}

class DriftPlaceRepository implements PlaceRepository {
  DriftPlaceRepository(this._dao, this._clock);

  final PlacesDao _dao;
  final DateTime Function() _clock;
  final _uuid = const Uuid();

  @override
  Stream<List<Place>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_toDomain).toList());

  @override
  Stream<List<Place>> watchForTrip(String tripId) =>
      _dao.watchForTrip(tripId).map((rows) => rows.map(_toDomain).toList());

  @override
  Future<String> createPlace({
    required String name,
    String country = '',
    String city = '',
    double? lat,
    double? lng,
    String? tripId,
    String notes = '',
    PlaceCategory? category,
  }) async {
    final id = _uuid.v4();
    await _dao.insertPlace(
      PlaceRow(
        id: id,
        name: name.trim(),
        lat: lat,
        lng: lng,
        country: country.trim(),
        city: city.trim(),
        status: PlaceStatus.wantToGo.index,
        visitedAt: null,
        tripId: tripId,
        notes: notes.trim(),
        createdAt: _clock(),
        category: category?.index,
      ),
    );
    return id;
  }

  @override
  Future<void> updatePlace(Place place) async {
    final existing = await _dao.getById(place.id);
    if (existing == null) return;
    await _dao.updatePlace(
      existing.copyWith(
        name: place.name.trim(),
        lat: Value(place.lat),
        lng: Value(place.lng),
        country: place.country.trim(),
        city: place.city.trim(),
        status: place.status.index,
        visitedAt: Value(place.visitedAt),
        tripId: Value(place.tripId),
        notes: place.notes.trim(),
        category: Value(place.category?.index),
        summary: Value(place.summary),
        summaryFetchedAt: Value(place.summaryFetchedAt),
      ),
    );
  }

  @override
  Future<void> setVisited(
    String id, {
    required bool visited,
    DateTime? visitedOn,
  }) {
    return _dao.setStatus(
      id,
      (visited ? PlaceStatus.beenThere : PlaceStatus.wantToGo).index,
      visited ? (visitedOn ?? _clock()) : null,
    );
  }

  @override
  Future<void> bulkMarkVisited(List<String> ids, DateTime visitedOn) =>
      _dao.bulkSetStatus(ids, PlaceStatus.beenThere.index, visitedOn);

  @override
  Future<void> deletePlace(String id) => _dao.deletePlace(id);

  @override
  Future<void> setSummary(String id, {String? summary}) =>
      _dao.setSummary(id, summary, _clock());

  Place _toDomain(PlaceRow row) => Place(
        id: row.id,
        name: row.name,
        lat: row.lat,
        lng: row.lng,
        country: row.country,
        city: row.city,
        status: PlaceStatus.values[row.status],
        visitedAt: row.visitedAt,
        tripId: row.tripId,
        notes: row.notes,
        category:
            row.category == null ? null : PlaceCategory.values[row.category!],
        summary: row.summary,
        summaryFetchedAt: row.summaryFetchedAt,
      );
}
