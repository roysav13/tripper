import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import 'backup_service.dart';

const kSupportsBackupArchive = true;

BackupService _service(AppDatabase db, DateTime Function() clock) =>
    BackupService(db, getApplicationDocumentsDirectory, clock);

/// Writes the archive to a temp file and returns its path.
Future<String> writeBackupArchive(
  AppDatabase db,
  DateTime Function() clock,
) async {
  final service = _service(db, clock);
  final tempDir = await getTemporaryDirectory();
  final target = p.join(tempDir.path, service.suggestedFileName());
  final file = await service.export(target);
  return file.path;
}

Future<void> restoreBackupArchive(
  AppDatabase db,
  DateTime Function() clock,
  String handle,
) =>
    _service(db, clock).import(handle);

/// System share sheet — the user picks Drive, email, local storage…
Future<void> shareBackupArchive(String handle, {required String text}) async {
  await Share.shareXFiles([XFile(handle)], text: text);
}
