import 'dart:js_interop';

import 'package:path/path.dart' as p;

import '../files/local_file_store.dart';
import 'download_web.dart';

/// Web: browsers have no photo library, so "save" means "download".
Future<void> saveImageToDevice(String storageKey, LocalFileStore store) async {
  final bytes = await store.read(storageKey);
  if (bytes == null) {
    throw StateError('No stored file for key "$storageKey"');
  }
  await downloadBytes(bytes.toJS, fileName: p.basename(storageKey));
}
