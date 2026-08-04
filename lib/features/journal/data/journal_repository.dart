import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/files/file_vault_service.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_photo.dart';
import 'journal_dao.dart';

/// Widget tests mock at this boundary.
abstract interface class JournalRepository {
  Stream<List<JournalEntry>> watchForTrip(String tripId);
  Future<JournalEntry?> getById(String id);

  /// [photoSourcePaths] are copied into the vault; loggedAt defaults to
  /// clock() when null — never DateTime.now().
  Future<String> createEntry({
    required String tripId,
    required String summary,
    DateTime? loggedAt,
    double? lat,
    double? lng,
    String? placeName,
    List<String> photoSourcePaths = const [],
  });

  /// [newPhotoSourcePaths] are copied into the vault and appended;
  /// [removedPhotoIds] are dropped and their vault files deleted.
  Future<void> updateEntry(
    JournalEntry entry, {
    List<String> newPhotoSourcePaths = const [],
    List<String> removedPhotoIds = const [],
  });

  /// Deletes the entry row (photos cascade) and their vault files.
  Future<void> deleteEntry(String id);
}

class DriftJournalRepository implements JournalRepository {
  DriftJournalRepository(this._dao, this._files, this._clock, this._idGen);

  final JournalDao _dao;
  final FileVaultService _files;
  final DateTime Function() _clock;
  final String Function() _idGen;

  @override
  Stream<List<JournalEntry>> watchForTrip(String tripId) =>
      _dao.watchForTrip(tripId).map((rows) => rows.map(_toDomain).toList());

  @override
  Future<JournalEntry?> getById(String id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<String> createEntry({
    required String tripId,
    required String summary,
    DateTime? loggedAt,
    double? lat,
    double? lng,
    String? placeName,
    List<String> photoSourcePaths = const [],
  }) async {
    final id = _idGen();
    final photos = await _importPhotos(
      photoSourcePaths,
      entryId: id,
      startIndex: 0,
    );
    await _dao.insertEntry(
      JournalEntryRow(
        id: id,
        tripId: tripId,
        summary: summary.trim(),
        loggedAt: loggedAt ?? _clock(),
        lat: lat,
        lng: lng,
        placeName: placeName,
        createdAt: _clock(),
      ),
      photos,
    );
    return id;
  }

  @override
  Future<void> updateEntry(
    JournalEntry entry, {
    List<String> newPhotoSourcePaths = const [],
    List<String> removedPhotoIds = const [],
  }) async {
    final existing = await _dao.getById(entry.id);
    if (existing == null) return;

    final kept =
        existing.photos.where((p) => !removedPhotoIds.contains(p.id)).toList();
    final imported = await _importPhotos(
      newPhotoSourcePaths,
      entryId: entry.id,
      startIndex: kept.length,
    );

    await _dao.updateEntry(
      existing.entry.copyWith(
        summary: entry.summary.trim(),
        loggedAt: entry.loggedAt,
        lat: Value(entry.lat),
        lng: Value(entry.lng),
        placeName: Value(entry.placeName),
      ),
      [...kept, ...imported],
    );

    for (final photo in existing.photos) {
      if (removedPhotoIds.contains(photo.id)) {
        await _files.delete(photo.filePath);
      }
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    final existing = await _dao.getById(id);
    if (existing == null) return;
    await _dao.deleteEntry(id);
    for (final photo in existing.photos) {
      await _files.delete(photo.filePath);
    }
  }

  Future<List<JournalPhotoRow>> _importPhotos(
    List<String> sourcePaths, {
    required String entryId,
    required int startIndex,
  }) async {
    final rows = <JournalPhotoRow>[];
    for (var i = 0; i < sourcePaths.length; i++) {
      final vaultPath = await _files.import(sourcePaths[i]);
      rows.add(
        JournalPhotoRow(
          id: _idGen(),
          entryId: entryId,
          filePath: vaultPath,
          orderIndex: startIndex + i,
        ),
      );
    }
    return rows;
  }

  JournalEntry _toDomain(JournalEntryWithPhotos row) => JournalEntry(
        id: row.entry.id,
        tripId: row.entry.tripId,
        summary: row.entry.summary,
        loggedAt: row.entry.loggedAt,
        createdAt: row.entry.createdAt,
        lat: row.entry.lat,
        lng: row.entry.lng,
        placeName: row.entry.placeName,
        photos: [
          for (final p in row.photos)
            JournalPhoto(id: p.id, filePath: p.filePath),
        ],
      );
}
