import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';
import 'package:tripper/features/places/data/place_repository.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/trips/data/trip_repository.dart';

void main() {
  late AppDatabase db;
  late DriftPlaceRepository repo;
  late DriftTripRepository tripRepo;
  final today = DateTime(2026, 7, 19);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPlaceRepository(db.placesDao, () => today);
    tripRepo = DriftTripRepository(db.tripsDao, () => today);
  });

  tearDown(() async => db.close());

  test('create defaults to want-to-go without location', () async {
    final id = await repo.createPlace(name: 'Railay viewpoint');
    final place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.isVisited, isFalse);
    expect(place.hasLocation, isFalse);
    expect(place.visitedAt, isNull);
  });

  test('mark visited stamps the clock date; un-visit clears it', () async {
    final id = await repo.createPlace(name: 'Phi Phi lagoon');
    await repo.setVisited(id, visited: true);
    var place = (await repo.watchAll().first).single;
    expect(place.isVisited, isTrue);
    expect(place.visitedAt, today);

    await repo.setVisited(id, visited: false);
    place = (await repo.watchAll().first).single;
    expect(place.isVisited, isFalse);
    expect(place.visitedAt, isNull);
  });

  test('bulk mark visited stamps a shared date', () async {
    final a = await repo.createPlace(name: 'A');
    final b = await repo.createPlace(name: 'B');
    await repo.createPlace(name: 'C');
    final end = DateTime(2026, 7, 27);

    await repo.bulkMarkVisited([a, b], end);
    final places = await repo.watchAll().first;
    expect(places.where((p) => p.isVisited).length, 2);
    expect(
      places.where((p) => p.isVisited).every((p) => p.visitedAt == end),
      isTrue,
    );
  });

  test('deleting a trip keeps its places with tripId nulled', () async {
    final tripId = await tripRepo.createTrip(
      name: 'Thailand',
      destinations: ['Krabi'],
      startDate: DateTime(2026, 7, 16),
      endDate: DateTime(2026, 7, 27),
      colorTag: 0,
    );
    final placeId = await repo.createPlace(name: 'Railay', tripId: tripId);
    expect((await repo.watchForTrip(tripId).first).length, 1);

    await tripRepo.deleteTrip(tripId);
    final place =
        (await repo.watchAll().first).singleWhere((p) => p.id == placeId);
    expect(place.tripId, isNull);
  });

  test(
      'category survives the enum<->int index round trip through create, '
      'update, and clear', () async {
    // Cross-task issue (final review): category?.index / values[index] is
    // the only place the enum<->int conversion happens, and nothing
    // exercised it — widget tests all mock at FakePlaceRepository, which
    // stores the enum directly. Deleting the category write in updatePlace
    // would silently wipe category on every edit and leave the suite green.
    final id = await repo.createPlace(
      name: 'Railay viewpoint',
      category: PlaceCategory.hotel,
    );
    var place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.category, PlaceCategory.hotel);

    await repo.updatePlace(
      place.copyWith(category: () => PlaceCategory.restaurant),
    );
    place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.category, PlaceCategory.restaurant);

    await repo.updatePlace(place.copyWith(category: () => null));
    place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.category, isNull);
  });

  test('setSummary stamps the clock and survives an unrelated update',
      () async {
    final id = await repo.createPlace(name: 'Railay viewpoint');
    var place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.summary, isNull);
    expect(place.summaryFetchedAt, isNull);

    await repo.setSummary(id, summary: 'A quiet limestone cove.');
    place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.summary, 'A quiet limestone cove.');
    expect(place.summaryFetchedAt, today);

    // Editing an unrelated field (e.g. notes) must not wipe the summary
    // that a background fetch already stored.
    await repo.updatePlace(place.copyWith(notes: 'Bring water shoes'));
    place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.summary, 'A quiet limestone cove.');
    expect(place.summaryFetchedAt, today);
  });

  test(
      'setSummary with a null result still stamps fetchedAt — attempted, '
      'not "never tried"', () async {
    final id = await repo.createPlace(name: 'Corner store');
    await repo.setSummary(id, summary: null);
    final place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.summary, isNull);
    expect(place.summaryFetchedAt, today);
  });

  test('watchForTrip only emits that trip\'s places', () async {
    final tripId = await tripRepo.createTrip(
      name: 'Rome',
      destinations: ['Rome'],
      startDate: DateTime(2026, 10, 3),
      endDate: DateTime(2026, 10, 7),
      colorTag: 0,
    );
    await repo.createPlace(name: 'Colosseum', tripId: tripId);
    await repo.createPlace(name: 'Unlinked');
    final places = await repo.watchForTrip(tripId).first;
    expect(places.map((p) => p.name).toList(), ['Colosseum']);
  });
}
