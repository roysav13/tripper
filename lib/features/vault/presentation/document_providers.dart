import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/files/file_vault_service.dart';
import '../data/document_repository.dart';
import '../data/documents_dao.dart';
import '../domain/document.dart';

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
