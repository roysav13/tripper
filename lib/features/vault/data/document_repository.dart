import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/files/file_vault_service.dart';
import '../domain/document.dart';
import 'documents_dao.dart';

/// Max pinned documents (SPEC — quick-access stays scannable).
const kMaxPinned = 4;

class PinLimitReachedException implements Exception {
  const PinLimitReachedException();
}

/// Widget tests mock at this boundary.
abstract interface class DocumentRepository {
  Stream<List<Document>> watchAll();
  Stream<List<Document>> watchForTrip(String tripId);
  Future<Document?> getById(String id);

  /// [sourceFilePath] is copied into the vault; null = manual record.
  Future<String> createDocument({
    required String title,
    required DocumentCategory category,
    String? sourceFilePath,
    String? mimeType,
    DateTime? expiryDate,
    bool isGlobal,
    Map<String, String> details,
    List<String> tripIds,
  });
  Future<void> updateDocument(Document doc);

  /// Throws [PinLimitReachedException] beyond [kMaxPinned].
  Future<void> setPinned(String id, {required bool pinned});
  Future<void> setLinks(String id, List<String> tripIds);

  /// Deletes row and vault file.
  Future<void> deleteDocument(String id);
}

class DriftDocumentRepository implements DocumentRepository {
  DriftDocumentRepository(this._dao, this._files, this._clock, this._idGen);

  final DocumentsDao _dao;
  final FileVaultService _files;
  final DateTime Function() _clock;
  final String Function() _idGen;

  @override
  Stream<List<Document>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_toDomain).toList());

  @override
  Stream<List<Document>> watchForTrip(String tripId) =>
      _dao.watchForTrip(tripId).map((rows) => rows.map(_toDomain).toList());

  @override
  Future<Document?> getById(String id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toDomain(row);
  }

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
    final id = _idGen();
    final vaultPath =
        sourceFilePath == null ? null : await _files.import(sourceFilePath);
    await _dao.insertDocument(
      DocumentRow(
        id: id,
        title: title.trim(),
        category: category.index,
        filePath: vaultPath,
        mimeType: mimeType,
        expiryDate: expiryDate,
        isGlobal: isGlobal,
        isPinned: false,
        detailsJson: jsonEncode(details),
        createdAt: _clock(),
      ),
    );
    if (tripIds.isNotEmpty) await _dao.setLinks(id, tripIds);
    return id;
  }

  @override
  Future<void> updateDocument(Document doc) async {
    final existing = await _dao.getById(doc.id);
    if (existing == null) return;
    await _dao.updateDocument(
      existing.document.copyWith(
        title: doc.title.trim(),
        category: doc.category.index,
        expiryDate: Value(doc.expiryDate),
        isGlobal: doc.isGlobal,
        detailsJson: jsonEncode(doc.details),
      ),
    );
    await _dao.setLinks(doc.id, doc.tripIds);
  }

  @override
  Future<void> setPinned(String id, {required bool pinned}) async {
    if (pinned && await _dao.countPinned() >= kMaxPinned) {
      throw const PinLimitReachedException();
    }
    await _dao.setPinned(id, pinned);
  }

  @override
  Future<void> setLinks(String id, List<String> tripIds) =>
      _dao.setLinks(id, tripIds);

  @override
  Future<void> deleteDocument(String id) async {
    final row = await _dao.getById(id);
    if (row == null) return;
    final path = row.document.filePath;
    await _dao.deleteDocument(id);
    if (path != null) await _files.delete(path);
  }

  Document _toDomain(DocumentWithLinks row) {
    final d = row.document;
    final rawDetails = jsonDecode(d.detailsJson);
    return Document(
      id: d.id,
      title: d.title,
      category: DocumentCategory.values[d.category],
      filePath: d.filePath,
      mimeType: d.mimeType,
      expiryDate: d.expiryDate,
      isGlobal: d.isGlobal,
      isPinned: d.isPinned,
      details: rawDetails is Map
          ? rawDetails.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      tripIds: row.tripIds,
    );
  }
}
