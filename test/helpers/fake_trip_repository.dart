import 'dart:async';

import 'package:tripper/features/trips/data/trip_repository.dart';
import 'package:tripper/features/trips/domain/trip.dart';

/// Fake at the repository boundary (testing rules — no DB in widget tests).
class FakeTripRepository implements TripRepository {
  FakeTripRepository(this._trips);

  final List<Trip> _trips;
  final _controller = StreamController<List<Trip>>.broadcast();

  void emit(List<Trip> trips) {
    _trips
      ..clear()
      ..addAll(trips);
    _controller.add(List.of(trips));
  }

  /// M4.2 states audit — lets a test simulate a stream failure without a
  /// real DB error. A fresh subscription (e.g. after `ref.invalidate`)
  /// doesn't replay this — it just re-reads current state, which is what
  /// makes a "retry" button meaningful to test.
  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<Trip>> watchTrips() async* {
    yield List.of(_trips);
    yield* _controller.stream;
  }

  @override
  Future<Trip?> getTrip(String id) async =>
      _trips.where((t) => t.id == id).firstOrNull;

  @override
  Future<String> createTrip({
    required String name,
    required List<String> destinations,
    DateTime? startDate,
    DateTime? endDate,
    required int colorTag,
  }) async {
    final trip = Trip(
      id: 'fake-${_trips.length}',
      name: name,
      destinations: destinations,
      startDate: startDate,
      endDate: endDate,
      colorTag: colorTag,
    );
    emit([..._trips, trip]);
    return trip.id;
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    emit([
      for (final t in _trips)
        if (t.id == trip.id) trip else t,
    ]);
  }

  @override
  Future<void> setArchived(String id, {required bool archived}) async {
    emit([
      for (final t in _trips)
        if (t.id == id) t.copyWith(archived: archived) else t,
    ]);
  }

  @override
  Future<void> markCompletionPromptShown(String id) async {
    emit([
      for (final t in _trips)
        if (t.id == id) t.copyWith(completionPromptShown: true) else t,
    ]);
  }

  @override
  Future<void> deleteTrip(String id) async {
    emit([..._trips.where((t) => t.id != id)]);
  }
}
