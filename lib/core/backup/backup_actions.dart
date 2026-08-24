/// Platform entry points for the backup archive, so the Settings screen
/// never imports the filesystem-bound writer directly.
///
/// `kSupportsBackupArchive` is false on the web; the other three throw
/// there and must not be called. See `backup_actions_web.dart` for why.
library;

export 'backup_actions_io.dart'
    if (dart.library.js_interop) 'backup_actions_web.dart'
    show
        kSupportsBackupArchive,
        writeBackupArchive,
        restoreBackupArchive,
        shareBackupArchive;
