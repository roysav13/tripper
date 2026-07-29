import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'document_tables.dart';

part 'documents_dao.g.dart';

class DocumentWithLinks {
  const DocumentWithLinks(this.document, this.tripIds);

  final DocumentRow document;
  final List<String> tripIds;
}

@DriftAccessor(tables: [Documents, TripDocuments])
class DocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$DocumentsDaoMixin {
  DocumentsDao(super.db);

  Stream<List<DocumentWithLinks>> watchAll() {
    final query = (select(documents)
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .join([
      leftOuterJoin(
        tripDocuments,
        tripDocuments.documentId.equalsExp(documents.id),
      ),
    ]);
    return query.watch().map(_group);
  }

  Stream<List<DocumentWithLinks>> watchForTrip(String tripId) {
    return watchAll().map(
      (docs) => [
        for (final d in docs)
          if (d.tripIds.contains(tripId)) d,
      ],
    );
  }

  Future<DocumentWithLinks?> getById(String id) async {
    final query = (select(documents)..where((d) => d.id.equals(id))).join([
      leftOuterJoin(
        tripDocuments,
        tripDocuments.documentId.equalsExp(documents.id),
      ),
    ]);
    final grouped = _group(await query.get());
    return grouped.isEmpty ? null : grouped.single;
  }

  Future<void> insertDocument(DocumentRow row) => into(documents).insert(row);

  Future<void> updateDocument(DocumentRow row) =>
      update(documents).replace(row);

  Future<void> deleteDocument(String id) =>
      (delete(documents)..where((d) => d.id.equals(id))).go();

  Future<void> setPinned(String id, bool pinned) =>
      (update(documents)..where((d) => d.id.equals(id)))
          .write(DocumentsCompanion(isPinned: Value(pinned)));

  Future<int> countPinned() async {
    final row = await (selectOnly(documents)
          ..addColumns([documents.id.count()])
          ..where(documents.isPinned.equals(true)))
        .getSingle();
    return row.read(documents.id.count()) ?? 0;
  }

  Future<void> setLinks(String documentId, List<String> tripIds) {
    return transaction(() async {
      await (delete(tripDocuments)
            ..where((l) => l.documentId.equals(documentId)))
          .go();
      for (final tripId in tripIds) {
        await into(tripDocuments).insert(
          TripDocumentRow(tripId: tripId, documentId: documentId),
        );
      }
    });
  }

  Future<List<String>> allFilePaths() async {
    final rows = await (selectOnly(documents)
          ..addColumns([documents.filePath])
          ..where(documents.filePath.isNotNull()))
        .get();
    return [for (final r in rows) r.read(documents.filePath)!];
  }

  List<DocumentWithLinks> _group(List<TypedResult> rows) {
    final order = <String>[];
    final docById = <String, DocumentRow>{};
    final linksById = <String, List<String>>{};
    for (final row in rows) {
      final doc = row.readTable(documents);
      if (!docById.containsKey(doc.id)) {
        order.add(doc.id);
        docById[doc.id] = doc;
        linksById[doc.id] = [];
      }
      final link = row.readTableOrNull(tripDocuments);
      if (link != null) linksById[doc.id]!.add(link.tripId);
    }
    return [
      for (final id in order) DocumentWithLinks(docById[id]!, linksById[id]!),
    ];
  }
}
