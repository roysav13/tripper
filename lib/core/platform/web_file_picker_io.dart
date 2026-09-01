import 'dart:typed_data';

/// Native builds never take this path — `document_form_sheet.dart` only
/// calls [pickWebFile] when `kIsWeb`, and Android keeps using
/// `FilePicker.platform` directly.
class PickedWebFile {
  const PickedWebFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

Future<PickedWebFile?> pickWebFile({required String accept}) {
  throw UnsupportedError('pickWebFile is web-only');
}
