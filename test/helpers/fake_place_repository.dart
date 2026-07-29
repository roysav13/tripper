import 'dart:async';

import 'package:tripper/features/places/data/place_repository.dart';
import 'package:tripper/features/places/domain/place.dart';

/// Fake at the repository boundary (testing rules — no DB in widget tests).
class FakePlaceRepository implements PlaceRepository {
  FakePlaceRepository(this._places, {DateTime? clock})
      : _clock = clock ?? DateTime(2026, 7, 19);

  final List<Place> _places;
  final DateTime _clock;
  final _controller = StreamController<List<Place>>.broadcast();

  void emit(List<Place> places) {
    _places
      ..clear()
      ..addAll(places);
    _controller.add(List.of(places));
  }

  /// M4.2 states audit — simulates a stream failure for error-state tests.
  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<Place>> watchAll() async* {
    yield List.of(_places);
    yield* _controller.stream;
  }

  @override
  Stream<List<Place>> watchForTrip(String tripId) async* {
    yield [
      for (final p in _places)
        if (p.tripId == tripId) p,
    ];
    yield* _controller.stream.map(
      (all) => [
        for (final p in all)
          if (p.tripId == tripId) p,
      ],
    );
  }

  @override
  Future<String> createPlace({
    required String name,
    String country = '',
    String city = '',
    double? lat,
    double? lng,
    String? tripId,
    String notes = '',
  }) async {
    final place = Place(
      id: 'fake-${_places.length}',
      name: name,
      country: country,
      city: city,
      lat: lat,
      lng: lng,
      tripId: tripId,
      notes: notes,
    );
    emit([..._places, place]);
    return place.id;
  }

  @override
  Future<void> updatePlace(Place place) async {
    emit([
      for (final p in _places)
        if (p.id == place.id) place else p,
    ]);
  }

  @override
  Future<void> setVisited(
    String id, {
    required bool visited,
    DateTime? visitedOn,
  }) async {
    emit([
      for (final p in _places)
        if (p.id == id)
          p.copyWith(
            status: visited ? PlaceStatus.beenThere : PlaceStatus.wantToGo,
            visitedAt: () => visited ? (visitedOn ?? _clock) : null,
          )
        else
          p,
    ]);
  }

  @override
  Future<void> bulkMarkVisited(List<String> ids, DateTime visitedOn) async {
    emit([
      for (final p in _places)
        if (ids.contains(p.id))
          p.copyWith(
            status: PlaceStatus.beenThere,
            visitedAt: () => visitedOn,
          )
        else
          p,
    ]);
  }

  @override
  Future<void> deletePlace(String id) async {
    emit([..._places.where((p) => p.id != id)]);
  }
}
