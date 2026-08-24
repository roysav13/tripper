/// `openStoredFile(storageKey, store, fileName:)` — hands a vault file to
/// the rest of the device: another app via the Android intent system, or
/// a browser download on the web.
library;

export 'open_file_io.dart'
    if (dart.library.js_interop) 'open_file_web.dart'
    show openStoredFile;
