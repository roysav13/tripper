import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../platform/storage_durability.dart';

/// Android/desktop: a real SQLite file in the app documents directory.
QueryExecutor openTripperDatabase() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    storageDurability.value = StorageDurability.durable;
    return NativeDatabase.createInBackground(
      File(p.join(dir.path, 'tripper.db')),
    );
  });
}
