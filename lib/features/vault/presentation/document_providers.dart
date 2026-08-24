import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/files/local_file_store.dart';
import '../../../core/filtering/filter_sort_controller.dart';
import '../../../core/filtering/sort_spec.dart';
import '../data/document_repository.dart';
import '../data/documents_dao.dart';
import '../domain/document.dart';
import '../domain/document_sort.dart';

const _uuid = Uuid();

final documentsDaoProvider =
    Provider<DocumentsDao>((ref) => ref.watch(databaseProvider).documentsDao);

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DriftDocumentRepository(
    ref.watch(documentsDaoProvider),
    ref.watch(fileVaultServiceProvider),
    ref.watch(clockProvider),
    _uuid.v4,
  ),
);

final vaultDocumentsProvider = StreamProvider<List<Document>>(
  (ref) => ref.watch(documentRepositoryProvider).watchAll(),
);

final pinnedDocumentsProvider = Provider<List<Document>>((ref) {
  final docs = ref.watch(vaultDocumentsProvider).valueOrNull ?? const [];
  return docs.where((d) => d.isPinned).toList();
});

final tripDocumentsProvider = StreamProvider.family<List<Document>, String>(
  (ref, tripId) => ref.watch(documentRepositoryProvider).watchForTrip(tripId),
);

/// One filter+sort state for the Vault tab — a single scope (`'vault'`),
/// unlike Places, since Vault has no per-trip filter/sort surface.
final documentFilterSortProvider = NotifierProvider.family<
    FilterSortController<DocumentSortField>,
    FilterSortState<DocumentSortField>,
    String>(
  () => FilterSortController<DocumentSortField>(
    const SortSpec(DocumentSortField.createdDate, SortDirection.descending),
  ),
);
