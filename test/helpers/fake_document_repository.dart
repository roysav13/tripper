import 'dart:async';

import 'package:tripper/features/vault/data/document_repository.dart';
import 'package:tripper/features/vault/domain/document.dart';

/// Fake at the repository boundary (testing rules — no DB in widget tests).
class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository(this._docs, {DateTime? clock})
      : _clock = clock ?? DateTime(2026, 7, 19);

  final List<Document> _docs;
  final DateTime _clock;
  final _controller = StreamController<List<Document>>.broadcast();

  void emit(List<Document> docs) {
    _docs
      ..clear()
      ..addAll(docs);
    _controller.add(List.of(docs));
  }

  /// M4.2 states audit — simulates a stream failure for error-state tests.
  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<Document>> watchAll() async* {
    yield List.of(_docs);
    yield* _controller.stream;
  }

  @override
  Stream<List<Document>> watchForTrip(String tripId) async* {
    yield [
      for (final d in _docs)
        if (d.tripIds.contains(tripId)) d,
    ];
  }

  @override
  Future<Document?> getById(String id) async =>
      _docs.where((d) => d.id == id).firstOrNull;

  @override
  Future<String> createDocument({
    required String title,
    required DocumentCategory category,
    String? sourceFilePath,
    String? mimeType,
    DateTime? expiryDate,
    bool isGlobal = false,
    Map<String, String> details = const {},
    List<String> tripIds = const [],
  }) async {
    final doc = Document(
      id: 'fake-${_docs.length}',
      title: title,
      category: category,
      createdAt: _clock,
      filePath: sourceFilePath,
      mimeType: mimeType,
      expiryDate: expiryDate,
      isGlobal: isGlobal,
      details: details,
      tripIds: tripIds,
    );
    emit([..._docs, doc]);
    return doc.id;
  }

  @override
  Future<void> updateDocument(Document doc) async {
    emit([
      for (final d in _docs)
        if (d.id == doc.id) doc else d,
    ]);
  }

  @override
  Future<void> setPinned(String id, {required bool pinned}) async {
    emit([
      for (final d in _docs)
        if (d.id == id) d.copyWith(isPinned: pinned) else d,
    ]);
  }

  @override
  Future<void> setLinks(String id, List<String> tripIds) async {
    emit([
      for (final d in _docs)
        if (d.id == id) d.copyWith(tripIds: tripIds) else d,
    ]);
  }

  @override
  Future<void> deleteDocument(String id) async {
    emit([..._docs.where((d) => d.id != id)]);
  }
}
