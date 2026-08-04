# Journal Globe/Gallery + Place↔Entry Correlation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Journal globe plot entries (not Places) with small non-colliding dots, photo thumbnails, a chronological journey line, and drag-only rotation that opens on the latest entry; correlate Places and journal entries bidirectionally; and replace the flat gallery strip with a day-grouped horizontal timeline.

**Architecture:** A nullable `placeId` FK links `journal_entries` to `places`. A small orchestration layer (`place_visit_actions.dart`) keeps "place marked visited" and "entry created" in sync in both directions without recursion. The globe (`journal_globe.dart`) switches its data source from `Place` to `JournalEntry` and gains photo-thumbnail points and arced journey-line connections, using pure/testable helper functions for the logic that doesn't need the GPU surface. The gallery becomes a new `JournalGalleryTimeline` widget that groups entries by calendar day.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), `flutter_earth_globe` (v2.2.1), `google_maps_flutter` (unaffected by this plan), `intl`.

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`. Reuse `context.colors` throughout.
- No `DateTime.now()` in domain/repository code — always `clockProvider`.
- Every user-facing string goes through `lib/l10n/app_en.arb`, and both generated-by-hand files (`app_localizations.dart`, `app_localizations_en.dart`) must be updated in the same commit — this repo cannot run `flutter gen-l10n` here (see below), so those two files are edited directly, mirroring the exact style of existing entries.
- Every Drift schema bump ships a migration test in the same commit (`test/unit/journal/journal_migration_test.dart` here).
- Widget tests mock at the repository boundary (`FakeJournalRepository`, `FakePlaceRepository` in `test/helpers/`) — never a real `AppDatabase` in a widget test.
- **This environment cannot run Flutter/Dart tooling** (network-blocked SDK download, per `CLAUDE.md`). That means:
  - Any step that changes a Drift `Table` class requires regenerating `*.g.dart` via `dart run build_runner build --delete-conflicting-outputs` **on the developer's machine**, committed alongside the table change. Task 1 calls this out explicitly; don't skip it.
  - Every "run the test" step in this plan is something the executor runs locally (or CI runs), per `CLAUDE.md`'s Verification section — never claim a step passed without that external run actually happening.
- `flutter_earth_globe`'s `Point`/`PointStyle` has no image support; the photo-thumbnail-as-dot technique in Task 6 relies on `Point.labelBuilder` + `isLabelVisible` + `labelOffset`, positioned via the package's own `Positioned` math (`left = pos.dx - labelOffset.dx - width/2`, `top = pos.dy - labelOffset.dy - height`) — confirmed by reading `rotating_globe.dart` in the installed package (v2.2.1) directly.

---

### Task 1: Schema — `journal_entries.placeId`

**Files:**
- Modify: `lib/features/journal/data/journal_tables.dart`
- Modify: `lib/core/database/app_database.dart`
- Regenerate (developer machine): `lib/features/journal/data/journal_dao.g.dart`, `lib/core/database/app_database.g.dart`
- Modify: `test/unit/journal/journal_migration_test.dart`

**Interfaces:**
- Produces: `JournalEntries.placeId` (nullable `TextColumn`, FK → `Places.id`, `onDelete: KeyAction.setNull`); `JournalEntryRow.placeId` (`String?`, generated).

- [ ] **Step 1: Add the column to the table definition**

`lib/features/journal/data/journal_tables.dart` — add the import and the column:

```dart
import 'package:drift/drift.dart';

import '../../places/data/place_tables.dart';
import '../../trips/data/trip_tables.dart';

@DataClassName('JournalEntryRow')
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get summary => text().withLength(min: 1, max: 4000)();

  /// User-editable log time — never `DateTime.now()`, defaults to
  /// `clockProvider` at creation (domain rule).
  DateTimeColumn get loggedAt => dateTime()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  TextColumn get placeName => text().nullable()();

  /// Links this entry to the Place it corresponds to, if any — set when
  /// the entry's location was picked from (or created as) one of the
  /// trip's Places, or when the entry was auto-created because a Place
  /// was marked visited from the Places tab. SET NULL, not cascade:
  /// deleting the place must never delete the entry (entries are user
  /// content — text, photos — only ever removed by explicit user action).
  TextColumn get placeId =>
      text().nullable().references(Places, #id, onDelete: KeyAction.setNull)();

  /// Immutable audit stamp — never shown or edited.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('JournalPhotoRow')
class JournalPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get entryId =>
      text().references(JournalEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

- [ ] **Step 2: Bump schema version and wire the migration**

`lib/core/database/app_database.dart` — update the schema history comment, bump `schemaVersion` to `11`, and change the v10 block from a bare `if` to an `if`/`else if` chain (the file's own comment explains why: `createTable` always builds the CURRENT shape, so a later `addColumn` on the same table must be mutually exclusive with the create step, not a second top-level `if`):

```dart
/// Schema history:
///   v1 — empty scaffold (M0)
///   v2 — Trips + TripDestinations (M1)
///   v3 — trip dates nullable: planned + open-ended trips (M1 polish)
///   v4 — Documents + TripDocuments (M2)
///   v5 — Places (M3)
///   v6 — Trips.completionPromptShown (M3c)
///   v7 — Expenses (M5.5)
///   v8 — Expenses conversion columns (M5.5b)
///   v9 — ItineraryItems (M5.7, feature since withdrawn — see below)
///   v10 — JournalEntries + JournalPhotos (Journal feature)
///   v11 — JournalEntries.placeId (Place<->JournalEntry correlation)
```

```dart
  @override
  int get schemaVersion => 11;
```

```dart
          if (from < 10) {
            await m.createTable(journalEntries);
            await m.createTable(journalPhotos);
          } else if (from < 11) {
            await m.addColumn(journalEntries, journalEntries.placeId);
          }
```

- [ ] **Step 3: Regenerate Drift code (developer machine, not this sandbox)**

Run locally:
```bash
dart run build_runner build --delete-conflicting-outputs
```
Commit the regenerated `lib/features/journal/data/journal_dao.g.dart` and `lib/core/database/app_database.g.dart` alongside the table/schema changes above. Nothing in later tasks compiles until this has run — `JournalEntryRow.placeId` and the bumped schema come from here.

- [ ] **Step 4: Write the migration tests**

Replace the existing "v1 -> v10 in one jump" test and add new ones. Full updated `test/unit/journal/journal_migration_test.dart`:

```dart
import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// Schema-bump rule (testing conventions): every schema bump ships a
/// migration test in the same commit. v10 added JournalEntries +
/// JournalPhotos (Journal feature). v11 added JournalEntries.placeId
/// (Place<->JournalEntry correlation). Mirrors expenses_migration_test.dart.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const insertTrip = 'INSERT INTO trips (id, name, color_tag, archived, '
      'completion_prompt_shown, created_at) '
      "VALUES ('t1', 'Thailand', 0, 0, 0, 0)";

  /// The v10 journal_entries shape — before place_id existed.
  const createV10JournalEntries = '''
CREATE TABLE journal_entries (
  id TEXT NOT NULL PRIMARY KEY,
  trip_id TEXT NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
  summary TEXT NOT NULL,
  logged_at INTEGER NOT NULL,
  lat REAL,
  lng REAL,
  place_name TEXT,
  created_at INTEGER NOT NULL
)''';

  test(
      'v9 -> v10 creates journal_entries and journal_photos, preserves '
      'existing trips', () async {
    // A v9 install: neither journal table exists yet (child first — FK).
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement(insertTrip);

    await db.migration.onUpgrade(Migrator(db), 9, 10);

    await db.customSelect('SELECT COUNT(*) FROM journal_entries').getSingle();
    await db.customSelect('SELECT COUNT(*) FROM journal_photos').getSingle();
    final trips = await db.customSelect('SELECT name FROM trips').get();
    expect(trips.single.read<String>('name'), 'Thailand');
  });

  test(
      'v10 -> v11 adds place_id to an existing table, null (unlinked), '
      'keeping existing entries', () async {
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement(createV10JournalEntries);
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO journal_entries (id, trip_id, summary, logged_at, '
      'created_at) '
      "VALUES ('j1', 't1', 'Arrived', 0, 0)",
    );

    await db.migration.onUpgrade(Migrator(db), 10, 11);

    final rows = await db
        .customSelect('SELECT summary, place_id FROM journal_entries')
        .get();
    expect(rows.single.read<String>('summary'), 'Arrived');
    expect(rows.single.read<String?>('place_id'), isNull);
  });

  test(
      'v9 -> v11 in one jump does NOT try to add place_id to a table it '
      'just created (regression: crashed with "duplicate column name" for '
      'anyone skipping a version)', () async {
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement(insertTrip);

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 9, 11),
      completes,
    );
    // The freshly created table already has the v11 shape.
    await db.customSelect('SELECT place_id FROM journal_entries').get();
  });

  test('v1 -> v11 in one jump survives', () async {
    await db.customStatement('DROP TABLE journal_photos');
    await db.customStatement('DROP TABLE journal_entries');
    await db.customStatement('DROP TABLE itinerary_items');
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement('DROP TABLE trip_destinations');
    await db.customStatement('DROP TABLE trips');

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 1, 11),
      completes,
    );
    await db.customSelect('SELECT COUNT(*) FROM journal_entries').getSingle();
    await db.customSelect('SELECT place_id FROM journal_entries').get();
    await db.customSelect('SELECT completion_prompt_shown FROM trips').get();
  });

  test('journal_entries cascades when its trip is deleted', () async {
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);

    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO journal_entries (id, trip_id, summary, logged_at, '
      'created_at) '
      "VALUES ('j1', 't1', 'Arrived', 0, 0)",
    );

    await db.customStatement("DELETE FROM trips WHERE id = 't1'");

    final remaining = await db
        .customSelect('SELECT COUNT(*) AS c FROM journal_entries')
        .getSingle();
    expect(remaining.read<int>('c'), 0);
  });

  test('journal_photos cascades when its entry is deleted', () async {
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO journal_entries (id, trip_id, summary, logged_at, '
      'created_at) '
      "VALUES ('j1', 't1', 'Arrived', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO journal_photos (id, entry_id, file_path, order_index) '
      "VALUES ('p1', 'j1', '/tmp/a.jpg', 0)",
    );

    await db.customStatement("DELETE FROM journal_entries WHERE id = 'j1'");

    final remaining = await db
        .customSelect('SELECT COUNT(*) AS c FROM journal_photos')
        .getSingle();
    expect(remaining.read<int>('c'), 0);
  });

  test(
      'deleting a place unlinks (not deletes) its journal entry '
      '(place_id SET NULL)', () async {
    await db.customStatement(insertTrip);
    await db.customStatement(
      "INSERT INTO places (id, name, status, trip_id, created_at) "
      "VALUES ('p1', 'Krabi', 1, 't1', 0)",
    );
    await db.customStatement(
      'INSERT INTO journal_entries (id, trip_id, summary, logged_at, '
      'place_id, created_at) '
      "VALUES ('j1', 't1', 'Arrived', 0, 'p1', 0)",
    );

    await db.customStatement("DELETE FROM places WHERE id = 'p1'");

    final row = await db
        .customSelect(
          "SELECT place_id FROM journal_entries WHERE id = 'j1'",
        )
        .getSingle();
    expect(row.data['place_id'], isNull);
    final remaining = await db
        .customSelect('SELECT COUNT(*) AS c FROM journal_entries')
        .getSingle();
    expect(remaining.read<int>('c'), 1);
  });
}
```

- [ ] **Step 5: Run and commit**

Run (locally): `flutter test test/unit/journal/journal_migration_test.dart`
Expected: all tests PASS (requires Step 3's regeneration to have happened first).

```bash
git add lib/features/journal/data/journal_tables.dart \
  lib/features/journal/data/journal_dao.g.dart \
  lib/core/database/app_database.dart \
  lib/core/database/app_database.g.dart \
  test/unit/journal/journal_migration_test.dart
git commit -m "feat(journal): add placeId link to journal_entries (schema v11)"
```

---

### Task 2: Domain + repository — `placeId` plumbing, `hasEntryForPlace`

**Files:**
- Modify: `lib/features/journal/domain/journal_entry.dart`
- Modify: `lib/features/journal/data/journal_dao.dart`
- Modify: `lib/features/journal/data/journal_repository.dart`
- Modify: `test/helpers/fake_journal_repository.dart`
- Test: `test/unit/journal/journal_repository_test.dart`

**Interfaces:**
- Consumes: `JournalEntryRow.placeId` (`String?`, from Task 1).
- Produces: `JournalEntry.placeId` (`String?`); `JournalRepository.createEntry({..., String? placeId})`; `JournalRepository.hasEntryForPlace(String placeId) -> Future<bool>`; `JournalEntry.copyWith({..., String? Function()? placeId})`.

- [ ] **Step 1: Add `placeId` to the domain model**

`lib/features/journal/domain/journal_entry.dart` — full updated file:

```dart
import 'package:flutter/foundation.dart';

import 'journal_photo.dart';

@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.tripId,
    required this.summary,
    required this.loggedAt,
    required this.createdAt,
    this.lat,
    this.lng,
    this.placeName,
    this.placeId,
    this.photos = const [],
  });

  final String id;
  final String tripId;
  final String summary;

  /// User-editable log time — distinct from [createdAt].
  final DateTime loggedAt;

  /// Immutable audit stamp — never shown or edited.
  final DateTime createdAt;

  final double? lat;
  final double? lng;
  final String? placeName;

  /// The Place this entry corresponds to, if any (Place<->JournalEntry
  /// correlation) — set when the entry's location was picked from an
  /// existing Place, or when this entry was auto-created because a Place
  /// was marked visited.
  final String? placeId;

  final List<JournalPhoto> photos;

  bool get hasLocation => lat != null && lng != null;
  bool get hasPhotos => photos.isNotEmpty;

  JournalEntry copyWith({
    String? summary,
    DateTime? loggedAt,
    double? Function()? lat,
    double? Function()? lng,
    String? Function()? placeName,
    String? Function()? placeId,
    List<JournalPhoto>? photos,
  }) {
    return JournalEntry(
      id: id,
      tripId: tripId,
      summary: summary ?? this.summary,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt,
      lat: lat == null ? this.lat : lat(),
      lng: lng == null ? this.lng : lng(),
      placeName: placeName == null ? this.placeName : placeName(),
      placeId: placeId == null ? this.placeId : placeId(),
      photos: photos ?? this.photos,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is JournalEntry &&
      other.id == id &&
      other.tripId == tripId &&
      other.summary == summary &&
      other.loggedAt == loggedAt &&
      other.createdAt == createdAt &&
      other.lat == lat &&
      other.lng == lng &&
      other.placeName == placeName &&
      other.placeId == placeId &&
      listEquals(other.photos, photos);

  @override
  int get hashCode => Object.hash(
        id,
        tripId,
        summary,
        loggedAt,
        createdAt,
        lat,
        lng,
        placeName,
        placeId,
        Object.hashAll(photos),
      );
}
```

- [ ] **Step 2: Add `hasEntryForPlace` to the DAO**

`lib/features/journal/data/journal_dao.dart` — add this method inside `JournalDao` (after `getById`):

```dart
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
```

- [ ] **Step 3: Thread `placeId` through the repository**

`lib/features/journal/data/journal_repository.dart` — full updated file:

```dart
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
  /// clock() when null — never DateTime.now(). [placeId] links this entry
  /// to a Place (Place<->JournalEntry correlation).
  Future<String> createEntry({
    required String tripId,
    required String summary,
    DateTime? loggedAt,
    double? lat,
    double? lng,
    String? placeName,
    String? placeId,
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

  /// Whether any entry is already linked to [placeId].
  Future<bool> hasEntryForPlace(String placeId);
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
    String? placeId,
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
        placeId: placeId,
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
        placeId: Value(entry.placeId),
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

  @override
  Future<bool> hasEntryForPlace(String placeId) =>
      _dao.hasEntryForPlace(placeId);

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
        placeId: row.entry.placeId,
        photos: [
          for (final p in row.photos)
            JournalPhoto(id: p.id, filePath: p.filePath),
        ],
      );
}
```

- [ ] **Step 4: Update the test fake**

`test/helpers/fake_journal_repository.dart` — full updated file:

```dart
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
```

- [ ] **Step 5: Add repository tests**

`test/unit/journal/journal_repository_test.dart` — add these two tests (anywhere after the existing "location and place name roundtrip" test, before the closing `}` of `main()`):

```dart
  test('placeId roundtrips through create and read', () async {
    final tripId = await createTrip();
    final id = await repo.createEntry(
      tripId: tripId,
      summary: 'Linked to a place',
      placeId: 'place-1',
    );
    final entry = await repo.getById(id);
    expect(entry!.placeId, 'place-1');
  });

  test('hasEntryForPlace is true only once an entry links that place',
      () async {
    final tripId = await createTrip();
    expect(await repo.hasEntryForPlace('place-1'), isFalse);

    await repo.createEntry(
      tripId: tripId,
      summary: 'Linked to a place',
      placeId: 'place-1',
    );

    expect(await repo.hasEntryForPlace('place-1'), isTrue);
    expect(await repo.hasEntryForPlace('place-2'), isFalse);
  });
```

- [ ] **Step 6: Run and commit**

Run (locally): `flutter test test/unit/journal/journal_repository_test.dart`
Expected: PASS.

```bash
git add lib/features/journal/domain/journal_entry.dart \
  lib/features/journal/data/journal_dao.dart \
  lib/features/journal/data/journal_repository.dart \
  test/helpers/fake_journal_repository.dart \
  test/unit/journal/journal_repository_test.dart
git commit -m "feat(journal): thread placeId through JournalEntry and JournalRepository"
```

---

### Task 3: Place → Entry correlation (`markPlaceVisited` / `markPlacesVisited`)

**Files:**
- Create: `lib/features/places/presentation/place_visit_actions.dart`
- Modify: `lib/features/places/presentation/trip_places_tab.dart`
- Modify: `lib/features/places/presentation/places_screen.dart`
- Modify: `lib/features/places/presentation/place_actions_sheet.dart`
- Modify: `lib/features/trips/presentation/trip_list_screen.dart`
- Test: `test/widget/places/place_visit_actions_test.dart`

**Interfaces:**
- Consumes: `PlaceRepository.setVisited`, `PlaceRepository.bulkMarkVisited` (existing); `JournalRepository.createEntry`, `JournalRepository.hasEntryForPlace` (Task 2); `clockProvider` (`lib/core/database/database_provider.dart`); `placeRepositoryProvider` (`lib/features/places/presentation/place_providers.dart`); `journalRepositoryProvider` (`lib/features/journal/presentation/journal_providers.dart`).
- Produces: `Future<void> markPlaceVisited(WidgetRef ref, Place place, {required bool visited})`; `Future<void> markPlacesVisited(WidgetRef ref, List<Place> places, DateTime visitedOn)`.

- [ ] **Step 1: Write the orchestrator**

Create `lib/features/places/presentation/place_visit_actions.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../journal/presentation/journal_providers.dart';
import '../domain/place.dart';
import 'place_providers.dart';

/// Marks [place] visited/un-visited, and — only when marking visited —
/// ensures it has a linked journal entry (Place<->JournalEntry
/// correlation: an entry IS a visited place). Un-visiting never touches
/// an existing linked entry (entries are user content, never
/// auto-deleted). Idempotent: toggling visited on/off/on never creates a
/// second stub entry, via [JournalRepository.hasEntryForPlace].
///
/// A place with no [Place.tripId] can't get a trip-scoped entry — the
/// visited flag still updates, stub creation is silently skipped.
Future<void> markPlaceVisited(
  WidgetRef ref,
  Place place, {
  required bool visited,
}) async {
  final placeRepo = ref.read(placeRepositoryProvider);
  final clock = ref.read(clockProvider);
  final visitedOn = visited ? clock() : null;
  await placeRepo.setVisited(place.id, visited: visited, visitedOn: visitedOn);
  if (!visited || place.tripId == null) return;

  final journalRepo = ref.read(journalRepositoryProvider);
  if (await journalRepo.hasEntryForPlace(place.id)) return;
  await journalRepo.createEntry(
    tripId: place.tripId!,
    summary: '',
    loggedAt: visitedOn,
    lat: place.lat,
    lng: place.lng,
    placeName: place.name,
    placeId: place.id,
  );
}

/// Bulk form of [markPlaceVisited] — used by the trip-completion prompt,
/// which marks several wishlist places visited at once. Same
/// idempotency and no-tripId-skip rules apply per place.
Future<void> markPlacesVisited(
  WidgetRef ref,
  List<Place> places,
  DateTime visitedOn,
) async {
  final placeRepo = ref.read(placeRepositoryProvider);
  await placeRepo.bulkMarkVisited([for (final p in places) p.id], visitedOn);

  final journalRepo = ref.read(journalRepositoryProvider);
  for (final place in places) {
    if (place.tripId == null) continue;
    if (await journalRepo.hasEntryForPlace(place.id)) continue;
    await journalRepo.createEntry(
      tripId: place.tripId!,
      summary: '',
      loggedAt: visitedOn,
      lat: place.lat,
      lng: place.lng,
      placeName: place.name,
      placeId: place.id,
    );
  }
}
```

- [ ] **Step 2: Wire the three single-place call sites**

`lib/features/places/presentation/trip_places_tab.dart` — replace the `onToggleVisited` callback:

```dart
              onToggleVisited: () =>
                  markPlaceVisited(ref, place, visited: !place.isVisited),
```

Add the import: `import 'place_visit_actions.dart';`

`lib/features/places/presentation/places_screen.dart` — find the `setVisited` call (around line 166) and replace:

```dart
            HapticFeedback.selectionClick();
            markPlaceVisited(ref, place, visited: !place.isVisited);
          },
```

Add the import: `import 'place_visit_actions.dart';` (adjust relative path if `places_screen.dart` lives one level differently than `trip_places_tab.dart` — both are in `lib/features/places/presentation/`, so the same relative import applies).

`lib/features/places/presentation/place_actions_sheet.dart` — replace the toggle-visited `ListTile.onTap`:

```dart
              onTap: () async {
                Navigator.of(context).pop();
                await markPlaceVisited(ref, place, visited: !place.isVisited);
              },
```

Add the import: `import 'place_visit_actions.dart';`

- [ ] **Step 3: Wire the bulk call site (trip-completion prompt)**

`lib/features/trips/presentation/trip_list_screen.dart` — the completion-prompt handler builds `wishlist` and a `selected` id set (see `_maybeShowCompletionPrompt`, around lines 182–194 and 244–248). Replace the final block:

```dart
      if ((confirmed ?? false) && selected.isNotEmpty) {
        await markPlacesVisited(
          ref,
          wishlist.where((p) => selected.contains(p.id)).toList(),
          candidate.endDate!,
        );
      }
```

Add the import: `import '../../places/presentation/place_visit_actions.dart';` (adjust the relative path to match this file's existing imports of `../../places/...`).

- [ ] **Step 4: Write the orchestrator tests**

`markPlaceVisited`/`markPlacesVisited` take a `WidgetRef`, which (like every other `ref`-consuming function in this codebase) can only be obtained from a real widget tree — so this is a widget test that captures `ref` via a `Consumer`, then drives the functions directly and asserts on the fake repositories, rather than tapping any UI (there is none to tap here; the UI wiring is Step 2/3, already covered by not regressing the existing call-site widget tests).

Create `test/widget/places/place_visit_actions_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/features/journal/presentation/journal_providers.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/places/presentation/place_visit_actions.dart';

import '../../helpers/fake_journal_repository.dart';
import '../../helpers/fake_place_repository.dart';

const _place = Place(
  id: 'p1',
  name: 'Railay Beach',
  lat: 8.0119,
  lng: 98.8378,
  tripId: 'trip-1',
);

const _tripless = Place(id: 'p2', name: 'No trip', lat: 1, lng: 1);

/// Captures the tree's WidgetRef into [onRef] so tests can call the
/// ref-consuming functions under test directly, without any UI to tap.
Widget _wrap({
  required FakePlaceRepository places,
  required FakeJournalRepository journal,
  required void Function(WidgetRef ref) onRef,
}) =>
    ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(places),
        journalRepositoryProvider.overrideWithValue(journal),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            onRef(ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

void main() {
  late FakePlaceRepository places;
  late FakeJournalRepository journal;
  late WidgetRef ref;

  setUp(() {
    places = FakePlaceRepository([_place, _tripless]);
    journal = FakeJournalRepository([]);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(places: places, journal: journal, onRef: (r) => ref = r),
    );
    await tester.pump();
  }

  testWidgets('marking visited creates one linked stub entry', (tester) async {
    await pump(tester);
    await markPlaceVisited(ref, _place, visited: true);

    final all = await places.watchAll().first;
    expect(all.firstWhere((p) => p.id == 'p1').isVisited, isTrue);

    final entries = await journal.watchForTrip('trip-1').first;
    expect(entries, hasLength(1));
    expect(entries.single.placeId, 'p1');
    expect(entries.single.summary, isEmpty);
    expect(entries.single.placeName, 'Railay Beach');
    expect(entries.single.loggedAt, DateTime(2026, 7, 19));
  });

  testWidgets('toggling visited off then on again does not duplicate the entry',
      (tester) async {
    await pump(tester);
    await markPlaceVisited(ref, _place, visited: true);
    await markPlaceVisited(ref, _place, visited: false);
    await markPlaceVisited(ref, _place, visited: true);

    final entries = await journal.watchForTrip('trip-1').first;
    expect(entries, hasLength(1));
  });

  testWidgets('un-visiting never deletes the linked entry', (tester) async {
    await pump(tester);
    await markPlaceVisited(ref, _place, visited: true);
    await markPlaceVisited(ref, _place, visited: false);

    final all = await places.watchAll().first;
    expect(all.firstWhere((p) => p.id == 'p1').isVisited, isFalse);
    final entries = await journal.watchForTrip('trip-1').first;
    expect(entries, hasLength(1));
  });

  testWidgets('a place with no tripId is marked visited but gets no stub entry',
      (tester) async {
    await pump(tester);
    await markPlaceVisited(ref, _tripless, visited: true);

    final all = await places.watchAll().first;
    expect(all.firstWhere((p) => p.id == 'p2').isVisited, isTrue);
    expect(await journal.hasEntryForPlace('p2'), isFalse);
  });

  testWidgets('markPlacesVisited creates one stub entry per place, once each',
      (tester) async {
    await pump(tester);
    const third = Place(id: 'p3', name: 'Ao Nang', lat: 2, lng: 2, tripId: 'trip-1');
    places.emit([_place, _tripless, third]);

    await markPlacesVisited(ref, [_place, third], DateTime(2026, 8, 1));

    final entries = await journal.watchForTrip('trip-1').first;
    expect(entries, hasLength(2));
    expect(entries.map((e) => e.placeId), containsAll(['p1', 'p3']));
    // Re-running with an already-linked place doesn't duplicate.
    await markPlacesVisited(ref, [_place], DateTime(2026, 8, 2));
    final after = await journal.watchForTrip('trip-1').first;
    expect(after, hasLength(2));
  });
}
```

- [ ] **Step 5: Run and commit**

Run (locally): `flutter analyze && flutter test test/widget/places/place_visit_actions_test.dart`
Expected: PASS.

```bash
git add lib/features/places/presentation/place_visit_actions.dart \
  lib/features/places/presentation/trip_places_tab.dart \
  lib/features/places/presentation/places_screen.dart \
  lib/features/places/presentation/place_actions_sheet.dart \
  lib/features/trips/presentation/trip_list_screen.dart \
  test/widget/places/place_visit_actions_test.dart
git commit -m "feat(places): marking a place visited creates a linked journal entry"
```

---

### Task 4: Entry → Place correlation (location picker)

**Files:**
- Modify: `lib/features/journal/presentation/journal_location_picker.dart`
- Modify: `lib/features/journal/presentation/journal_entry_form_sheet.dart`
- Modify: `test/widget/journal/journal_location_picker_test.dart`

**Interfaces:**
- Consumes: `JournalRepository.createEntry({..., String? placeId})` (Task 2).
- Produces: `JournalLocationPick.placeId` (`String?`).

- [ ] **Step 1: Add `placeId` to the pick result and close the "existing unvisited place" gap**

`lib/features/journal/presentation/journal_location_picker.dart` — update `JournalLocationPick`:

```dart
class JournalLocationPick {
  const JournalLocationPick({
    required this.lat,
    required this.lng,
    this.placeName,
    this.placeId,
  });

  final double lat;
  final double lng;
  final String? placeName;
  final String? placeId;
}
```

Replace `_confirmPick`:

```dart
  /// A brand-new named location (search result, not one of the trip's
  /// existing Places) is added to the trip's Places on save, so it shows
  /// up as visited on future pickers, the Places tab, and the globe. An
  /// existing trip Place picked via chip that isn't visited yet is now
  /// also marked visited here (previously only brand-new places were).
  /// A bare map pin has no name to give a Place, so it's stored on the
  /// entry only.
  Future<void> _confirmPick(List<Place> tripPlaces) async {
    final picked = _picked!;
    final name = _placeName;
    final isNewNamedPlace = _pickedPlaceId == null &&
        name != null &&
        !tripPlaces.any(
          (p) => p.name.trim().toLowerCase() == name.trim().toLowerCase(),
        );

    var placeId = _pickedPlaceId;
    if (isNewNamedPlace) {
      setState(() => _saving = true);
      final places = ref.read(placeRepositoryProvider);
      placeId = await places.createPlace(
        name: name,
        lat: picked.latitude,
        lng: picked.longitude,
        tripId: widget.tripId,
      );
      await places.setVisited(
        placeId,
        visited: true,
        visitedOn: ref.read(clockProvider)(),
      );
    } else if (placeId != null) {
      final existing = tripPlaces.firstWhere((p) => p.id == placeId);
      if (!existing.isVisited) {
        setState(() => _saving = true);
        await ref.read(placeRepositoryProvider).setVisited(
              placeId,
              visited: true,
              visitedOn: ref.read(clockProvider)(),
            );
      }
    }

    if (mounted) {
      Navigator.of(context).pop(
        JournalLocationPick(
          lat: picked.latitude,
          lng: picked.longitude,
          placeName: _placeName,
          placeId: placeId,
        ),
      );
    }
  }
```

This intentionally calls `placeRepository.setVisited` directly, not `markPlaceVisited` — the entry itself is about to be created by the caller (`_JournalEntryFormState._save`, Step 2 below) with this `placeId` already attached, so routing through the stub-creating orchestrator here would risk a duplicate. The two directions stay separate one-way call sites (per the design spec).

- [ ] **Step 2: Thread `placeId` through the entry form**

`lib/features/journal/presentation/journal_entry_form_sheet.dart` — in `_JournalEntryFormState`, add a field, initialize it, clear it, and pass it through:

```dart
  double? _lat;
  double? _lng;
  String? _placeName;
  String? _placeId;
```

```dart
    _lat = existing?.lat;
    _lng = existing?.lng;
    _placeName = existing?.placeName;
    _placeId = existing?.placeId;
```

In the "clear location" `IconButton.onPressed`:

```dart
                onPressed: () => setState(() {
                  _lat = null;
                  _lng = null;
                  _placeName = null;
                  _placeId = null;
                }),
```

In `_pickLocation`:

```dart
  Future<void> _pickLocation() async {
    final pick = await JournalLocationPicker.open(
      context,
      tripId: widget.tripId,
      initialLat: _lat,
      initialLng: _lng,
      initialPlaceName: _placeName,
    );
    if (pick == null || !mounted) return;
    setState(() {
      _lat = pick.lat;
      _lng = pick.lng;
      _placeName = pick.placeName;
      _placeId = pick.placeId;
    });
  }
```

In `_save`, thread it into both branches:

```dart
    if (existing == null) {
      await repo.createEntry(
        tripId: widget.tripId,
        summary: _summary.text,
        loggedAt: _loggedAt,
        lat: _lat,
        lng: _lng,
        placeName: _placeName,
        placeId: _placeId,
        photoSourcePaths: _newPhotoPaths,
      );
    } else {
      await repo.updateEntry(
        existing.copyWith(
          summary: _summary.text,
          loggedAt: _loggedAt,
          lat: () => _lat,
          lng: () => _lng,
          placeName: () => _placeName,
          placeId: () => _placeId,
        ),
        newPhotoSourcePaths: _newPhotoPaths,
        removedPhotoIds: _removedPhotoIds,
      );
    }
```

- [ ] **Step 3: Update the existing location-picker test, add a new one**

`test/widget/journal/journal_location_picker_test.dart` — the first test's name and body need to change (picking an existing, not-yet-visited place must now mark it visited). Replace it with these two tests (asserting on `places`' state after save, same style the file's existing second test already uses — `JournalLocationPicker` is the `home` route in `_wrap`, so there's no separate route to capture a pop result from):

```dart
  testWidgets(
      'picking one of the trip\'s existing, not-yet-visited locations '
      'marks it visited', (tester) async {
    final places = FakePlaceRepository([
      const Place(
        id: 'p1',
        name: 'Railay Beach',
        lat: 8.0119,
        lng: 98.8378,
        tripId: 'trip-1',
      ),
    ]);
    await tester
        .pumpWidget(_wrap(places: places, geocoder: _FakeGeocoder(const [])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final all = await places.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.isVisited, isTrue);
  });

  testWidgets(
      'picking an already-visited trip place does not re-stamp visitedAt',
      (tester) async {
    final originalVisit = DateTime(2020, 1, 1);
    final places = FakePlaceRepository(
      [
        Place(
          id: 'p1',
          name: 'Railay Beach',
          lat: 8.0119,
          lng: 98.8378,
          tripId: 'trip-1',
          status: PlaceStatus.beenThere,
          visitedAt: originalVisit,
        ),
      ],
      clock: DateTime(2026, 7, 19),
    );
    await tester
        .pumpWidget(_wrap(places: places, geocoder: _FakeGeocoder(const [])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Railay Beach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final all = await places.watchAll().first;
    expect(all.single.visitedAt, originalVisit);
  });
```

- [ ] **Step 4: Run and commit**

Run (locally): `flutter test test/widget/journal/journal_location_picker_test.dart test/widget/journal/journal_entry_form_sheet_test.dart`
Expected: PASS. (`journal_entry_form_sheet_test.dart` isn't modified by this task, but re-run it since `_JournalEntryFormState` changed — confirm no regression.)

```bash
git add lib/features/journal/presentation/journal_location_picker.dart \
  lib/features/journal/presentation/journal_entry_form_sheet.dart \
  test/widget/journal/journal_location_picker_test.dart
git commit -m "feat(journal): picking an existing trip place marks it visited"
```

---

### Task 5: Pure entry-derivation helpers

**Files:**
- Create: `lib/features/journal/domain/journal_entry_queries.dart`
- Test: `test/unit/journal/journal_entry_queries_test.dart`

**Interfaces:**
- Produces: `JournalEntry? latestLocatedEntry(List<JournalEntry> entries)`; `List<(JournalEntry, JournalEntry)> journeyConnections(List<JournalEntry> entries)`; `List<List<JournalEntry>> groupEntriesByDay(List<JournalEntry> entries)`.

These are plain functions with no Flutter/GPU dependency — used by the globe (Task 6) and the gallery (Task 7), and independently unit-testable without any widget harness.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/journal/journal_entry_queries_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/domain/journal_entry_queries.dart';

JournalEntry _e(
  String id,
  DateTime loggedAt, {
  double? lat,
  double? lng,
}) =>
    JournalEntry(
      id: id,
      tripId: 't1',
      summary: id,
      loggedAt: loggedAt,
      createdAt: loggedAt,
      lat: lat,
      lng: lng,
    );

void main() {
  group('latestLocatedEntry', () {
    test('returns null for an empty list', () {
      expect(latestLocatedEntry([]), isNull);
    });

    test('returns null when no entry has a location', () {
      final entries = [_e('a', DateTime(2026, 1, 1))];
      expect(latestLocatedEntry(entries), isNull);
    });

    test('returns the located entry with the latest loggedAt', () {
      final entries = [
        _e('early', DateTime(2026, 1, 1), lat: 1, lng: 1),
        _e('unlocated', DateTime(2026, 1, 5)),
        _e('late', DateTime(2026, 1, 10), lat: 2, lng: 2),
      ];
      expect(latestLocatedEntry(entries)!.id, 'late');
    });
  });

  group('journeyConnections', () {
    test('empty for fewer than two located entries', () {
      expect(journeyConnections([]), isEmpty);
      expect(
        journeyConnections([_e('a', DateTime(2026, 1, 1), lat: 1, lng: 1)]),
        isEmpty,
      );
    });

    test('connects consecutive located entries in chronological order',
        () {
      final entries = [
        _e('c', DateTime(2026, 1, 3), lat: 3, lng: 3),
        _e('a', DateTime(2026, 1, 1), lat: 1, lng: 1),
        _e('unlocated', DateTime(2026, 1, 2)),
        _e('b', DateTime(2026, 1, 2, 12), lat: 2, lng: 2),
      ];
      final pairs = journeyConnections(entries);
      expect(pairs, hasLength(2));
      expect(pairs[0].$1.id, 'a');
      expect(pairs[0].$2.id, 'b');
      expect(pairs[1].$1.id, 'b');
      expect(pairs[1].$2.id, 'c');
    });
  });

  group('groupEntriesByDay', () {
    test('empty list produces no groups', () {
      expect(groupEntriesByDay([]), isEmpty);
    });

    test('groups same-day entries together, preserving order, sorted by day',
        () {
      final entries = [
        _e('day2-first', DateTime(2026, 1, 2, 9)),
        _e('day1-only', DateTime(2026, 1, 1, 14)),
        _e('day2-second', DateTime(2026, 1, 2, 18)),
      ];
      final groups = groupEntriesByDay(entries);
      expect(groups, hasLength(2));
      expect(groups[0].map((e) => e.id).toList(), ['day1-only']);
      expect(
        groups[1].map((e) => e.id).toList(),
        ['day2-first', 'day2-second'],
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run (locally): `flutter test test/unit/journal/journal_entry_queries_test.dart`
Expected: FAIL — `package:tripper/features/journal/domain/journal_entry_queries.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

Create `lib/features/journal/domain/journal_entry_queries.dart`:

```dart
import 'journal_entry.dart';

/// The chronologically-latest located entry, or null if none are located.
/// Used by the globe to decide what to focus on when it opens or when a
/// new entry is logged.
JournalEntry? latestLocatedEntry(List<JournalEntry> entries) {
  JournalEntry? latest;
  for (final entry in entries) {
    if (!entry.hasLocation) continue;
    if (latest == null || entry.loggedAt.isAfter(latest.loggedAt)) {
      latest = entry;
    }
  }
  return latest;
}

/// Consecutive pairs of located entries in chronological order — the
/// journey line's segments on the globe.
List<(JournalEntry, JournalEntry)> journeyConnections(
  List<JournalEntry> entries,
) {
  final located = entries.where((e) => e.hasLocation).toList()
    ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  return [
    for (var i = 0; i < located.length - 1; i++) (located[i], located[i + 1]),
  ];
}

/// [entries] grouped by the local calendar day of [JournalEntry.loggedAt],
/// oldest day first; entries within a day keep their relative order from
/// [entries] (the caller is expected to already pass entries in
/// chronological order — [JournalRepository.watchForTrip] does). Used by
/// the gallery timeline to decide which entries share one day-slot.
List<List<JournalEntry>> groupEntriesByDay(List<JournalEntry> entries) {
  final byDay = <DateTime, List<JournalEntry>>{};
  final order = <DateTime>[];
  for (final entry in entries) {
    final day = DateTime(
      entry.loggedAt.year,
      entry.loggedAt.month,
      entry.loggedAt.day,
    );
    if (!byDay.containsKey(day)) {
      order.add(day);
      byDay[day] = [];
    }
    byDay[day]!.add(entry);
  }
  order.sort();
  return [for (final day in order) byDay[day]!];
}
```

- [ ] **Step 4: Run to verify it passes**

Run (locally): `flutter test test/unit/journal/journal_entry_queries_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/journal/domain/journal_entry_queries.dart \
  test/unit/journal/journal_entry_queries_test.dart
git commit -m "feat(journal): add pure entry-derivation helpers for globe and gallery"
```

---

### Task 6: Globe — entries, drag-only rotation, photo dots, journey line

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`
- Modify: `lib/features/journal/presentation/trip_journal_tab.dart`
- Modify: `test/widget/journal/journal_globe_test.dart`

**Interfaces:**
- Consumes: `latestLocatedEntry`, `journeyConnections` (Task 5); `JournalEntry` (Task 2).
- Produces: `JournalGlobe({required List<JournalEntry> entries, void Function(JournalEntry)? onEntryTap, bool renderGlobe})`.

- [ ] **Step 1: Rewrite `journal_globe.dart`**

Full replacement of `lib/features/journal/presentation/journal_globe.dart`:

```dart
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_entry_queries.dart';

const _dotSize = 2.5;
const _photoDotDiameter = 26.0;

/// flutter_earth_globe renders via GPU fragment shaders, which widget tests
/// can't render. Tests pass `renderGlobe: false` to get tappable
/// entry-icon scaffolding without ever constructing
/// `FlutterEarthGlobeController` (SPEC: no GPU/platform dependency in
/// tests) — same seam as PlacesMapView's `renderMap: false`.
///
/// Texture is a locally bundled asset (assets/globe/earth_day.jpg) — no
/// network fetch to render (offline rule, SPEC §3.1.2). Points are this
/// trip's located journal entries — an entry IS a visited place (see
/// place_visit_actions.dart) — not read from Places directly.
class JournalGlobe extends StatefulWidget {
  const JournalGlobe({
    super.key,
    required this.entries,
    this.onEntryTap,
    this.renderGlobe = true,
  });

  final List<JournalEntry> entries;
  final void Function(JournalEntry entry)? onEntryTap;
  final bool renderGlobe;

  @override
  State<JournalGlobe> createState() => _JournalGlobeState();
}

class _JournalGlobeState extends State<JournalGlobe> {
  FlutterEarthGlobeController? _controller;
  bool _initialized = false;
  String? _focusedEntryId;

  // Not initState: building the controller reads context.colors (a Theme
  // lookup), and establishing an InheritedWidget dependency before
  // initState() completes throws. didChangeDependencies is the first safe
  // point, and runs before the first build.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.renderGlobe && !_initialized) {
      _initialized = true;
      _controller = _buildController();
    }
  }

  @override
  void didUpdateWidget(JournalGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.renderGlobe || _sameEntryIds(oldWidget.entries)) return;
    _syncPoints(oldWidget.entries);
    _maybeFocusLatest();
  }

  bool _sameEntryIds(List<JournalEntry> previous) {
    if (previous.length != widget.entries.length) return false;
    for (var i = 0; i < previous.length; i++) {
      if (previous[i].id != widget.entries[i].id) return false;
    }
    return true;
  }

  // Diffed in place via addPoint/removePoint (and addPointConnection/
  // removePointConnection) — never dispose+recreate the controller here.
  // flutter_earth_globe's own FlutterEarthGlobe widget disposes
  // controller.rotationController itself when unmounted; disposing it
  // again ourselves double-frees the same AnimationController and
  // crashes ("AnimationController.dispose() called more than once").
  void _syncPoints(List<JournalEntry> previous) {
    final controller = _controller;
    if (controller == null) return;
    for (final connection in controller.connections.toList()) {
      controller.removePointConnection(connection.id);
    }
    for (final entry in previous) {
      if (entry.hasLocation) controller.removePoint(entry.id);
    }
    _addPoints(controller);
  }

  void _addPoints(FlutterEarthGlobeController controller) {
    final colors = context.colors;
    for (final entry in widget.entries) {
      if (!entry.hasLocation) continue;
      controller.addPoint(
        Point(
          id: entry.id,
          coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
          label: entry.placeName ?? entry.summary,
          // Photo entries render via labelBuilder instead (below) — the
          // native dot is suppressed (size: 0) so it doesn't peek out
          // from behind the thumbnail.
          style: PointStyle(
            color: colors.accent,
            size: entry.hasPhotos ? 0 : _dotSize,
          ),
          isLabelVisible: entry.hasPhotos,
          // Centers a _photoDotDiameter-square widget exactly on the
          // point: the package positions labelBuilder output at
          // `left = pos.dx - labelOffset.dx - width/2`,
          // `top = pos.dy - labelOffset.dy - height`.
          labelOffset: const Offset(0, -_photoDotDiameter / 2),
          labelBuilder: entry.hasPhotos
              ? (context, point, isHovering, isVisible) =>
                  _PhotoDot(filePath: entry.photos.first.filePath)
              : null,
          onTap: widget.onEntryTap == null
              ? null
              : () => widget.onEntryTap!(entry),
        ),
      );
    }
    for (final (start, end) in journeyConnections(widget.entries)) {
      controller.addPointConnection(
        PointConnection(
          id: '${start.id}->${end.id}',
          start: GlobeCoordinates(start.lat!, start.lng!),
          end: GlobeCoordinates(end.lat!, end.lng!),
          style: PointConnectionStyle(
            color: colors.accent.withValues(alpha: 0.6),
            lineWidth: 1.5,
          ),
        ),
      );
    }
  }

  FlutterEarthGlobeController _buildController() {
    final controller = FlutterEarthGlobeController(
      // Auto-rotation was disorienting (issue: "the map is spinning, a
      // headache reason") — the globe now only moves on user drag, which
      // is native to the package regardless of this flag.
      isRotating: false,
      isDayNightCycleEnabled: false,
      // The package applies a simulated directional light to the sphere
      // shader independent of isDayNightCycleEnabled — defaults to a strong
      // hemisphere-darkening effect that reads as a night side. Disable it
      // so the whole globe renders evenly lit.
      surfaceLightingEnabled: false,
      surface: const AssetImage('assets/globe/earth_day.jpg'),
    );
    controller.onLoaded = () {
      _addPoints(controller);
      _maybeFocusLatest(animate: false);
    };
    return controller;
  }

  /// Opens on the most recent entry rather than a fixed default, and
  /// re-focuses (animated) only when the latest entry actually changes —
  /// not on every unrelated edit to some other entry.
  void _maybeFocusLatest({bool animate = true}) {
    final controller = _controller;
    if (controller == null || !controller.isReady) return;
    final latest = latestLocatedEntry(widget.entries);
    if (latest == null || latest.id == _focusedEntryId) return;
    _focusedEntryId = latest.id;
    controller.focusOnCoordinates(
      GlobeCoordinates(latest.lat!, latest.lng!),
      animate: animate,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!widget.renderGlobe) {
      // Test/preview scaffold: no shader surface, located entries as
      // tappable icons (photo-camera for entries with a photo, plain dot
      // otherwise) — mirrors JournalMapView's own renderMap:false seam.
      return ColoredBox(
        color: colors.paper,
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final entry in widget.entries)
                if (entry.hasLocation)
                  Semantics(
                    button: widget.onEntryTap != null,
                    label: entry.placeName ?? entry.summary,
                    child: IconButton(
                      icon: Icon(
                        entry.hasPhotos ? Icons.photo_camera : Icons.circle,
                        color: colors.accent,
                      ),
                      onPressed: widget.onEntryTap == null
                          ? null
                          : () => widget.onEntryTap!(entry),
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    // flutter_earth_globe sizes and centers itself off MediaQuery.of(context)
    // .size — the full device screen — rather than the constraints its
    // parent actually gives it. Embedded in a partial-height box (here, 70%
    // of the journal tab body), that mismatch made the sphere overflow/
    // misalign instead of filling its allotted area. Scoping a MediaQuery
    // with the real local size makes the package's internal layout math
    // match its actual box, and sizing the radius off that box keeps the
    // whole sphere visible without cropping.
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final radius = (math.min(size.width, size.height) / 2 - 12)
            .clamp(40.0, 110.0)
            .toDouble();
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: size),
          child: FlutterEarthGlobe(controller: _controller!, radius: radius),
        );
      },
    );
  }
}

/// A circular, accent-bordered photo thumbnail rendered at a point's
/// screen position via Point.labelBuilder (the package has no built-in
/// image support for points).
class _PhotoDot extends StatelessWidget {
  const _PhotoDot({required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: _photoDotDiameter,
      height: _photoDotDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.accent, width: 1.5),
      ),
      child: ClipOval(
        child: Image.file(
          File(filePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(color: colors.paper),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update the caller**

`lib/features/journal/presentation/trip_journal_tab.dart` — change the globe's data source. Replace:

```dart
                    Expanded(
                      flex: 7,
                      child: JournalGlobe(
                        places: visitedPlaces,
                        renderGlobe: renderGlobe,
                      ),
                    ),
```

with:

```dart
                    Expanded(
                      flex: 7,
                      child: JournalGlobe(
                        entries: entries,
                        renderGlobe: renderGlobe,
                      ),
                    ),
```

`visitedPlaces` (from `tripVisitedPlacesProvider`) stays used elsewhere in this same file for the `journalStatsLine` "N places visited" count — don't remove that provider or its `ref.watch` call.

- [ ] **Step 3: Rewrite the globe widget test**

Full replacement of `test/widget/journal/journal_globe_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_globe.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _e(String id, double lat, double lng) =>
    JournalEntry(
      id: id,
      tripId: 't1',
      summary: id,
      loggedAt: DateTime(2026, 7, 19),
      createdAt: DateTime(2026, 7, 19),
      lat: lat,
      lng: lng,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

void main() {
  // renderGlobe: false — flutter_earth_globe needs a GPU shader surface
  // that widget tests can't create (and we never hit the network here).
  testWidgets(
      'renders one tappable icon per located entry, tap fires the callback',
      (tester) async {
    JournalEntry? tapped;
    await tester.pumpWidget(
      _wrap(
        JournalGlobe(
          renderGlobe: false,
          onEntryTap: (e) => tapped = e,
          entries: [_e('a', 8.0, 98.8), _e('b', 7.7, 98.7)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.circle).first);
    await tester.pump();
    expect(tapped?.id, 'a');
  });

  testWidgets('entries without a location render no icon', (tester) async {
    final unlocated = JournalEntry(
      id: 'u',
      tripId: 't1',
      summary: 'no pin',
      loggedAt: DateTime(2026, 7, 19),
      createdAt: DateTime(2026, 7, 19),
    );
    await tester.pumpWidget(
      _wrap(JournalGlobe(renderGlobe: false, entries: [unlocated])),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.circle), findsNothing);
    expect(find.byIcon(Icons.photo_camera), findsNothing);
  });

  testWidgets('zero entries renders without crashing', (tester) async {
    await tester
        .pumpWidget(_wrap(const JournalGlobe(renderGlobe: false, entries: [])));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.circle), findsNothing);
  });
}
```

> Photo-vs-plain icon rendering (`Icons.photo_camera`) is already exercised by `JournalMapView`'s equivalent test seam — this file's second test covers "no location -> no icon" instead of duplicating that.

- [ ] **Step 4: Run and commit**

Run (locally): `flutter analyze && flutter test test/widget/journal/journal_globe_test.dart test/widget/journal/trip_journal_tab_test.dart`
Expected: PASS.

```bash
git add lib/features/journal/presentation/journal_globe.dart \
  lib/features/journal/presentation/trip_journal_tab.dart \
  test/widget/journal/journal_globe_test.dart
git commit -m "feat(journal): globe plots entries, drag-only rotation, photo dots, journey line"
```

**Manual verification required** (per `CLAUDE.md`: no GPU rendering in this environment or in widget tests) — once this lands, verify on-device or via `flutter run` that: dots are visibly smaller and don't collide for nearby entries; photo entries show the thumbnail, not a flat dot; a line connects entries in trip order; the globe does not auto-spin and opens centered on the latest entry; dragging still rotates it.

---

### Task 7: Gallery — day-grouped horizontal timeline

**Files:**
- Modify: `lib/features/journal/presentation/journal_widgets.dart`
- Modify: `lib/features/journal/presentation/trip_journal_tab.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_localizations.dart`
- Modify: `lib/l10n/app_localizations_en.dart`
- Test: `test/widget/journal/journal_gallery_timeline_test.dart`

**Interfaces:**
- Consumes: `groupEntriesByDay` (Task 5).
- Produces: `JournalGalleryTimeline({required List<JournalEntry> entries, required void Function(JournalEntry) onEdit, required void Function(JournalEntry) onDelete})`.

- [ ] **Step 1: Add the two new l10n strings**

`lib/l10n/app_en.arb` — add after `"journalMapLocationHint"` (around line 298):

```json
  "journalDayEntriesTitle": "{count} entries · {date}",
  "@journalDayEntriesTitle": {
    "placeholders": {
      "count": { "type": "int" },
      "date": { "type": "String" }
    }
  },
  "journalUntitledEntry": "Not written yet",
```

`lib/l10n/app_localizations.dart` — add after the `journalMapLocationHint` getter declaration (around line 1373):

```dart
  /// No description provided for @journalDayEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} entries · {date}'**
  String journalDayEntriesTitle(int count, String date);

  /// No description provided for @journalUntitledEntry.
  ///
  /// In en, this message translates to:
  /// **'Not written yet'**
  String get journalUntitledEntry;
```

`lib/l10n/app_localizations_en.dart` — add after the `journalMapLocationHint` getter implementation (around line 745):

```dart
  @override
  String journalDayEntriesTitle(int count, String date) {
    return '$count entries · $date';
  }

  @override
  String get journalUntitledEntry => 'Not written yet';
```

- [ ] **Step 2: Refactor `JournalGalleryCard` to expose shared pieces**

`lib/features/journal/presentation/journal_widgets.dart` — change `_photoHeight` from a private instance-scoped constant to a public one, and `_placeholder` from a private instance method to a public static method, so the new grouped card (Step 3) can reuse them. In the existing `JournalGalleryCard` class:

Replace:
```dart
  static const width = 148.0;
  static const _photoHeight = 84.0;
```
with:
```dart
  static const width = 148.0;
  static const photoHeight = 84.0;
```

Replace every remaining use of `_photoHeight` in this class with `photoHeight` (there are two: the `Image.file` height, and the `_placeholder(colors)` container height).

Replace:
```dart
  Widget _placeholder(AppColors colors) => Container(
        width: width,
        height: _photoHeight,
        color: colors.paper,
        alignment: Alignment.center,
        child: Icon(Icons.edit_note, color: colors.inkMuted),
      );
```
with:
```dart
  static Widget placeholder(AppColors colors) => Container(
        width: width,
        height: photoHeight,
        color: colors.paper,
        alignment: Alignment.center,
        child: Icon(Icons.edit_note, color: colors.inkMuted),
      );
```

And update its two call sites within the same class (`_placeholder(colors)` → `placeholder(colors)`).

- [ ] **Step 3: Add the timeline, the grouped card, and the day-list sheet**

Append to `lib/features/journal/presentation/journal_widgets.dart` (add these imports at the top of the file alongside the existing ones: `import '../../../l10n/app_localizations.dart';` and `import '../domain/journal_entry_queries.dart';`):

```dart
/// Horizontal, day-grouped timeline for the strip below the globe: a
/// hairline track with one dot per calendar day, each day's card hanging
/// below it on a short stem. A day with more than one entry renders as a
/// stacked-photo card with a count badge instead of [JournalGalleryCard]
/// directly; tapping it opens [showJournalDayEntriesSheet].
class JournalGalleryTimeline extends StatelessWidget {
  const JournalGalleryTimeline({
    super.key,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  final List<JournalEntry> entries;
  final void Function(JournalEntry entry) onEdit;
  final void Function(JournalEntry entry) onDelete;

  static const _dotSize = 11.0;
  static const _stemHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = groupEntriesByDay(entries);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            top: _dotSize / 2 - 1,
            child: Container(height: 2, color: colors.hairline),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: _dotSize / 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in days)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: _DaySlot(
                      day: day,
                      colors: colors,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySlot extends StatelessWidget {
  const _DaySlot({
    required this.day,
    required this.colors,
    required this.onEdit,
    required this.onDelete,
  });

  final List<JournalEntry> day;
  final AppColors colors;
  final void Function(JournalEntry entry) onEdit;
  final void Function(JournalEntry entry) onDelete;

  @override
  Widget build(BuildContext context) {
    final first = day.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: JournalGalleryTimeline._dotSize,
          height: JournalGalleryTimeline._dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accent,
            border: Border.all(color: colors.paper, width: 2),
          ),
        ),
        Container(
          width: 1,
          height: JournalGalleryTimeline._stemHeight,
          color: colors.hairline,
        ),
        day.length == 1
            ? JournalGalleryCard(
                entry: first,
                onTap: () => onEdit(first),
                onDelete: () => onDelete(first),
              )
            : _GroupedGalleryCard(
                day: day,
                onOpenDay: () => showJournalDayEntriesSheet(
                  context,
                  entries: day,
                  onEdit: onEdit,
                ),
              ),
      ],
    );
  }
}

class _GroupedGalleryCard extends StatelessWidget {
  const _GroupedGalleryCard({required this.day, required this.onOpenDay});

  final List<JournalEntry> day;
  final VoidCallback onOpenDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = day.first;
    final photoEntry = day.firstWhere((e) => e.hasPhotos, orElse: () => first);

    return SizedBox(
      width: JournalGalleryCard.width,
      child: PaperCard(
        onTap: onOpenDay,
        padding: EdgeInsets.zero,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: JournalGalleryCard.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppShape.radius - 1),
                      ),
                      child: photoEntry.hasPhotos
                          ? Image.file(
                              File(photoEntry.photos.first.filePath),
                              width: JournalGalleryCard.width,
                              height: JournalGalleryCard.photoHeight,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  JournalGalleryCard.placeholder(colors),
                            )
                          : JournalGalleryCard.placeholder(colors),
                    ),
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.inkPrimary.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: MonoText('${day.length}', color: colors.surface),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(DateFormat('dd MMM').format(first.loggedAt)),
                      const SizedBox(height: 2),
                      Text(
                        first.summary.isEmpty
                            ? AppLocalizations.of(context)!.journalUntitledEntry
                            : first.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          color: colors.inkPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing one day's entries — reached by tapping a
/// multi-entry [JournalGalleryTimeline] card. Tapping a row closes the
/// sheet and calls [onEdit] for that entry.
Future<void> showJournalDayEntriesSheet(
  BuildContext context, {
  required List<JournalEntry> entries,
  required void Function(JournalEntry entry) onEdit,
}) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    builder: (context) => _JournalDayEntriesSheet(entries: entries, onEdit: onEdit),
  );
}

class _JournalDayEntriesSheet extends StatelessWidget {
  const _JournalDayEntriesSheet({required this.entries, required this.onEdit});

  final List<JournalEntry> entries;
  final void Function(JournalEntry entry) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final day = entries.first.loggedAt;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SectionLabel(
              l10n.journalDayEntriesTitle(
                entries.length,
                DateFormat('d MMMM').format(day),
              ),
            ),
          ),
          for (final entry in entries)
            ListTile(
              leading: entry.hasPhotos
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(entry.photos.first.filePath),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _dayRowPlaceholder(colors),
                      ),
                    )
                  : _dayRowPlaceholder(colors),
              title: Text(
                entry.summary.isEmpty ? l10n.journalUntitledEntry : entry.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: MonoText(
                DateFormat('HH:mm').format(entry.loggedAt),
                muted: true,
              ),
              onTap: () {
                Navigator.of(context).pop();
                onEdit(entry);
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _dayRowPlaceholder(AppColors colors) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.hairline),
        ),
        child: Icon(Icons.edit_note, color: colors.inkMuted),
      );
}
```

`JournalGalleryTimeline._dotSize`/`_stemHeight` are referenced from `_DaySlot` by their qualified private name (`JournalGalleryTimeline._dotSize`) — valid Dart, since both classes live in the same library file.

Also add `import '../../../core/widgets/section_label.dart';` to this file's imports if not already present (check — `trip_journal_tab.dart` imports it today, `journal_widgets.dart` currently doesn't).

- [ ] **Step 4: Wire it into the tab, replacing the raw `ListView`**

`lib/features/journal/presentation/trip_journal_tab.dart` — replace the entire gallery `Expanded(flex: 3, child: ListView(...))` block (the one iterating `entries` into `JournalGalleryCard`s) with:

```dart
                    Expanded(
                      flex: 3,
                      child: JournalGalleryTimeline(
                        entries: entries,
                        onEdit: (entry) => showJournalEntryFormSheet(
                          context,
                          tripId: trip.id,
                          existing: entry,
                        ),
                        onDelete: (entry) => _confirmDelete(context, ref, entry),
                      ),
                    ),
```

- [ ] **Step 5: Write the widget tests**

Create `test/widget/journal/journal_gallery_timeline_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _e(String id, DateTime loggedAt, {String summary = ''}) =>
    JournalEntry(
      id: id,
      tripId: 't1',
      summary: summary.isEmpty ? id : summary,
      loggedAt: loggedAt,
      createdAt: loggedAt,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SizedBox(height: 200, child: child)),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

void main() {
  testWidgets('single-entry day renders its summary directly, tap edits it',
      (tester) async {
    JournalEntry? edited;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [_e('a', DateTime(2026, 7, 20), summary: 'Arrived')],
          onEdit: (e) => edited = e,
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arrived'), findsOneWidget);
    await tester.tap(find.text('Arrived'));
    await tester.pump();
    expect(edited?.id, 'a');
  });

  testWidgets(
      'multi-entry day shows a count badge, tap opens the day list, '
      'tapping a row edits that entry', (tester) async {
    JournalEntry? edited;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [
            _e('morning', DateTime(2026, 7, 20, 9), summary: 'Woke up early'),
            _e('evening', DateTime(2026, 7, 20, 20), summary: 'Sunset walk'),
          ],
          onEdit: (e) => edited = e,
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    // The grouped card shows the first (earliest) entry's summary as its
    // own label — not each individual entry yet.
    expect(find.text('Woke up early'), findsOneWidget);
    expect(find.text('Sunset walk'), findsNothing);

    await tester.tap(find.text('Woke up early'));
    await tester.pumpAndSettle();

    // Day-list sheet now shows both.
    expect(find.text('Woke up early'), findsOneWidget);
    expect(find.text('Sunset walk'), findsOneWidget);

    await tester.tap(find.text('Sunset walk'));
    await tester.pumpAndSettle();
    expect(edited?.id, 'evening');
  });

  testWidgets('entries on different days each get their own dot and card',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [
            _e('day1', DateTime(2026, 7, 19), summary: 'Day one'),
            _e('day2', DateTime(2026, 7, 20), summary: 'Day two'),
          ],
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day one'), findsOneWidget);
    expect(find.text('Day two'), findsOneWidget);
    expect(find.text('2'), findsNothing); // no grouping badge — two days
  });

  testWidgets('empty-summary entry falls back to the "not written yet" label',
      () async {
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [
            JournalEntry(
              id: 'stub',
              tripId: 't1',
              summary: '',
              loggedAt: DateTime(2026, 7, 20),
              createdAt: DateTime(2026, 7, 20),
            ),
          ],
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not written yet'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run and commit**

Run (locally): `flutter analyze && flutter test test/widget/journal/journal_gallery_timeline_test.dart test/widget/journal/trip_journal_tab_test.dart`
Expected: PASS. `trip_journal_tab_test.dart`'s existing "entries render in the timeline" test (single entry) should still pass unmodified against the new widget.

```bash
git add lib/features/journal/presentation/journal_widgets.dart \
  lib/features/journal/presentation/trip_journal_tab.dart \
  lib/l10n/app_en.arb \
  lib/l10n/app_localizations.dart \
  lib/l10n/app_localizations_en.dart \
  test/widget/journal/journal_gallery_timeline_test.dart
git commit -m "feat(journal): day-grouped horizontal gallery timeline"
```

---

## Suggested execution order

Tasks 1 → 2 → 3 → 4 must run in that order (each depends on the previous). Task 5 has no dependency on 1–4 and could run any time after Task 2 (it only needs `JournalEntry`, not `placeId` specifically) — but running it after Task 4 keeps the branch linear and easy to review. Tasks 6 and 7 both depend on Task 5; they don't depend on each other and could be done in parallel by two different workers if desired, but touch the same file (`trip_journal_tab.dart`) in nearby but non-overlapping regions (globe `Expanded` vs. gallery `Expanded`), so sequential is simpler.
