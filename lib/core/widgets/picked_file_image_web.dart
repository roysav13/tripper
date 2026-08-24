import 'package:flutter/painting.dart';

/// [source] is a `blob:` object URL here — what browser pickers return.
/// [NetworkImage] fetches those from the browser's own blob registry, so
/// nothing leaves the device.
ImageProvider pickedFileImage(String source) => NetworkImage(source);
