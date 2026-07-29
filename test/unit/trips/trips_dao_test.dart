import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';
import 'package:tripper/features/trips/data/trip_repository.dart';

// Runs against an in-memory SQLite DB. On Windows this needs sqlite3.dll on
// PATH (or run in CI, where libsqlite3 is present). No mocks — real queries.
void main() {
  late AppDatabase db;
  late DriftTripRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftTripRepository(db.tripsDao, () => DateTime(2026, 7, 19));
  });

  tearDown(() async => db.close());

  Future<String> create({
    String name = 'Thailand',
    List<String> destinations = const ['Krabi', 'Ko Pha-ngan', 'Bangkok'],
  }) {
    return repo.createTrip(
      name: name,
      destinations: destinations,
      startDate: DateTime(2026, 7, 16),
      endDate: DateTime(2026, 7, 27),
      colorTag: 2,
    );
  }

  test('create and read roundtrip, destinations keep order', () async {
    final id = await create();
    final trip = await repo.getTrip(id);
    expect(trip, isNotNull);
    expect(trip!.name, 'Thailand');
    expect(trip.destinations, ['Krabi', 'Ko Pha-ngan', 'Bangkok']);
    expect(trip.colorTag, 2);
    expect(trip.archived, isFalse);
  });

  test('update replaces destinations and reorders', () async {
    final id = await create();
    final trip = (await repo.getTrip(id))!;
    await repo.updateTrip(
      trip.copyWith(
        name: 'Thailand islands',
        destinations: ['Bangkok', 'Krabi'],
      ),
    );
    final updated = (await repo.getTrip(id))!;
    expect(updated.name, 'Thailand islands');
    expect(updated.destinations, ['Bangkok', 'Krabi']);
  });

  test('blank destinations are dropped on save', () async {
    final id = await create(destinations: ['Krabi', '  ', 'Bangkok']);
    final trip = (await repo.getTrip(id))!;
    expect(trip.destinations, ['Krabi', 'Bangkok']);
  });

  test('archive and unarchive', () async {
    final id = await create();
    await repo.setArchived(id, archived: true);
    expect((await repo.getTrip(id))!.archived, isTrue);
    await repo.setArchived(id, archived: false);
    expect((await repo.getTrip(id))!.archived, isFalse);
  });

  test('delete removes trip and cascades destinations', () async {
    final id = await create();
    await repo.deleteTrip(id);
    expect(await repo.getTrip(id), isNull);
    final orphanCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM trip_destinations')
        .getSingle();
    expect(orphanCount.data['c'], 0);
  });

  test('watchTrips emits ordered by start date', () async {
    await create(name: 'Later');
    await repo.createTrip(
      name: 'Sooner',
      destinations: ['Rome'],
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 5),
      colorTag: 0,
    );
    final trips = await repo.watchTrips().first;
    expect(trips.map((t) => t.name).toList(), ['Sooner', 'Later']);
  });

  test('trip with no dates roundtrips (planned)', () async {
    final id = await repo.createTrip(
      name: 'Japan someday',
      destinations: ['Tokyo'],
      colorTag: 0,
    );
    final trip = (await repo.getTrip(id))!;
    expect(trip.startDate, isNull);
    expect(trip.endDate, isNull);
  });

  test('clearing dates on update persists nulls', () async {
    final id = await create();
    final trip = (await repo.getTrip(id))!;
    await repo.updateTrip(
      trip.copyWith(startDate: () => null, endDate: () => null),
    );
    final updated = (await repo.getTrip(id))!;
    expect(updated.startDate, isNull);
    expect(updated.endDate, isNull);
  });

  test('completion prompt flag persists', () async {
    final id = await create();
    expect((await repo.getTrip(id))!.completionPromptShown, isFalse);
    await repo.markCompletionPromptShown(id);
    expect((await repo.getTrip(id))!.completionPromptShown, isTrue);
  });

  test('fresh database opens at schema v9 with every table queryable',
      () async {
    expect(db.schemaVersion, 9);
    for (final table in [
      'trips',
      'trip_destinations',
      'documents',
      'trip_documents',
      'places',
      'expenses', // v7 (M5.5)
      // v9 (M5.7). The Plan feature was withdrawn, but the table stays
      // so upgraded devices never face a destructive migration.
      'itinerary_items',
    ]) {
      await db.customSelect('SELECT COUNT(*) FROM $table').getSingle();
    }
  });
}
