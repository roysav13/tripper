import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Owns a storage subfolder: {appDocs}/{subfolder}/{uuid}.{ext}. Defaults
/// to the document vault ('vault'); pass a different [subfolder] for other
/// local-file features (e.g. trip cover photos — 'covers') so their files
/// never mix with vault documents. [sweepOrphans] assumes every file in
/// its own folder belongs to the table it was constructed for, so mixing
/// folders would make it delete files a different feature still needs.
/// Files are always copied in — picker content-URIs are ephemeral on Android.
class FileVaultService {
  FileVaultService(this._baseDir, {String subfolder = 'vault'})
      : _subfolder = subfolder;

  /// Injected for tests (temp dir) vs production (app documents dir).
  final Future<Directory> Function() _baseDir;
  final String _subfolder;
  final _uuid = const Uuid();

  static const maxFileBytes = 20 * 1024 * 1024;

  Future<Directory> _vaultDir() async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, _subfolder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies [sourcePath] into the vault; returns the vault path.
  /// Throws [FileTooLargeException] above [maxFileBytes].
  Future<String> import(String sourcePath) async {
    final source = File(sourcePath);
    final size = await source.length();
    if (size > maxFileBytes) throw FileTooLargeException(size);
    final dir = await _vaultDir();
    final ext = p.extension(sourcePath);
    final target = p.join(dir.path, '${_uuid.v4()}$ext');
    await source.copy(target);
    return target;
  }

  Future<void> delete(String vaultPath) async {
    final file = File(vaultPath);
    if (await file.exists()) await file.delete();
  }

  Future<bool> exists(String vaultPath) => File(vaultPath).exists();

  /// Files on disk with no DB reference are deleted; DB paths with no file
  /// are returned so rows can be flagged "file missing".
  Future<List<String>> sweepOrphans(Set<String> referencedPaths) async {
    final dir = await _vaultDir();
    await for (final entity in dir.list()) {
      if (entity is File && !referencedPaths.contains(entity.path)) {
        await entity.delete();
      }
    }
    final missing = <String>[];
    for (final path in referencedPaths) {
      if (!await File(path).exists()) missing.add(path);
    }
    return missing;
  }
}

class FileTooLargeException implements Exception {
  const FileTooLargeException(this.actualBytes);

  final int actualBytes;
}

final fileVaultServiceProvider = Provider<FileVaultService>(
  (ref) => FileVaultService(getApplicationDocumentsDirectory),
);
