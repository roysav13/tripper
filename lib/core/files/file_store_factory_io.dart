import 'package:path_provider/path_provider.dart';

import 'file_vault_service.dart';

/// Android/desktop store for one namespace. Selected by the conditional
/// import in `local_file_store.dart`.
LocalFileStore createLocalFileStore({required String subfolder}) =>
    FileVaultService(getApplicationDocumentsDirectory, subfolder: subfolder);
