import 'dart:js_interop';

import 'package:path/path.dart' as p;

import '../files/local_file_store.dart';
import 'download_web.dart';

/// Web: a page can't launch another app, so "open" becomes "download it
/// and let the OS decide" — which on iOS Safari is the share sheet, and
/// gets a PDF into Files or straight into a viewer.
Future<void> openStoredFile(
  String storageKey,
  LocalFileStore store, {
  String? fileName,
}) async {
  final bytes = await store.read(storageKey);
  if (bytes == null) {
    throw StateError('No stored file for key "$storageKey"');
  }
  await downloadBytes(bytes.toJS, fileName: fileName ?? p.basename(storageKey));
}
