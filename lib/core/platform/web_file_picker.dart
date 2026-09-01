/// Web-only file picker used in place of `package:file_picker` for the
/// vault's "Attach file" button.
///
/// `file_picker`'s web implementation guesses a cancelled dialog by racing
/// a 1-second timer against the window regaining `focus`, and on iOS
/// Safari the real `change` event carrying the picked file routinely
/// lands *after* that timer — especially once the Photos picker has to
/// convert a HEIC/large image — so a genuine pick gets silently treated
/// as a cancel and the file never reaches the app (found on iPhone,
/// 2026-09-01: "attach file" appeared to do nothing after choosing a
/// photo). This waits only on the real `change`/`cancel` events, with no
/// such race.
library;

export 'web_file_picker_io.dart'
    if (dart.library.js_interop) 'web_file_picker_web.dart'
    show pickWebFile, PickedWebFile;
