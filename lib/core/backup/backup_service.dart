import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';

/// Bumped only when the archive layout itself changes.
const kBackupFormatVersion = 1;

const _manifestName = 'manifest.json';
const _dbName = 'tripper.db';
const _vaultDir = 'vault';

class BackupException implements Exception {
  const BackupException(this.reason);

  final BackupFailure reason;
}

enum BackupFailure { corruptArchive, newerFormat, newerSchema }

/// Local-first means uninstall = data loss. This is the insurance policy
/// until cloud sync (SPEC Phase 3): one zip with the DB snapshot, every
/// vault file, and a manifest.
class BackupService {
  BackupService(this._db, this._baseDir, this._clock);

  final AppDatabase _db;
  final Future<Directory> Function() _baseDir;
  final DateTime Function() _clock;

  String suggestedFileName() {
    final now = _clock();
    final stamp = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    return 'tripper-backup-$stamp.zip';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Writes the archive to [targetPath] and returns it.
  Future<File> export(String targetPath) async {
    final base = await _baseDir();
    final staging = Directory(p.join(base.path, 'backup_tmp'));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    try {
      // VACUUM INTO — never zip a live database file.
      final snapshot = p.join(staging.path, _dbName);
      await _db
          .customStatement("VACUUM INTO '${snapshot.replaceAll("'", "''")}'");

      final vaultSource = Directory(p.join(base.path, _vaultDir));
      final fileNames = <String>[];
      if (await vaultSource.exists()) {
        await for (final entity in vaultSource.list()) {
          if (entity is File) fileNames.add(p.basename(entity.path));
        }
      }

      final manifest = {
        'formatVersion': kBackupFormatVersion,
        'schemaVersion': _db.schemaVersion,
        'createdAt': _clock().toIso8601String(),
        'fileCount': fileNames.length,
      };
      await File(p.join(staging.path, _manifestName))
          .writeAsString(jsonEncode(manifest));

      final encoder = ZipFileEncoder()..create(targetPath);
      await encoder.addFile(File(p.join(staging.path, _manifestName)));
      await encoder.addFile(File(snapshot));
      if (fileNames.isNotEmpty) {
        await encoder.addDirectory(vaultSource);
      }
      await encoder.close();
      return File(targetPath);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Replaces all current data with the archive's contents.
  /// Caller must close/recreate the database afterwards.
  Future<void> import(String archivePath) async {
    final bytes = await File(archivePath).readAsBytes();
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupException(BackupFailure.corruptArchive);
    }

    ArchiveFile? entry(String suffix) {
      for (final f in archive.files) {
        if (f.isFile && p.basename(f.name) == suffix) return f;
      }
      return null;
    }

    final manifestEntry = entry(_manifestName);
    final dbEntry = entry(_dbName);
    if (manifestEntry == null || dbEntry == null) {
      throw const BackupException(BackupFailure.corruptArchive);
    }

    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestEntry.content as List<int>))
          as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException(BackupFailure.corruptArchive);
    }

    final formatVersion = manifest['formatVersion'] as int? ?? 0;
    if (formatVersion > kBackupFormatVersion) {
      throw const BackupException(BackupFailure.newerFormat);
    }
    final schemaVersion = manifest['schemaVersion'] as int? ?? 0;
    if (schemaVersion > _db.schemaVersion) {
      // Restoring a future schema would corrupt reads — refuse clearly.
      throw const BackupException(BackupFailure.newerSchema);
    }

    final base = await _baseDir();
    // Restore vault files first: if this fails the DB is still intact.
    final vaultTarget = Directory(p.join(base.path, _vaultDir));
    if (await vaultTarget.exists()) await vaultTarget.delete(recursive: true);
    await vaultTarget.create(recursive: true);
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = p.basename(f.name);
      if (name == _manifestName || name == _dbName) continue;
      if (!f.name.contains('$_vaultDir/')) continue;
      await File(p.join(vaultTarget.path, name))
          .writeAsBytes(f.content as List<int>);
    }

    await _db.close();
    await File(p.join(base.path, _dbName))
        .writeAsBytes(dbEntry.content as List<int>);
  }
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    getApplicationDocumentsDirectory,
    ref.watch(clockProvider),
  ),
);
