/// Short-lived storage for bytes that only need to survive one screen —
/// a downloaded thumbnail on its way to OCR, a rasterized PDF page.
///
/// `writeScratchFile` returns an opaque handle: a temp-file path on
/// Android, a `blob:` object URL on the web. Callers pass it straight to
/// whatever consumes it and hand it back to `deleteScratchFile` when
/// they're done; nothing should parse it.
library;

export 'scratch_file_io.dart'
    if (dart.library.js_interop) 'scratch_file_web.dart'
    show writeScratchFile, deleteScratchFile;
