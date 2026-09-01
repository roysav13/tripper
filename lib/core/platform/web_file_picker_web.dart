import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PickedWebFile {
  const PickedWebFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// Opens the browser's native file picker and resolves on the real
/// `change` (a file was chosen) or `cancel` (the user backed out) event —
/// never on a guessed timeout, so a slow `change` never reads as a cancel.
Future<PickedWebFile?> pickWebFile({required String accept}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..style.display = 'none';
  web.document.body!.appendChild(input);

  final completer = Completer<web.File?>();
  input.addEventListener(
    'change',
    (web.Event _) {
      if (!completer.isCompleted) completer.complete(input.files?.item(0));
    }.toJS,
  );
  input.addEventListener(
    'cancel',
    (web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }.toJS,
  );

  input.click();
  final file = await completer.future;
  input.remove();
  if (file == null) return null;

  final buffer = await file.arrayBuffer().toDart;
  return PickedWebFile(name: file.name, bytes: buffer.toDart.asUint8List());
}
