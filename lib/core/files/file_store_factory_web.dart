import 'local_file_store.dart';
import 'web_file_store.dart';

/// Browser store for one namespace. Selected by the conditional import in
/// `local_file_store.dart`.
LocalFileStore createLocalFileStore({required String subfolder}) =>
    WebFileStore(subfolder: subfolder);
