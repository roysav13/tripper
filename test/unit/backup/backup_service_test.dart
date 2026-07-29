import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tripper/core/backup/backup_service.dart';
import 'package:tripper/core/database/app_database.dart';
import 'package:tripper/features/trips/data/trip_repository.dart';

void main() {
  late Directory baseDir;
  late AppDatabase db;
  late BackupService service;
  final clock = DateTime(2026, 7, 19);

  setUp(() async {
    baseDir = await Directory.systemTemp.createTemp('backup_test');
    // File-backed (not memory): VACUUM INTO needs a real database.
    db = AppDatabase(NativeDatabase(File(p.join(baseDir.path, 'tripper.db'))));
    service = BackupService(db, () async => baseDir, () => clock);
  });

  tearDown(() async {
    await db.close();
    if (await baseDir.exists()) await baseDir.delete(recursive: true);
  });

  Future<void> seed() async {
    final repo = DriftTripRepository(db.tripsDao, () => clock);
    await repo.createTrip(
      name: 'Thailand',
      destinations: ['Krabi'],
      startDate: DateTime(2026, 7, 16),
      endDate: DateTime(2026, 7, 27),
      colorTag: 0,
    );
    final vault = Directory(p.join(baseDir.path, 'vault'))
      ..createSync(recursive: true);
    File(p.join(vault.path, 'passport.pdf')).writeAsStringSync('pdf-bytes');
  }

  test('suggested file name carries the date', () {
    expect(service.suggestedFileName(), 'tripper-backup-2026-07-19.zip');
  });

  test('export produces a zip with manifest, db and vault files', () async {
    await seed();
    final target = p.join(baseDir.path, 'out.zip');
    final file = await service.export(target);
    expect(await file.exists(), isTrue);

    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final names = archive.files.map((f) => p.basename(f.name)).toList();
    expect(names, contains('manifest.json'));
    expect(names, contains('tripper.db'));
    expect(names, contains('passport.pdf'));

    final manifestFile =
        archive.files.firstWhere((f) => p.basename(f.name) == 'manifest.json');
    final manifest = jsonDecode(
      utf8.decode(manifestFile.content as List<int>),
    ) as Map<String, dynamic>;
    expect(manifest['formatVersion'], kBackupFormatVersion);
    expect(manifest['schemaVersion'], db.schemaVersion);
    expect(manifest['fileCount'], 1);

    // Staging directory is cleaned up.
    expect(
      await Directory(p.join(baseDir.path, 'backup_tmp')).exists(),
      isFalse,
    );
  });

  test('roundtrip: export, wipe, import restores rows and files', () async {
    await seed();
    final target = p.join(baseDir.path, 'out.zip');
    await service.export(target);

    // Wipe: drop the trip and the vault file.
    final repo = DriftTripRepository(db.tripsDao, () => clock);
    final trips = await repo.watchTrips().first;
    await repo.deleteTrip(trips.single.id);
    File(p.join(baseDir.path, 'vault', 'passport.pdf')).deleteSync();
    expect(await repo.watchTrips().first, isEmpty);

    await service.import(target);

    // Import closes the DB; reopen to verify contents came back.
    final restored =
        AppDatabase(NativeDatabase(File(p.join(baseDir.path, 'tripper.db'))));
    addTearDown(restored.close);
    final restoredRepo = DriftTripRepository(restored.tripsDao, () => clock);
    final restoredTrips = await restoredRepo.watchTrips().first;
    expect(restoredTrips.single.name, 'Thailand');
    expect(restoredTrips.single.destinations, ['Krabi']);
    expect(
      File(p.join(baseDir.path, 'vault', 'passport.pdf')).readAsStringSync(),
      'pdf-bytes',
    );
  });

  test('corrupt archive is rejected', () async {
    final bogus = File(p.join(baseDir.path, 'bogus.zip'))
      ..writeAsStringSync('not a zip');
    expect(
      () => service.import(bogus.path),
      throwsA(
        isA<BackupException>().having(
          (e) => e.reason,
          'reason',
          BackupFailure.corruptArchive,
        ),
      ),
    );
  });

  test('backup from a newer schema is refused', () async {
    final staging = Directory(p.join(baseDir.path, 'fake'))
      ..createSync(recursive: true);
    File(p.join(staging.path, 'manifest.json')).writeAsStringSync(
      jsonEncode({
        'formatVersion': kBackupFormatVersion,
        'schemaVersion': 999,
        'createdAt': clock.toIso8601String(),
        'fileCount': 0,
      }),
    );
    File(p.join(staging.path, 'tripper.db')).writeAsStringSync('x');
    final target = p.join(baseDir.path, 'future.zip');
    final encoder = ZipFileEncoder()..create(target);
    await encoder.addFile(File(p.join(staging.path, 'manifest.json')));
    await encoder.addFile(File(p.join(staging.path, 'tripper.db')));
    await encoder.close();

    expect(
      () => service.import(target),
      throwsA(
        isA<BackupException>().having(
          (e) => e.reason,
          'reason',
          BackupFailure.newerSchema,
        ),
      ),
    );
  });
}
