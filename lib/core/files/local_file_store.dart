import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_store_factory_io.dart'
    if (dart.library.js_interop) 'file_store_factory_web.dart';

/// Ceiling for a single stored file, on every platform.
const kMaxVaultFileBytes = 20 * 1024 * 1024;

class FileTooLargeException implements Exception {
  const FileTooLargeException(this.actualBytes);

  final int actualBytes;
}

/// Local blob storage for user files — vault documents, journal photos,
/// trip covers.
///
/// Callers hold on to the opaque **key** this returns and store it in the
/// database; they must never build one themselves or assume its shape.
/// On Android a key happens to be an absolute filesystem path (which is
/// what every existing row already contains, so nothing needs migrating);
/// on the web it is an IndexedDB record id. Treat it as a cookie either
/// way.
///
/// Each instance owns one namespace (`subfolder`) and [sweepOrphans]
/// deletes anything in that namespace it wasn't told about — so two
/// features must never share one store, or one will delete the other's
/// files.
abstract interface class LocalFileStore {
  /// Copies the file at [source] into the store and returns its key.
  ///
  /// [source] is a filesystem path on Android and a `blob:`/`http:` URL
  /// on the web (what image and file pickers hand back there). Throws
  /// [FileTooLargeException] above [kMaxVaultFileBytes].
  Future<String> import(String source);

  /// Stores [bytes] directly. [extension] is the dotted suffix to record
  /// in the key (`.pdf`); it may be empty. Use this whenever the caller
  /// already holds bytes — a web file picker never yields a readable
  /// path. Throws [FileTooLargeException] above [kMaxVaultFileBytes].
  Future<String> importBytes(Uint8List bytes, {String extension = ''});

  /// The stored bytes, or null if [key] is gone (a restored backup that
  /// lost a file, a browser that evicted storage).
  Future<Uint8List?> read(String key);

  Future<void> delete(String key);

  Future<bool> exists(String key);

  /// Deletes stored files no row references any more, and returns the
  /// keys whose file has vanished so rows can be flagged "file missing".
  Future<List<String>> sweepOrphans(Set<String> referencedKeys);
}

/// The document vault's store. Journal photos share it; trip covers get
/// their own (see `coverPhotoFileServiceProvider`) so neither sweep
/// deletes the other's files.
final fileVaultServiceProvider = Provider<LocalFileStore>(
  (ref) => createLocalFileStore(subfolder: 'vault'),
);
