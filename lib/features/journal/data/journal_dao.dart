import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'journal_tables.dart';

part 'journal_dao.g.dart';

class JournalEntryWithPhotos {
  const JournalEntryWithPhotos(this.entry, this.photos);

  final JournalEntryRow entry;

  /// Ordered by orderIndex.
  final List<JournalPhotoRow> photos;
}

@DriftAccessor(tables: [JournalEntries, JournalPhotos])
class JournalDao extends DatabaseAccessor<AppDatabase> with _$JournalDaoMixin {
  JournalDao(super.db);

  /// Ascending by loggedAt — oldest first, so the timeline and the map
  /// polyline both read as trip progression.
  Stream<List<JournalEntryWithPhotos>> watchForTrip(String tripId) {
    final query = (select(journalEntries)
          ..where((e) => e.tripId.equals(tripId))
          ..orderBy([(e) => OrderingTerm.asc(e.loggedAt)]))
        .join([
      leftOuterJoin(
        journalPhotos,
        journalPhotos.entryId.equalsExp(journalEntries.id),
      ),
    ]);
    return query.watch().map(_group);
  }

  Future<JournalEntryWithPhotos?> getById(String id) async {
    final query = (select(journalEntries)..where((e) => e.id.equals(id))).join(
      [
        leftOuterJoin(
          journalPhotos,
          journalPhotos.entryId.equalsExp(journalEntries.id),
        ),
      ],
    );
    final grouped = _group(await query.get());
    return grouped.isEmpty ? null : grouped.single;
  }

  /// Whether any entry is already linked to [placeId] — used to make
  /// "mark place visited creates a stub entry" idempotent across
  /// visited/un-visited toggling.
  Future<bool> hasEntryForPlace(String placeId) async {
    final row = await (select(journalEntries)
          ..where((e) => e.placeId.equals(placeId))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> insertEntry(
    JournalEntryRow entry,
    List<JournalPhotoRow> photos,
  ) {
    return transaction(() async {
      await into(journalEntries).insert(entry);
      for (final p in photos) {
        await into(journalPhotos).insert(p);
      }
    });
  }

  /// Replace-all-photos semantics, same as TripsDao.updateTrip/destinations.
  Future<void> updateEntry(
    JournalEntryRow entry,
    List<JournalPhotoRow> photos,
  ) {
    return transaction(() async {
      await update(journalEntries).replace(entry);
      await (delete(journalPhotos)..where((p) => p.entryId.equals(entry.id)))
          .go();
      for (final p in photos) {
        await into(journalPhotos).insert(p);
      }
    });
  }

  Future<void> deleteEntry(String id) {
    // Photos cascade via FK.
    return (delete(journalEntries)..where((e) => e.id.equals(id))).go();
  }

  List<JournalEntryWithPhotos> _group(List<TypedResult> rows) {
    final order = <String>[];
    final entryById = <String, JournalEntryRow>{};
    final photosById = <String, List<JournalPhotoRow>>{};
    for (final row in rows) {
      final entry = row.readTable(journalEntries);
      if (!entryById.containsKey(entry.id)) {
        order.add(entry.id);
        entryById[entry.id] = entry;
        photosById[entry.id] = [];
      }
      final photo = row.readTableOrNull(journalPhotos);
      if (photo != null) photosById[entry.id]!.add(photo);
    }
    return [
      for (final id in order)
        JournalEntryWithPhotos(
          entryById[id]!,
          photosById[id]!..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
        ),
    ];
  }
}
