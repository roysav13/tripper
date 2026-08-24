import '../database/app_database.dart';

/// The archive format is a `VACUUM INTO` snapshot of the SQLite file plus
/// the vault directory, zipped. Neither half exists in a browser: drift's
/// WASM database lives inside an OPFS/IndexedDB VFS with no readable path
/// to vacuum into, and vault files are IndexedDB records rather than a
/// directory. Producing a *different* archive format on the web would
/// give the user a file Android can't restore, which is worse than
/// saying so plainly — Settings hides the section and explains instead.
const kSupportsBackupArchive = false;

Future<String> writeBackupArchive(
  AppDatabase db,
  DateTime Function() clock,
) =>
    throw UnsupportedError('Backup archives are not available on the web');

Future<void> restoreBackupArchive(
  AppDatabase db,
  DateTime Function() clock,
  String handle,
) =>
    throw UnsupportedError('Backup archives are not available on the web');

Future<void> shareBackupArchive(String handle, {required String text}) =>
    throw UnsupportedError('Backup archives are not available on the web');
