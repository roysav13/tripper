import 'package:gal/gal.dart';

import '../files/local_file_store.dart';

/// Android: hand the file straight to the system gallery. Keys are real
/// paths here, so nothing needs to be read into memory first.
Future<void> saveImageToDevice(String storageKey, LocalFileStore store) =>
    Gal.putImage(storageKey);
