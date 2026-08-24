import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A file in the OS temp directory. Returns null if it can't be written.
Future<String?> writeScratchFile(
  Uint8List bytes, {
  required String extension,
  required String prefix,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final name = '$prefix${DateTime.now().microsecondsSinceEpoch}$extension';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

/// Best-effort — a leftover temp file is harmless, a crash over one is not.
Future<void> deleteScratchFile(String handle) async {
  try {
    await File(handle).delete();
  } catch (_) {}
}
