import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Overridden in tests with AppDatabase(NativeDatabase.memory()).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(dir.path, 'tripper.db')),
      );
    }),
  );
  ref.onDispose(db.close);
  return db;
});

/// Injectable clock — domain code never calls DateTime.now() directly.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
