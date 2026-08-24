import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hands [bytes] to the browser as a download named [fileName].
///
/// This is the web's only route for "get this file out of the app": there
/// is no gallery to save into and no other app to hand a path to. On iOS
/// Safari it opens the share sheet, which is how a boarding pass reaches
/// Files or Photos.
///
/// The object URL is revoked once the click has been dispatched, so the
/// browser's copy of the bytes is released as the download starts.
Future<void> downloadBytes(
  JSUint8Array bytes, {
  required String fileName,
}) async {
  final blob = web.Blob(
    [bytes].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
