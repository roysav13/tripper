import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../files/file_extensions.dart';

/// A `blob:` object URL standing in for a temp file. Anything that only
/// reads the handle back — `XFile`, `NetworkImage` — works with one
/// unchanged, which is what lets scratch-file callers stay
/// platform-agnostic.
Future<String?> writeScratchFile(
  Uint8List bytes, {
  required String extension,
  required String prefix,
}) async {
  try {
    // The Blob's type is the handle's only record of what kind of file
    // this is — a `blob:` URL has no extension — and the file store
    // reads it back when importing.
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeTypeForExtension(extension)),
    );
    return web.URL.createObjectURL(blob);
  } catch (_) {
    return null;
  }
}

/// Releases the browser's copy of the blob.
Future<void> deleteScratchFile(String handle) async {
  try {
    web.URL.revokeObjectURL(handle);
  } catch (_) {}
}
