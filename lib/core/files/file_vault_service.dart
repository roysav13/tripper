import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'local_file_store.dart';

export 'local_file_store.dart'
    show FileTooLargeException, LocalFileStore, kMaxVaultFileBytes;

/// Filesystem-backed [LocalFileStore]: `{appDocs}/{subfolder}/{uuid}.{ext}`.
///
/// Keys are absolute paths, which is what the database has always stored,
/// so this stayed the Android behaviour unchanged when the web store was
/// added. Files are always copied in — picker content-URIs are ephemeral
/// on Android.
class FileVaultService implements LocalFileStore {
  FileVaultService(this._baseDir, {String subfolder = 'vault'})
      : _subfolder = subfolder;

  /// Injected for tests (temp dir) vs production (app documents dir).
  final Future<Directory> Function() _baseDir;
  final String _subfolder;
  final _uuid = const Uuid();

  static const maxFileBytes = kMaxVaultFileBytes;

  Future<Directory> _vaultDir() async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, _subfolder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String> import(String source) async {
    final file = File(source);
    final size = await file.length();
    if (size > maxFileBytes) throw FileTooLargeException(size);
    final dir = await _vaultDir();
    final target = p.join(dir.path, '${_uuid.v4()}${p.extension(source)}');
    await file.copy(target);
    return target;
  }

  @override
  Future<String> importBytes(Uint8List bytes, {String extension = ''}) async {
    if (bytes.length > maxFileBytes) throw FileTooLargeException(bytes.length);
    final dir = await _vaultDir();
    final target = p.join(dir.path, '${_uuid.v4()}$extension');
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }

  @override
  Future<Uint8List?> read(String key) async {
    final file = File(key);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> delete(String key) async {
    final file = File(key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<bool> exists(String key) => File(key).exists();

  @override
  Future<List<String>> sweepOrphans(Set<String> referencedKeys) async {
    final dir = await _vaultDir();
    await for (final entity in dir.list()) {
      if (entity is File && !referencedKeys.contains(entity.path)) {
        await entity.delete();
      }
    }
    final missing = <String>[];
    for (final key in referencedKeys) {
      if (!await File(key).exists()) missing.add(key);
    }
    return missing;
  }
}
