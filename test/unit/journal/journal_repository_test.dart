import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';
import 'package:tripper/core/files/file_vault_service.dart';
import 'package:tripper/features/journal/data/journal_repository.dart';
import 'package:tripper/features/trips/data/trip_repository.dart';

// Runs against an in-memory SQLite DB. No mocks — real queries.
void main() {
  late AppDatabase db;
  late Directory tempDir;
  late DriftJournalRepository repo;
  late DriftTripRepository tripRepo;
  var idCounter = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('journal_dao_test');
    idCounter = 0;
    repo = DriftJournalRepository(
      db.journalDao,
      FileVaultService(() async => tempDir),
      () => DateTime(2026, 7, 19),
      () => 'entry-${idCounter++}',
    );
    tripRepo = DriftTripRepository(db.tripsDao, () => DateTime(2026, 7, 19));
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<String> createTrip() => tripRepo.createTrip(
        name: 'Thailand',
        destinations: ['Krabi'],
        startDate: DateTime(2026, 7, 16),
        endDate: DateTime(2026, 7, 27),
        colorTag: 0,
      );

  Future<String> writePhoto(String name) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes([1, 2, 3]);
    return file.path;
  }

  test('create and read roundtrip, loggedAt defaults to clock()', () async {
    final tripId = await createTrip();
    final id = await repo.createEntry(tripId: tripId, summary: 'Arrived!');
    final entry = await repo.getById(id);
    expect(entry, isNotNull);
    expect(entry!.summary, 'Arrived!');
    expect(entry.loggedAt, DateTime(2026, 7, 19));
    expect(entry.createdAt, DateTime(2026, 7, 19));
    expect(entry.hasLocation, isFalse);
    expect(entry.photos, isEmpty);
  });

  test('explicit loggedAt is kept, not overridden by clock()', () async {
    final tripId = await createTrip();
    final id = await repo.createEntry(
      tripId: tripId,
      summary: 'Backdated entry',
      loggedAt: DateTime(2026, 7, 17, 9),
    );
    final entry = await repo.getById(id);
    expect(entry!.loggedAt, DateTime(2026, 7, 17, 9));
  });

  test('location and place name roundtrip', () async {
    final tripId = await createTrip();
    final id = await repo.createEntry(
      tripId: tripId,
      summary: 'On the boat',
      lat: 8.0863,
      lng: 98.9063,
      placeName: 'Krabi',
    );
    final entry = await repo.getById(id);
    expect(entry!.hasLocation, isTrue);
    expect(entry.lat, 8.0863);
    expect(entry.lng, 98.9063);
    expect(entry.placeName, 'Krabi');
  });

  test('photos are imported into the vault, preserving order', () async {
    final tripId = await createTrip();
    final photoA = await writePhoto('a.jpg');
    final photoB = await writePhoto('b.jpg');
    final id = await repo.createEntry(
      tripId: tripId,
      summary: 'Photo dump',
      photoSourcePaths: [photoA, photoB],
    );
    final entry = await repo.getById(id);
    expect(entry!.photos.length, 2);
    expect(await File(entry.photos[0].filePath).exists(), isTrue);
    expect(await File(entry.photos[1].filePath).exists(), isTrue);
    expect(entry.photos[0].filePath, isNot(photoA)); // copied, not referenced
  });

  test('updateEntry keeps existing photos not removed, appends new ones',
      () async {
    final tripId = await createTrip();
    final photoA = await writePhoto('a.jpg');
    final id = await repo.createEntry(
      tripId: tripId,
      summary: 'Day 1',
      photoSourcePaths: [photoA],
    );
    var entry = (await repo.getById(id))!;
    final keptPath = entry.photos.single.filePath;

    final photoB = await writePhoto('b.jpg');
    await repo.updateEntry(
      entry.copyWith(summary: 'Day 1, edited'),
      newPhotoSourcePaths: [photoB],
    );

    entry = (await repo.getById(id))!;
    expect(entry.summary, 'Day 1, edited');
    expect(entry.photos.length, 2);
    expect(entry.photos[0].filePath, keptPath);
    expect(await File(keptPath).exists(), isTrue);
  });

  test('updateEntry deletes vault files for removed photos', () async {
    final tripId = await createTrip();
    final photoA = await writePhoto('a.jpg');
    final photoB = await writePhoto('b.jpg');
    final id = await repo.createEntry(
      tripId: tripId,
      summary: 'Two photos',
      photoSourcePaths: [photoA, photoB],
    );
    var entry = (await repo.getById(id))!;
    final removedPath = entry.photos[0].filePath;
    final keptPath = entry.photos[1].filePath;

    await repo.updateEntry(
      entry,
      removedPhotoIds: [entry.photos[0].id],
    );

    entry = (await repo.getById(id))!;
    expect(entry.photos.length, 1);
    expect(entry.photos.single.filePath, keptPath);
    expect(await File(removedPath).exists(), isFalse);
    expect(await File(keptPath).exists(), isTrue);
  });

  test('deleteEntry removes the row and its vault files', () async {
    final tripId = await createTrip();
    final photoA = await writePhoto('a.jpg');
    final id = await repo.createEntry(
      tripId: tripId,
      summary: 'Gone soon',
      photoSourcePaths: [photoA],
    );
    final vaultPath = (await repo.getById(id))!.photos.single.filePath;

    await repo.deleteEntry(id);

    expect(await repo.getById(id), isNull);
    expect(await File(vaultPath).exists(), isFalse);
  });

  test('deleting the trip cascades entries and their photos', () async {
    final tripId = await createTrip();
    await repo.createEntry(tripId: tripId, summary: 'Entry 1');
    await tripRepo.deleteTrip(tripId);

    final entries = await repo.watchForTrip(tripId).first;
    expect(entries, isEmpty);
    final orphanCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM journal_entries')
        .getSingle();
    expect(orphanCount.data['c'], 0);
  });

  test('watchForTrip emits entries ordered ascending by loggedAt', () async {
    final tripId = await createTrip();
    await repo.createEntry(
      tripId: tripId,
      summary: 'Later',
      loggedAt: DateTime(2026, 7, 20),
    );
    await repo.createEntry(
      tripId: tripId,
      summary: 'Earlier',
      loggedAt: DateTime(2026, 7, 17),
    );
    final entries = await repo.watchForTrip(tripId).first;
    expect(entries.map((e) => e.summary).toList(), ['Earlier', 'Later']);
  });

  test('watchForTrip only emits entries for that trip', () async {
    final tripA = await createTrip();
    final tripB = await tripRepo.createTrip(
      name: 'Other trip',
      destinations: ['Rome'],
      colorTag: 0,
    );
    await repo.createEntry(tripId: tripA, summary: 'A entry');
    await repo.createEntry(tripId: tripB, summary: 'B entry');

    final entries = await repo.watchForTrip(tripA).first;
    expect(entries.map((e) => e.summary).toList(), ['A entry']);
  });
}
