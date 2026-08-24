import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

import '../../platform/storage_durability.dart';

/// Web: SQLite compiled to WebAssembly, persisted by the browser.
///
/// `sqlite3.wasm` and `drift_worker.js` are served from the app root —
/// both are committed under `web/` and cached by the service worker, so
/// an installed PWA opens its database with no network at all.
///
/// Drift negotiates the best storage the browser will give it (OPFS in a
/// dedicated worker down to IndexedDB). Every option except the last one
/// persists; if we land on an in-memory database we record that in
/// [storageDurability] so the UI can warn instead of pretending the data
/// is saved.
QueryExecutor openTripperDatabase() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'tripper',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    storageDurability.value =
        result.chosenImplementation == WasmStorageImplementation.inMemory
            ? StorageDurability.ephemeral
            : StorageDurability.durable;

    if (kDebugMode) {
      debugPrint(
        '[db] web storage: ${result.chosenImplementation.name}'
        '${result.missingFeatures.isEmpty ? '' : ' '
            '(missing: ${result.missingFeatures.map((f) => f.name).join(', ')})'}',
      );
    }
    return result.resolvedExecutor;
  });
}
