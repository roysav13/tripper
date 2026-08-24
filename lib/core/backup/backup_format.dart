/// Backup archive vocabulary that both platforms can name.
///
/// The archive *writer* is filesystem-bound and Android-only (see
/// `backup_service.dart`), but the failure types have to be catchable
/// from the shared Settings screen, so they live here where web code can
/// import them too.
library;

/// Bumped only when the archive layout itself changes.
const kBackupFormatVersion = 1;

class BackupException implements Exception {
  const BackupException(this.reason);

  final BackupFailure reason;
}

enum BackupFailure { corruptArchive, newerFormat, newerSchema }
