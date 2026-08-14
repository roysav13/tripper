import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';
import 'package:tripper/core/files/file_vault_service.dart';
import 'package:tripper/features/trips/data/trip_repository.dart';
import 'package:tripper/features/vault/data/document_repository.dart';
import 'package:tripper/features/vault/domain/document.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late DriftDocumentRepository repo;
  late DriftTripRepository tripRepo;
  var idCounter = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('dao_test');
    idCounter = 0;
    repo = DriftDocumentRepository(
      db.documentsDao,
      FileVaultService(() async => tempDir),
      () => DateTime(2026, 7, 19),
      () => 'doc-${idCounter++}',
    );
    tripRepo = DriftTripRepository(db.tripsDao, () => DateTime(2026, 7, 19));
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<String> createTrip(String name) => tripRepo.createTrip(
        name: name,
        destinations: ['Somewhere'],
        startDate: DateTime(2026, 7, 16),
        endDate: DateTime(2026, 7, 27),
        colorTag: 0,
      );

  test('a new document\'s createdAt comes from the injected clock', () async {
    final id = await repo.createDocument(
      title: 'Passport',
      category: DocumentCategory.passportId,
    );
    final doc = (await repo.getById(id))!;
    expect(doc.createdAt, DateTime(2026, 7, 19));
  });

  test('manual record roundtrips with details JSON', () async {
    final id = await repo.createDocument(
      title: 'Flight to BKK',
      category: DocumentCategory.flight,
      details: {'flightNumber': 'LY083', 'confirmationCode': 'XK4R2M'},
    );
    final doc = (await repo.getById(id))!;
    expect(doc.category, DocumentCategory.flight);
    expect(
      doc.details,
      {'flightNumber': 'LY083', 'confirmationCode': 'XK4R2M'},
    );
    expect(doc.hasFile, isFalse);
  });

  test('link and unlink trips', () async {
    final tripA = await createTrip('A');
    final tripB = await createTrip('B');
    final id = await repo.createDocument(
      title: 'Passport',
      category: DocumentCategory.passportId,
      isGlobal: true,
      tripIds: [tripA],
    );

    var doc = (await repo.getById(id))!;
    expect(doc.tripIds, [tripA]);

    await repo.setLinks(id, [tripA, tripB]);
    doc = (await repo.getById(id))!;
    expect(doc.tripIds.toSet(), {tripA, tripB});

    await repo.setLinks(id, []);
    doc = (await repo.getById(id))!;
    expect(doc.tripIds, isEmpty);
  });

  test('deleting a trip unlinks but keeps the document', () async {
    final tripA = await createTrip('A');
    final id = await repo.createDocument(
      title: 'Insurance',
      category: DocumentCategory.insurance,
      tripIds: [tripA],
    );
    await tripRepo.deleteTrip(tripA);
    final doc = await repo.getById(id);
    expect(doc, isNotNull);
    expect(doc!.tripIds, isEmpty);
  });

  test('deleting a document removes its links and vault file', () async {
    final src = File('${tempDir.path}/ticket.pdf');
    await src.writeAsString('pdf');
    final tripA = await createTrip('A');
    final id = await repo.createDocument(
      title: 'Ticket',
      category: DocumentCategory.transport,
      sourceFilePath: src.path,
      tripIds: [tripA],
    );
    final vaultPath = (await repo.getById(id))!.filePath!;
    expect(await File(vaultPath).exists(), isTrue);

    await repo.deleteDocument(id);
    expect(await repo.getById(id), isNull);
    expect(await File(vaultPath).exists(), isFalse);
    final linkCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM trip_documents')
        .getSingle();
    expect(linkCount.data['c'], 0);
  });

  test('pin limit is enforced at $kMaxPinned', () async {
    final ids = <String>[];
    for (var i = 0; i < kMaxPinned + 1; i++) {
      ids.add(
        await repo.createDocument(
          title: 'Doc $i',
          category: DocumentCategory.other,
        ),
      );
    }
    for (var i = 0; i < kMaxPinned; i++) {
      await repo.setPinned(ids[i], pinned: true);
    }
    expect(
      () => repo.setPinned(ids[kMaxPinned], pinned: true),
      throwsA(isA<PinLimitReachedException>()),
    );
    // Unpin one -> pinning works again.
    await repo.setPinned(ids[0], pinned: false);
    await repo.setPinned(ids[kMaxPinned], pinned: true);
  });

  test('watchForTrip only emits linked documents', () async {
    final tripA = await createTrip('A');
    await repo.createDocument(
      title: 'Linked',
      category: DocumentCategory.stay,
      tripIds: [tripA],
    );
    await repo.createDocument(
      title: 'Unlinked',
      category: DocumentCategory.other,
    );
    final docs = await repo.watchForTrip(tripA).first;
    expect(docs.map((d) => d.title).toList(), ['Linked']);
  });

  test(
      'a live subscription re-emits when a standalone document is linked '
      'after the fact (Vault screen scenario, not a fresh query)', () async {
    final tripA = await createTrip('A');
    final id = await repo.createDocument(
      title: 'Passport',
      category: DocumentCategory.passportId,
      isGlobal: true,
      // Deliberately unlinked at creation — mirrors a standalone vault doc.
    );

    // Subscribe *before* linking, like a screen that's already open and
    // watching — this is what repo.getById()-based tests never exercised.
    final emissions = <List<String>>[];
    final sub = repo.watchForTrip(tripA).listen(
          (docs) => emissions.add(docs.map((d) => d.id).toList()),
        );
    addTearDown(sub.cancel);

    // Let the initial (empty) emission land before mutating.
    await Future<void>.delayed(Duration.zero);
    expect(emissions, <List<String>>[<String>[]], reason: 'starts unlinked');

    await repo.setLinks(id, [tripA]);
    await Future<void>.delayed(Duration.zero);

    expect(
      emissions.last,
      [id],
      reason: 'an already-subscribed stream must reflect a link added later',
    );
  });
}
