import 'dart:async';

import 'package:tripper/features/journal/data/journal_repository.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/domain/journal_photo.dart';

/// Fake at the repository boundary (testing rules — no DB in widget tests).
class FakeJournalRepository implements JournalRepository {
  FakeJournalRepository(this._entries);

  final List<JournalEntry> _entries;
  final _controller = StreamController<List<JournalEntry>>.broadcast();

  void emit(List<JournalEntry> entries) {
    _entries
      ..clear()
      ..addAll(entries);
    _controller.add(List.of(entries));
  }

  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<JournalEntry>> watchForTrip(String tripId) async* {
    yield [
      for (final e in _entries)
        if (e.tripId == tripId) e,
    ];
    yield* _controller.stream.map(
      (entries) => [
        for (final e in entries)
          if (e.tripId == tripId) e,
      ],
    );
  }

  @override
  Future<JournalEntry?> getById(String id) async =>
      _entries.where((e) => e.id == id).firstOrNull;

  @override
  Future<String> createEntry({
    required String tripId,
    required String summary,
    DateTime? loggedAt,
    double? lat,
    double? lng,
    String? placeName,
    String? placeId,
    List<String> photoSourcePaths = const [],
  }) async {
    final id = 'fake-${_entries.length}';
    final now = loggedAt ?? DateTime(2026);
    final entry = JournalEntry(
      id: id,
      tripId: tripId,
      summary: summary,
      loggedAt: now,
      createdAt: now,
      lat: lat,
      lng: lng,
      placeName: placeName,
      placeId: placeId,
      photos: [
        for (final path in photoSourcePaths)
          JournalPhoto(id: 'fake-photo-$path', filePath: path),
      ],
    );
    emit([..._entries, entry]);
    return id;
  }

  @override
  Future<void> updateEntry(
    JournalEntry entry, {
    List<String> newPhotoSourcePaths = const [],
    List<String> removedPhotoIds = const [],
  }) async {
    final keptPhotos =
        entry.photos.where((p) => !removedPhotoIds.contains(p.id)).toList();
    final updated = entry.copyWith(
      photos: [
        ...keptPhotos,
        for (final path in newPhotoSourcePaths)
          JournalPhoto(id: 'fake-photo-$path', filePath: path),
      ],
    );
    emit([
      for (final e in _entries)
        if (e.id == entry.id) updated else e,
    ]);
  }

  @override
  Future<void> deleteEntry(String id) async {
    emit([..._entries.where((e) => e.id != id)]);
  }

  @override
  Future<bool> hasEntryForPlace(String placeId) async =>
      _entries.any((e) => e.placeId == placeId);
}
