import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

import 'file_extensions.dart';
import 'local_file_store.dart';

const _databaseName = 'tripper_files';
const _storeName = 'files';

/// IndexedDB-backed [LocalFileStore] — the web counterpart of
/// `FileVaultService`.
///
/// Bytes go in as a `Uint8Array`, which the structured-clone algorithm
/// stores natively; nothing is base64'd, so a 20 MB document costs 20 MB.
/// Keys look like `vault/{uuid}.pdf` so one flat object store can hold
/// every namespace and [sweepOrphans] can still tell them apart.
///
/// One database is shared by all instances (opening the same IndexedDB
/// name twice is legal but pointless), so [_openDatabase] is memoised.
class WebFileStore implements LocalFileStore {
  WebFileStore({String subfolder = 'vault'}) : _subfolder = subfolder;

  final String _subfolder;
  final _uuid = const Uuid();

  static Future<web.IDBDatabase>? _database;

  static Future<web.IDBDatabase> _openDatabase() {
    return _database ??= () {
      final completer = Completer<web.IDBDatabase>();
      final request = web.window.indexedDB.open(_databaseName, 1);
      request.onupgradeneeded = (web.Event _) {
        final db = request.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      }.toJS;
      request.onsuccess = (web.Event _) {
        completer.complete(request.result as web.IDBDatabase);
      }.toJS;
      request.onerror = (web.Event _) {
        // Don't cache a failed open — private-browsing modes can start
        // refusing IndexedDB and then allow it again in a fresh tab.
        _database = null;
        completer.completeError(
          StateError('IndexedDB unavailable: ${request.error?.message}'),
        );
      }.toJS;
      return completer.future;
    }();
  }

  /// Runs [action] against the object store and waits for the surrounding
  /// transaction to commit, so a write is durable before we return its key.
  static Future<T> _transact<T>(
    String mode,
    FutureOr<T> Function(web.IDBObjectStore store) action,
  ) async {
    final db = await _openDatabase();
    final transaction = db.transaction(_storeName.toJS, mode);
    final result = await action(transaction.objectStore(_storeName));
    if (mode == 'readwrite') await _completed(transaction);
    return result;
  }

  static Future<void> _completed(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;
    void fail(web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB write failed: ${transaction.error?.message}'),
        );
      }
    }

    transaction.onerror = fail.toJS;
    transaction.onabort = fail.toJS;
    return completer.future;
  }

  static Future<JSAny?> _await(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = (web.Event _) {
      if (!completer.isCompleted) completer.complete(request.result);
    }.toJS;
    request.onerror = (web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB request failed: ${request.error?.message}'),
        );
      }
    }.toJS;
    return completer.future;
  }

  @override
  Future<String> import(String source) async {
    // A picker hands back a `blob:` URL, not a path. Fetching it yields
    // both the bytes and the Blob's MIME type — the only surviving trace
    // of what kind of file the user chose, since the URL has no
    // extension to read one off.
    final response = await web.window.fetch(source.toJS).toDart;
    final blob = await response.blob().toDart;
    final buffer = await blob.arrayBuffer().toDart;
    final bytes = buffer.toDart.asUint8List();
    final extension =
        extensionForMimeType(blob.type) ?? p.extension(Uri.parse(source).path);
    return importBytes(bytes, extension: extension);
  }

  @override
  Future<String> importBytes(Uint8List bytes, {String extension = ''}) async {
    if (bytes.length > kMaxVaultFileBytes) {
      throw FileTooLargeException(bytes.length);
    }
    final key = '$_subfolder/${_uuid.v4()}$extension';
    await _transact(
      'readwrite',
      (store) => _await(store.put(bytes.toJS, key.toJS)),
    );
    return key;
  }

  @override
  Future<Uint8List?> read(String key) async {
    final value =
        await _transact('readonly', (store) => _await(store.get(key.toJS)));
    if (value == null || value.isUndefinedOrNull) return null;
    return (value as JSUint8Array).toDart;
  }

  @override
  Future<void> delete(String key) {
    return _transact('readwrite', (store) => _await(store.delete(key.toJS)));
  }

  @override
  Future<bool> exists(String key) async {
    final count =
        await _transact('readonly', (store) => _await(store.count(key.toJS)));
    return ((count as JSNumber?)?.toDartInt ?? 0) != 0;
  }

  @override
  Future<List<String>> sweepOrphans(Set<String> referencedKeys) async {
    final prefix = '$_subfolder/';
    final stored = await _transact('readonly', (store) async {
      final keys = await _await(store.getAllKeys()) as JSArray<JSAny?>;
      return keys.toDart
          .whereType<JSString>()
          .map((k) => k.toDart)
          .where((k) => k.startsWith(prefix))
          .toList();
    });

    // One transaction per delete, rather than looping inside a single one:
    // an IndexedDB transaction goes inactive once control returns to the
    // event loop, and awaiting between requests inside one is exactly the
    // pattern that has historically broken on Safari — which is the
    // browser this whole build exists for.
    for (final key in stored) {
      if (!referencedKeys.contains(key)) await delete(key);
    }

    final present = stored.toSet();
    return [
      for (final key in referencedKeys)
        if (!present.contains(key)) key,
    ];
  }
}
