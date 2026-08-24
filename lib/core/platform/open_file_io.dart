import 'package:open_filex/open_filex.dart';

import '../files/local_file_store.dart';

/// Android: hand the path to whatever app claims the MIME type.
Future<void> openStoredFile(
  String storageKey,
  LocalFileStore store, {
  String? fileName,
}) async {
  await OpenFilex.open(storageKey);
}
