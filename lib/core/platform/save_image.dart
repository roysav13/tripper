/// `saveImageToDevice(storageKey, store)` — puts a stored photo somewhere
/// the user can find it outside Tripper: the system gallery on Android, a
/// browser download on the web.
library;

export 'save_image_io.dart' if (dart.library.js_interop) 'save_image_web.dart'
    show saveImageToDevice;
