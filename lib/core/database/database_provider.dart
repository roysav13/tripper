import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'connection/connection_io.dart'
    if (dart.library.js_interop) 'connection/connection_web.dart';

/// Overridden in tests with AppDatabase(NativeDatabase.memory()).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openTripperDatabase());
  ref.onDispose(db.close);
  return db;
});

/// Injectable clock — domain code never calls DateTime.now() directly.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
