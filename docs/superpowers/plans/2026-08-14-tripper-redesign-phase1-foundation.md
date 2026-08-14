# Tripper Redesign — Phase 1: Design-System Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the token/primitive foundation for the "Immersive Golden Hour" redesign — the new `AppColors`/`AppShape` values, the `Trip.coverPhotoPath` schema column, the generated-cover-gradient helper, the `GlassChrome` primitive, and the governance doc rewrite (CLAUDE.md rules 1 & 6, SPEC.md §4) — so every later phase (Trips+Vault, Places, Journal+Expenses+Settings, cross-cutting polish) builds on the real tokens instead of the old teal/rust field-journal system.

**Architecture:** Five self-contained tasks. Tasks 1–4 are additive/value-only changes (no existing screen is restyled yet — that's Phases 2–4) so the app keeps compiling and passing its full test suite after every task. Task 5 rewrites governance docs to match what tasks 1–4 actually shipped, per the design spec's explicit instruction to update docs alongside code rather than ahead of it.

**Tech Stack:** Flutter/Dart, Riverpod, Drift/SQLite (schema v12 → v13), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md` (sections referenced below: §3 design tokens, §4 component rules, §6 technical implications, §7 governance doc updates).

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart` (CLAUDE.md rule 1, unchanged mechanism — only the values and written rule change).
- One accent only: coral (`AppColors.accent`) does all interactive/active/CTA work. Amber (`AppColors.warning`) is reserved for expiry/danger-adjacent warnings — never reused as a second accent (spec §4 rule 1).
- Gradients are scoped to hero/cover-photo scrims and generated trip-cover art only — never buttons, text backgrounds, or flat surfaces (spec §4 rule 2).
- No new font assets — reuses the three already bundled (Fraunces, IBM Plex Sans, IBM Plex Mono); no `pubspec.yaml` changes needed in this phase (`image_picker` is already a dependency, unused until Phase 2's picker UI).
- No `DateTime.now()` in domain code, ARB-only strings, RTL-safe layouts, local-first/offline policy, and test-with-feature discipline (CLAUDE.md rules 2–5) remain unaffected and apply to every task below.
- Every Drift schema bump ships a migration test in the same commit (CLAUDE.md rule 5) — Task 2.

**Out of scope for this plan** (deferred to later phases per spec §8): restyling any actual screen (Trips list, Trip detail, Vault, Places, Journal), the cover-photo picker UI, custom map styles/markers, the journal globe recolor, RTL re-verification against restyled screens, and golden-test baselines (none exist yet in this repo, so there is nothing to re-baseline in this phase).

---

### Task 1: Rewrite `AppColors` and `AppShape` tokens

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/theme/app_spacing.dart:11-17` (the `AppShape` class)
- Test: `test/unit/theme/app_colors_test.dart` (new)

**Interfaces:**
- Produces: `AppColors` gains four new required fields — `heroGradientStart`, `heroGradientEnd`, `mapWater`, `mapLand` (`Color`, non-nullable) — alongside the existing `paper`, `surface`, `inkPrimary`, `inkSecondary`, `inkMuted`, `hairline`, `accent`, `warning`, `error`, `success`. `AppShape.pillRadius` (`double`, `999.0`) is new; `AppShape.radius` changes from `10.0` to `14.0`. Every later task/phase reads colors via `context.colors` (`AppColorsX` extension, unchanged) and shape via `AppShape.radius`/`AppShape.pillRadius`.

- [ ] **Step 1: Write the failing token-value test**

Create `test/unit/theme/app_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_spacing.dart';

/// Locks the "Immersive Golden Hour" token values (redesign spec §3) so a
/// future edit can't silently drift the palette back toward the old
/// teal/rust field-journal system without a test failing here first.
void main() {
  test('dark palette matches the Immersive Golden Hour spec', () {
    expect(AppColors.dark.paper, const Color(0xFF12141C));
    expect(AppColors.dark.surface, const Color(0xFF1C1F2B));
    expect(AppColors.dark.inkPrimary, const Color(0xFFF5F1EA));
    expect(AppColors.dark.inkSecondary, const Color(0xFFA9AEBD));
    expect(AppColors.dark.inkMuted, const Color(0xFF6E7386));
    expect(AppColors.dark.hairline, const Color(0x14FFFFFF));
    expect(AppColors.dark.accent, const Color(0xFFFF6B5E));
    expect(AppColors.dark.warning, const Color(0xFFF2A93C));
    expect(AppColors.dark.error, const Color(0xFFE5484D));
    expect(AppColors.dark.success, const Color(0xFF34D399));
    expect(AppColors.dark.heroGradientStart, const Color(0xFF171A2E));
    expect(AppColors.dark.heroGradientEnd, const Color(0xFFFF6B5E));
    expect(AppColors.dark.mapWater, const Color(0xFF17263C));
    expect(AppColors.dark.mapLand, const Color(0xFF242F3E));
  });

  test('light palette matches the Immersive Golden Hour spec', () {
    expect(AppColors.light.paper, const Color(0xFFFAF3EC));
    expect(AppColors.light.surface, const Color(0xFFFFFFFF));
    expect(AppColors.light.inkPrimary, const Color(0xFF1B1A22));
    expect(AppColors.light.inkSecondary, const Color(0xFF5B5A66));
    expect(AppColors.light.inkMuted, const Color(0xFF8A8894));
    expect(AppColors.light.hairline, const Color(0xFFE7E1D8));
    expect(AppColors.light.accent, const Color(0xFFE85A4E));
    expect(AppColors.light.warning, const Color(0xFFC97A1B));
    expect(AppColors.light.error, const Color(0xFFC23B34));
    expect(AppColors.light.success, const Color(0xFF1F9A6E));
    expect(AppColors.light.heroGradientStart, const Color(0xFFFAF3EC));
    expect(AppColors.light.heroGradientEnd, const Color(0xFFE85A4E));
    expect(AppColors.light.mapWater, const Color(0xFFDCEAE6));
    expect(AppColors.light.mapLand, const Color(0xFFEFE7D8));
  });

  test('card/sheet corner radius grows to 14px (spec §3.4)', () {
    expect(AppShape.radius, 14.0);
  });

  test('pill radius token exists for chips/tab indicators (spec §3.4)', () {
    expect(AppShape.pillRadius, 999.0);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/theme/app_colors_test.dart`
Expected: compile error or FAIL — `heroGradientStart`/`heroGradientEnd`/`mapWater`/`mapLand`/`pillRadius` don't exist yet, and the current `accent`/`warning` values are still teal/rust.

- [ ] **Step 3: Rewrite `AppColors`**

Replace the full contents of `lib/core/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// The Tripper palette — "Immersive Golden Hour"
/// (docs/superpowers/specs/2026-08-14-tripper-redesign-design.md §3). The
/// ONLY file allowed to contain raw Color(0xFF...) values.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.paper,
    required this.surface,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkMuted,
    required this.hairline,
    required this.accent,
    required this.warning,
    required this.error,
    required this.success,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.mapWater,
    required this.mapLand,
  });

  /// App background. Dark mode: near-black night tone. Light mode: warm
  /// off-white, never pure white.
  final Color paper;

  /// Cards and sheets — solid content, never glass.
  final Color surface;

  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkMuted;

  /// Dividers and card borders — hairlines survive under the new skin.
  final Color hairline;

  /// Coral — the one accent. Actions, active states, "want to go"
  /// pins/dots. Never a second accent alongside [warning].
  final Color accent;

  /// Amber — expiry/danger-adjacent warnings only. Also reused for map
  /// labels — no separate "map gold" token.
  final Color warning;

  final Color error;
  final Color success;

  /// Cover scrims and generated trip-cover art only — never buttons, text
  /// backgrounds, or flat surfaces (component rule 2).
  final Color heroGradientStart;
  final Color heroGradientEnd;

  /// Custom Google Maps style base (map_style.dart, Phase 3) — replaces
  /// Google's stock/Night colors.
  final Color mapWater;
  final Color mapLand;

  static const light = AppColors(
    paper: Color(0xFFFAF3EC),
    surface: Color(0xFFFFFFFF),
    inkPrimary: Color(0xFF1B1A22),
    inkSecondary: Color(0xFF5B5A66),
    inkMuted: Color(0xFF8A8894),
    hairline: Color(0xFFE7E1D8),
    accent: Color(0xFFE85A4E),
    warning: Color(0xFFC97A1B),
    error: Color(0xFFC23B34),
    success: Color(0xFF1F9A6E),
    heroGradientStart: Color(0xFFFAF3EC),
    heroGradientEnd: Color(0xFFE85A4E),
    mapWater: Color(0xFFDCEAE6),
    mapLand: Color(0xFFEFE7D8),
  );

  static const dark = AppColors(
    paper: Color(0xFF12141C),
    surface: Color(0xFF1C1F2B),
    inkPrimary: Color(0xFFF5F1EA),
    inkSecondary: Color(0xFFA9AEBD),
    inkMuted: Color(0xFF6E7386),
    hairline: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    accent: Color(0xFFFF6B5E),
    warning: Color(0xFFF2A93C),
    error: Color(0xFFE5484D),
    success: Color(0xFF34D399),
    heroGradientStart: Color(0xFF171A2E),
    heroGradientEnd: Color(0xFFFF6B5E),
    mapWater: Color(0xFF17263C),
    mapLand: Color(0xFF242F3E),
  );

  @override
  AppColors copyWith({
    Color? paper,
    Color? surface,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkMuted,
    Color? hairline,
    Color? accent,
    Color? warning,
    Color? error,
    Color? success,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? mapWater,
    Color? mapLand,
  }) {
    return AppColors(
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      success: success ?? this.success,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      mapWater: mapWater ?? this.mapWater,
      mapLand: mapLand ?? this.mapLand,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      paper: Color.lerp(paper, other.paper, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      heroGradientStart:
          Color.lerp(heroGradientStart, other.heroGradientStart, t)!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      mapWater: Color.lerp(mapWater, other.mapWater, t)!,
      mapLand: Color.lerp(mapLand, other.mapLand, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
```

- [ ] **Step 4: Update `AppShape`**

In `lib/core/theme/app_spacing.dart`, replace the `AppShape` class (lines 11-17):

```dart
abstract final class AppShape {
  /// Cards and sheets — grown from the old field-journal 10px per the
  /// redesign (spec §3.4).
  static const radius = 14.0;

  /// Chips and tab indicators — full pill.
  static const pillRadius = 999.0;

  /// Hairline borders instead of shadows on solid content.
  static const hairlineWidth = 0.5;
}
```

- [ ] **Step 5: Run the test again and confirm it passes**

Run: `flutter test test/unit/theme/app_colors_test.dart`
Expected: PASS (all four tests).

- [ ] **Step 6: Regression-check contrast app-wide**

Run: `flutter test test/widget/accessibility_test.dart`
Expected: PASS — confirms the new palette still clears `textContrastGuideline` everywhere the old teal/rust palette did (this file already exercises every current screen; no changes needed to it in this task).

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_colors.dart lib/core/theme/app_spacing.dart test/unit/theme/app_colors_test.dart
git commit -m "feat(theme): rewrite AppColors/AppShape for Immersive Golden Hour"
```

---

### Task 2: `Trip.coverPhotoPath` schema column + plumbing

**Files:**
- Modify: `lib/features/trips/data/trip_tables.dart:3-19` (the `Trips` table)
- Modify: `lib/core/database/app_database.dart:17-29` (schema history comment), `:56` (`schemaVersion`), `:68-80` (the trips migration block)
- Modify: `lib/features/trips/domain/trip.dart` (full file)
- Modify: `lib/features/trips/data/trip_repository.dart` (full file)
- Modify: `test/helpers/fake_trip_repository.dart` (full file)
- Modify: `test/unit/trips/trips_dao_test.dart:19-30` (the `create` helper) and append one test
- Test: `test/unit/trips/trips_migration_test.dart` (new)
- Regenerated (do not hand-edit): `lib/core/database/app_database.g.dart`, `lib/features/trips/data/trips_dao.g.dart`

**Interfaces:**
- Consumes: `AppColors`/`AppShape` from Task 1 are not used here — this task is DB/domain only.
- Produces: `Trip.coverPhotoPath` (`String?`), `Trip.copyWith({..., String? Function()? coverPhotoPath})`, `TripRepository.createTrip({..., String? coverPhotoPath})`. Phase 2's cover-photo picker UI and generated-gradient wiring read/write this field.

- [ ] **Step 1: Write the failing migration test**

Create `test/unit/trips/trips_migration_test.dart`:

```dart
import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';

/// Schema-bump rule (CLAUDE.md rule 5): every schema bump ships a
/// migration test. v13 adds Trips.coverPhotoPath.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The v12 trips table — before coverPhotoPath existed.
  const createV12Trips = '''
CREATE TABLE trips (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  start_date INTEGER,
  end_date INTEGER,
  color_tag INTEGER NOT NULL DEFAULT 0,
  archived INTEGER NOT NULL DEFAULT 0,
  completion_prompt_shown INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
)''';

  test(
      'v12 -> v13 adds coverPhotoPath to an existing trips table, null '
      '(= no photo, render the generated gradient), keeping existing rows',
      () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createV12Trips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(
      'INSERT INTO trips (id, name, color_tag, archived, '
      "completion_prompt_shown, created_at) "
      "VALUES ('t1', 'Thailand', 0, 0, 0, 0)",
    );

    await db.migration.onUpgrade(Migrator(db), 12, 13);

    final rows = await db
        .customSelect('SELECT name, cover_photo_path FROM trips')
        .get();
    expect(rows.single.read<String>('name'), 'Thailand');
    expect(rows.single.read<String?>('cover_photo_path'), isNull);
  });

  test(
      'v1 -> v13 (trips did not exist yet) creates the table at its '
      'current shape and does not also try to add coverPhotoPath a second '
      'time (same duplicate-column regression class the places v4->v12 '
      'migration test guards against)', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement('PRAGMA foreign_keys = ON');

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 1, 13),
      completes,
    );
    await db.customSelect('SELECT cover_photo_path FROM trips').get();
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/trips/trips_migration_test.dart`
Expected: FAIL — `no such column: cover_photo_path` (column doesn't exist yet).

- [ ] **Step 3: Add the column to the table definition**

In `lib/features/trips/data/trip_tables.dart`, replace lines 3-19:

```dart
@DataClassName('TripRow')
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get colorTag => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// "Trip over — mark places visited?" is offered exactly once (M3).
  BoolColumn get completionPromptShown =>
      boolean().withDefault(const Constant(false))();

  /// Path to a locally-stored cover photo (redesign spec §6). Null means
  /// no photo — render the generated gradient fallback instead.
  TextColumn get coverPhotoPath => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

- [ ] **Step 4: Bump the schema and add the migration step**

In `lib/core/database/app_database.dart`, insert after line 29 (the `///   v12 —` line):

```dart
///   v13 — Trips.coverPhotoPath (Immersive Golden Hour redesign;
///         generated-gradient fallback renders when this is null)
```

Change line 56 from `int get schemaVersion => 12;` to `int get schemaVersion => 13;`.

Replace the trips block at lines 68-80:

```dart
          if (from < 2) {
            await m.createTable(trips);
            await m.createTable(tripDestinations);
          } else {
            if (from == 2) {
              // Relax NOT NULL on dates — table recreation, data kept.
              await m.alterTable(TableMigration(trips));
            }
            if (from < 6) {
              await m.addColumn(trips, trips.completionPromptShown);
            }
            if (from < 13) {
              await m.addColumn(trips, trips.coverPhotoPath);
            }
          }
```

- [ ] **Step 5: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/core/database/app_database.g.dart` and `lib/features/trips/data/trips_dao.g.dart` regenerate with no errors; `TripRow` now has a `coverPhotoPath` field.

- [ ] **Step 6: Run the migration test again and confirm it passes**

Run: `flutter test test/unit/trips/trips_migration_test.dart`
Expected: PASS (both tests).

- [ ] **Step 7: Write the failing DAO roundtrip test**

In `test/unit/trips/trips_dao_test.dart`, replace the `create` helper (lines 19-30):

```dart
  Future<String> create({
    String name = 'Thailand',
    List<String> destinations = const ['Krabi', 'Ko Pha-ngan', 'Bangkok'],
    String? coverPhotoPath,
  }) {
    return repo.createTrip(
      name: name,
      destinations: destinations,
      startDate: DateTime(2026, 7, 16),
      endDate: DateTime(2026, 7, 27),
      colorTag: 2,
      coverPhotoPath: coverPhotoPath,
    );
  }
```

Then append this test at the end of `main()`, before the closing `});`:

```dart
  test('coverPhotoPath persists through create/update, defaults to null',
      () async {
    final id = await create();
    final trip = (await repo.getTrip(id))!;
    expect(trip.coverPhotoPath, isNull);

    await repo.updateTrip(
      trip.copyWith(coverPhotoPath: () => '/vault/covers/t1.jpg'),
    );
    final updated = (await repo.getTrip(id))!;
    expect(updated.coverPhotoPath, '/vault/covers/t1.jpg');
  });
```

- [ ] **Step 8: Run it and confirm it fails**

Run: `flutter test test/unit/trips/trips_dao_test.dart`
Expected: compile error — `createTrip` has no `coverPhotoPath` parameter, `Trip.copyWith` has no `coverPhotoPath` parameter.

- [ ] **Step 9: Add `coverPhotoPath` to the `Trip` domain class**

Replace the full contents of `lib/features/trips/domain/trip.dart`:

```dart
import 'package:flutter/foundation.dart';

/// planned  — no start date yet ("someday: Japan")
/// upcoming — starts in the future
/// active   — started; open-ended trips (no end date) stay active
/// past     — ended
enum TripStatus { active, upcoming, planned, past }

@immutable
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.destinations,
    this.startDate,
    this.endDate,
    this.colorTag = 0,
    this.archived = false,
    this.completionPromptShown = false,
    this.coverPhotoPath,
  }) : assert(
          startDate != null || endDate == null,
          'endDate requires startDate',
        );

  final String id;
  final String name;

  /// Ordered: Krabi -> Ko Pha-ngan -> Bangkok.
  final List<String> destinations;

  /// Both optional (SPEC: planned trips, one-way tickets).
  /// Date-only semantics — time components are ignored everywhere.
  final DateTime? startDate;
  final DateTime? endDate;

  final int colorTag;
  final bool archived;

  /// The one-time "trip over — mark places visited?" prompt was offered.
  final bool completionPromptShown;

  /// Path to a locally-stored cover photo. Null means no photo — render
  /// the generated gradient fallback instead (redesign spec §6).
  final String? coverPhotoPath;

  /// Inclusive length; null when open-ended or unplanned.
  int? get lengthInDays => (startDate == null || endDate == null)
      ? null
      : _dateOnly(endDate!).difference(_dateOnly(startDate!)).inDays + 1;

  /// 1-based day number for [today]; null when no start date.
  int? dayNumber(DateTime today) => startDate == null
      ? null
      : _dateOnly(today).difference(_dateOnly(startDate!)).inDays + 1;

  Trip copyWith({
    String? name,
    List<String>? destinations,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    int? colorTag,
    bool? archived,
    bool? completionPromptShown,
    String? Function()? coverPhotoPath,
  }) {
    return Trip(
      id: id,
      name: name ?? this.name,
      destinations: destinations ?? this.destinations,
      startDate: startDate == null ? this.startDate : startDate(),
      endDate: endDate == null ? this.endDate : endDate(),
      colorTag: colorTag ?? this.colorTag,
      archived: archived ?? this.archived,
      completionPromptShown:
          completionPromptShown ?? this.completionPromptShown,
      coverPhotoPath:
          coverPhotoPath == null ? this.coverPhotoPath : coverPhotoPath(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Trip &&
      other.id == id &&
      other.name == name &&
      listEquals(other.destinations, destinations) &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.colorTag == colorTag &&
      other.archived == archived &&
      other.coverPhotoPath == coverPhotoPath;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        Object.hashAll(destinations),
        startDate,
        endDate,
        colorTag,
        archived,
        coverPhotoPath,
      );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Buckets by calendar date, inclusive on both ends.
TripStatus bucketTrip(Trip trip, DateTime today) {
  final start = trip.startDate;
  if (start == null) return TripStatus.planned;
  final d = _dateOnly(today);
  if (d.isBefore(_dateOnly(start))) return TripStatus.upcoming;
  final end = trip.endDate;
  if (end != null && d.isAfter(_dateOnly(end))) return TripStatus.past;
  return TripStatus.active;
}

/// Days actually travelled across every non-archived trip (M5.6).
///
/// Counts only days that have happened: a past trip contributes its full
/// length, an active one contributes up to and including today, and
/// upcoming/planned trips contribute nothing — a "days travelled" figure
/// that counts a holiday you haven't taken yet isn't a trophy, it's a
/// forecast.
///
/// Overlapping trips are counted once. Two trips sharing a day is a data
/// entry quirk, but double-counting it would inflate the number in a way
/// that's impossible to explain looking at the list.
int daysTraveled(List<Trip> trips, DateTime today) {
  final days = <DateTime>{};
  final todayOnly = _dateOnly(today);
  for (final trip in trips) {
    if (trip.archived) continue;
    final start = trip.startDate;
    if (start == null) continue;
    var day = _dateOnly(start);
    if (day.isAfter(todayOnly)) continue; // hasn't begun
    // Open-ended trips are treated as running until today.
    final end = trip.endDate == null ? todayOnly : _dateOnly(trip.endDate!);
    final last = end.isAfter(todayOnly) ? todayOnly : end;
    while (!day.isAfter(last)) {
      days.add(day);
      day = DateTime(day.year, day.month, day.day + 1);
    }
  }
  return days.length;
}

/// Launch behavior (SPEC §3.1.1): exactly one active trip -> open it.
String? launchRedirectPath(List<Trip> trips, DateTime today) {
  final active = trips
      .where((t) => !t.archived && bucketTrip(t, today) == TripStatus.active)
      .toList();
  if (active.length == 1) return '/trips/${active.single.id}';
  return null;
}
```

- [ ] **Step 10: Thread `coverPhotoPath` through the repository**

Replace the full contents of `lib/features/trips/data/trip_repository.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/trip.dart';
import 'trips_dao.dart';

/// Widget tests mock at this boundary (testing rules).
abstract interface class TripRepository {
  Stream<List<Trip>> watchTrips();
  Future<Trip?> getTrip(String id);
  Future<String> createTrip({
    required String name,
    required List<String> destinations,
    DateTime? startDate,
    DateTime? endDate,
    required int colorTag,
    String? coverPhotoPath,
  });
  Future<void> updateTrip(Trip trip);
  Future<void> setArchived(String id, {required bool archived});
  Future<void> markCompletionPromptShown(String id);
  Future<void> deleteTrip(String id);
}

class DriftTripRepository implements TripRepository {
  DriftTripRepository(this._dao, this._clock);

  final TripsDao _dao;
  final DateTime Function() _clock;
  final _uuid = const Uuid();

  @override
  Stream<List<Trip>> watchTrips() =>
      _dao.watchAll().map((rows) => rows.map(_toDomain).toList());

  @override
  Future<Trip?> getTrip(String id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<String> createTrip({
    required String name,
    required List<String> destinations,
    DateTime? startDate,
    DateTime? endDate,
    required int colorTag,
    String? coverPhotoPath,
  }) async {
    final id = _uuid.v4();
    await _dao.insertTrip(
      TripRow(
        id: id,
        name: name.trim(),
        startDate: startDate,
        endDate: endDate,
        colorTag: colorTag,
        archived: false,
        completionPromptShown: false,
        coverPhotoPath: coverPhotoPath,
        createdAt: _clock(),
      ),
      _destinationRows(id, destinations),
    );
    return id;
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    final existing = await _dao.getById(trip.id);
    if (existing == null) return;
    await _dao.updateTrip(
      existing.trip.copyWith(
        name: trip.name.trim(),
        startDate: Value(trip.startDate),
        endDate: Value(trip.endDate),
        colorTag: trip.colorTag,
        archived: trip.archived,
        coverPhotoPath: Value(trip.coverPhotoPath),
      ),
      _destinationRows(trip.id, trip.destinations),
    );
  }

  @override
  Future<void> setArchived(String id, {required bool archived}) =>
      _dao.setArchived(id, archived);

  @override
  Future<void> markCompletionPromptShown(String id) =>
      _dao.setCompletionPromptShown(id);

  @override
  Future<void> deleteTrip(String id) => _dao.deleteTrip(id);

  List<TripDestinationRow> _destinationRows(
    String tripId,
    List<String> destinations,
  ) {
    final cleaned =
        destinations.map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    return [
      for (var i = 0; i < cleaned.length; i++)
        TripDestinationRow(
          id: _uuid.v4(),
          tripId: tripId,
          name: cleaned[i],
          orderIndex: i,
        ),
    ];
  }

  Trip _toDomain(TripWithDestinations row) => Trip(
        id: row.trip.id,
        name: row.trip.name,
        destinations: [for (final d in row.destinations) d.name],
        startDate: row.trip.startDate,
        endDate: row.trip.endDate,
        colorTag: row.trip.colorTag,
        archived: row.trip.archived,
        completionPromptShown: row.trip.completionPromptShown,
        coverPhotoPath: row.trip.coverPhotoPath,
      );
}
```

- [ ] **Step 11: Update the fake repository test helper**

Replace the full contents of `test/helpers/fake_trip_repository.dart`:

```dart
import 'dart:async';

import 'package:tripper/features/trips/data/trip_repository.dart';
import 'package:tripper/features/trips/domain/trip.dart';

/// Fake at the repository boundary (testing rules — no DB in widget tests).
class FakeTripRepository implements TripRepository {
  FakeTripRepository(this._trips);

  final List<Trip> _trips;
  final _controller = StreamController<List<Trip>>.broadcast();

  void emit(List<Trip> trips) {
    _trips
      ..clear()
      ..addAll(trips);
    _controller.add(List.of(trips));
  }

  /// M4.2 states audit — lets a test simulate a stream failure without a
  /// real DB error. A fresh subscription (e.g. after `ref.invalidate`)
  /// doesn't replay this — it just re-reads current state, which is what
  /// makes a "retry" button meaningful to test.
  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<Trip>> watchTrips() async* {
    yield List.of(_trips);
    yield* _controller.stream;
  }

  @override
  Future<Trip?> getTrip(String id) async =>
      _trips.where((t) => t.id == id).firstOrNull;

  @override
  Future<String> createTrip({
    required String name,
    required List<String> destinations,
    DateTime? startDate,
    DateTime? endDate,
    required int colorTag,
    String? coverPhotoPath,
  }) async {
    final trip = Trip(
      id: 'fake-${_trips.length}',
      name: name,
      destinations: destinations,
      startDate: startDate,
      endDate: endDate,
      colorTag: colorTag,
      coverPhotoPath: coverPhotoPath,
    );
    emit([..._trips, trip]);
    return trip.id;
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    emit([
      for (final t in _trips)
        if (t.id == trip.id) trip else t,
    ]);
  }

  @override
  Future<void> setArchived(String id, {required bool archived}) async {
    emit([
      for (final t in _trips)
        if (t.id == id) t.copyWith(archived: archived) else t,
    ]);
  }

  @override
  Future<void> markCompletionPromptShown(String id) async {
    emit([
      for (final t in _trips)
        if (t.id == id) t.copyWith(completionPromptShown: true) else t,
    ]);
  }

  @override
  Future<void> deleteTrip(String id) async {
    emit([..._trips.where((t) => t.id != id)]);
  }
}
```

- [ ] **Step 12: Run the DAO test again and confirm it passes**

Run: `flutter test test/unit/trips/trips_dao_test.dart`
Expected: PASS (all tests, including the new one).

- [ ] **Step 13: Run the full trips test folder**

Run: `flutter test test/unit/trips`
Expected: PASS — confirms `trip_bucketer_test.dart`, `trip_validator_test.dart`, `days_traveled_test.dart`, `trip_notifications_test.dart` are unaffected.

- [ ] **Step 14: Commit**

```bash
git add lib/features/trips/data/trip_tables.dart lib/core/database/app_database.dart lib/core/database/app_database.g.dart lib/features/trips/data/trips_dao.g.dart lib/features/trips/domain/trip.dart lib/features/trips/data/trip_repository.dart test/helpers/fake_trip_repository.dart test/unit/trips/trips_dao_test.dart test/unit/trips/trips_migration_test.dart
git commit -m "feat(trips): add Trip.coverPhotoPath (schema v13)"
```

---

### Task 3: Generated cover-gradient helper

**Files:**
- Create: `lib/core/theme/generated_cover_gradient.dart`
- Test: `test/unit/theme/generated_cover_gradient_test.dart` (new)

**Interfaces:**
- Consumes: `AppColors.heroGradientStart`/`heroGradientEnd` (Task 1).
- Produces: `LinearGradient generatedCoverGradient(String tripId, AppColors colors)` — Phase 2's Trips-list/Trip-detail cover widgets call this whenever `Trip.coverPhotoPath` (Task 2) is null.

- [ ] **Step 1: Write the failing test**

Create `test/unit/theme/generated_cover_gradient_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/generated_cover_gradient.dart';

void main() {
  test(
      'same trip id always produces the same gradient (deterministic, no '
      'randomness — must work fully offline)', () {
    final a = generatedCoverGradient('trip-123', AppColors.dark);
    final b = generatedCoverGradient('trip-123', AppColors.dark);
    expect(a.begin, b.begin);
    expect(a.end, b.end);
    expect(a.colors, b.colors);
  });

  test(
      'different trip ids produce more than one distinct angle across a '
      'sample set', () {
    final sampleIds = List.generate(20, (i) => 'trip-$i');
    final begins = sampleIds
        .map((id) => generatedCoverGradient(id, AppColors.dark).begin)
        .toSet();
    expect(begins.length, greaterThan(1));
  });

  test(
      'only ever uses the two tracked hero-gradient tokens — never invents '
      'a new hue (component rule 2: gradients are scoped)', () {
    final gradient = generatedCoverGradient('trip-abc', AppColors.light);
    expect(gradient.colors, [
      AppColors.light.heroGradientStart,
      AppColors.light.heroGradientEnd,
    ]);
  });

  test('begin and end are always opposite corners', () {
    final gradient = generatedCoverGradient('trip-xyz', AppColors.dark);
    final begin = gradient.begin as Alignment;
    final end = gradient.end as Alignment;
    expect(end.x, -begin.x);
    expect(end.y, -begin.y);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/theme/generated_cover_gradient_test.dart`
Expected: compile error — `generatedCoverGradient` doesn't exist yet.

- [ ] **Step 3: Implement the helper**

Create `lib/core/theme/generated_cover_gradient.dart`:

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A deterministic gradient fallback for a trip with no cover photo
/// (redesign spec §6). The same trip id always produces the same
/// gradient — no randomness, no network, fully available offline
/// (SPEC §3.1.2/§3.1.3). Only ever uses the two tracked hero-gradient
/// tokens (component rule 2: gradients are scoped, never inventing an
/// untracked hue).
LinearGradient generatedCoverGradient(String tripId, AppColors colors) {
  const corners = [
    Alignment.topLeft,
    Alignment.topCenter,
    Alignment.topRight,
    Alignment.centerLeft,
  ];
  final begin = corners[tripId.hashCode.abs() % corners.length];
  final end = Alignment(-begin.x, -begin.y);
  return LinearGradient(
    begin: begin,
    end: end,
    colors: [colors.heroGradientStart, colors.heroGradientEnd],
  );
}
```

- [ ] **Step 4: Run the test again and confirm it passes**

Run: `flutter test test/unit/theme/generated_cover_gradient_test.dart`
Expected: PASS (all four tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/generated_cover_gradient.dart test/unit/theme/generated_cover_gradient_test.dart
git commit -m "feat(theme): add generated cover-gradient fallback helper"
```

---

### Task 4: `GlassChrome` primitive widget

**Files:**
- Create: `lib/core/widgets/glass_chrome.dart`
- Test: `test/widget/core/glass_chrome_test.dart` (new)

**Interfaces:**
- Consumes: `context.colors` (`AppColorsX`, Task 1), `AppShape.hairlineWidth`.
- Produces: `class GlassChrome extends StatelessWidget` with `{required Widget child, BorderRadius borderRadius = BorderRadius.zero}` — Phase 2's Trip-detail glass topbar/tab bar and Phase 3's Places glass filter chips wrap their content in this.

- [ ] **Step 1: Write the failing widget test**

Create `test/widget/core/glass_chrome_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/glass_chrome.dart';

void main() {
  testWidgets('renders its child inside a blurred backdrop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: GlassChrome(child: Text('Places')),
        ),
      ),
    );

    expect(find.text('Places'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('surface is translucent, not solid — reads as glass',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: GlassChrome(child: SizedBox()),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color!.a, closeTo(0.55, 0.01));
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/core/glass_chrome_test.dart`
Expected: compile error — `GlassChrome` doesn't exist yet.

- [ ] **Step 3: Implement the widget**

Create `lib/core/widgets/glass_chrome.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Blurred glass chrome for nav/tab/top bars sitting over a photo or
/// gradient hero (redesign spec §4, component rule 3). Never use this for
/// regular content cards — those stay solid ([PaperCard]) for reliable
/// contrast and cheap repaint.
class GlassChrome extends StatelessWidget {
  const GlassChrome({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.55),
            borderRadius: borderRadius,
            border: Border.all(
              color: colors.hairline,
              width: AppShape.hairlineWidth,
            ),
            boxShadow: [
              // Tinted with the app's own dark tone, never a flat
              // gray/black — this is the one place in the redesign
              // shadows are allowed at all (glass-over-imagery only,
              // component rule 3 / spec §3.4).
              BoxShadow(
                color: AppColors.dark.paper.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test again and confirm it passes**

Run: `flutter test test/widget/core/glass_chrome_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/glass_chrome.dart test/widget/core/glass_chrome_test.dart
git commit -m "feat(widgets): add GlassChrome primitive"
```

---

### Task 5: Rewrite governance docs (CLAUDE.md rules 1 & 6, SPEC.md §4)

**Files:**
- Modify: `CLAUDE.md` (hard rules 1 and 6)
- Modify: `docs/SPEC.md:141-174` (§4 Design system)

**Interfaces:** None — documentation only. This task must land after Tasks 1-4 so the docs describe tokens/primitives that actually exist in code (spec §7: docs change alongside code, not ahead of it).

- [ ] **Step 1: Rewrite CLAUDE.md hard rules 1 and 6**

In `CLAUDE.md`, replace rule 1:

```
1. No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`. One accent only — coral (`AppColors.accent`) for actions, active states, and "want to go" pins/dots. Amber (`AppColors.warning`) is reserved for expiry/danger-adjacent warnings only — never a second accent. Gradients are allowed but scoped to hero/cover-photo scrims and generated trip-cover art only — never buttons, text backgrounds, or flat surfaces. Full token tables: `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md` §3.
```

Replace rule 6:

```
6. Visual language ("Immersive Golden Hour" — `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md`): serif (Fraunces) for names/titles, mono (IBM Plex Mono, uppercase) for dates/codes/metadata. Solid content cards keep hairline borders and no shadow (`PaperCard`). Glass/blur chrome (`GlassChrome`) is reserved for nav/tab/top bars sitting over a photo or gradient hero — never for regular content cards. `PaperCard`/`SectionLabel`/`MonoText`/`EmptyState`/`GlassChrome` primitives from `lib/core/widgets/`.
```

- [ ] **Step 2: Rewrite SPEC.md §4**

In `docs/SPEC.md`, replace lines 141-174 (the full `## 4. Design system` section through the end of §4.4, up to but not including `## 5. Technical architecture`):

```markdown
## 4. Design system

### 4.1 Direction

"Immersive Golden Hour" — cinematic, photo-forward, dark-first. Trip
covers (real photos, or a generated gradient when none is set) are the
emotional anchor of the app instead of staying text/data-forward. Glass
(blurred) chrome floats over photography for navigation; content below
the fold stays on solid, calm surfaces. The "boarding pass" data
discipline — mono metadata, hairline dividers, serif titles — survives
underneath the new skin. Full rationale and screen-by-screen breakdown:
`docs/superpowers/specs/2026-08-14-tripper-redesign-design.md`.

### 4.2 Color tokens

| Token | Dark | Light | Use |
|---|---|---|---|
| `paper` | `#12141C` | `#FAF3EC` | App background |
| `surface` | `#1C1F2B` | `#FFFFFF` | Solid content cards (non-glass) |
| `inkPrimary` | `#F5F1EA` | `#1B1A22` | Primary text |
| `inkSecondary` | `#A9AEBD` | `#403F47`\* | Secondary text, timestamps |
| `inkMuted` | `#6E7386` | `#56525D`\* | Placeholder, disabled |
| `hairline` | `rgba(255,255,255,.08)` | `#E7E1D8` | Borders on solid cards |
| `accent` (coral) | `#FF6B5E` | `#A23F37`\* | The one accent — CTAs, active states, "want to go" pins/dots |
| `warning` (amber) | `#F2A93C` | `#8D5513`\* | Expiry/danger-adjacent warnings only. Also reused for map labels |
| `success` | `#34D399` | `#1F9A6E` | Confirmations only |
| `error` | `#E5484D` | `#C23B34` | Real errors/validation only |
| `heroGradientStart`/`heroGradientEnd` | `#171A2E` → `#FF6B5E` | `#FAF3EC` → `#A23F37`\* | Cover scrims and generated trip-cover art only |
| `mapWater`/`mapLand` | `#17263c`/`#242f3e` | `#DCEAE6`/`#EFE7D8` | Map style base |

\* Light-mode `accent`, `warning`, `inkMuted`, `inkSecondary` (and
`heroGradientEnd`, which mirrors `accent`) were darkened from the original
mockup values during Task 1's implementation — the originals
(`#E85A4E`/`#C97A1B`/`#8A8894`/`#5B5A66`) failed WCAG AA 4.5:1 text contrast
against real rendered UI (`accessibility_test.dart`), which per component
rule 6 ("contrast is non-negotiable") outranks the un-audited mockup hex.

Rule: **one accent, total, in the entire app.** Amber is reserved
exclusively for warnings and never doubles as a second accent. Named
brand hues: three (night, coral, amber), plus the two utility colors
(success/error) every app needs. Dark is the primary mode; light is a
fully-designed true alternate (not a mechanical inversion) — both ship
from day one.

### 4.3 Typography

Unchanged from the original field-journal system:
- **Headings:** `Fraunces` (serif) — titles, trip names, hero headings
- **Body/UI:** `IBM Plex Sans` — body, buttons, UI labels
- **Data/codes:** `IBM Plex Mono`, uppercase-tracked — dates, codes,
  coordinates, stats, kickers
- 5-size type scale (display, title, body, label, caption); weight
  carries hierarchy more than size does.

### 4.4 Component principles

- **One accent, not two.** Coral does all interactive/active/CTA work.
  Amber is warnings-only.
- **Gradients are scoped, not banned.** Only on hero/cover-photo scrims
  and generated trip-cover art. Never on buttons, text backgrounds, or
  flat surfaces.
- **Glass/blur is for chrome over imagery only** — nav bars, tab bars,
  top bars sitting on a photo or gradient hero (`GlassChrome`). Regular
  content cards stay solid (`PaperCard`) for reliable contrast and cheap
  repaint — no shadow.
- **Hairline borders survive** on solid cards, recolored per token table
  above — keeps the "printed, not app-y" feel under the new skin.
- **Two pin/marker states, one accent** — coral+glow = want-to-go, muted
  parchment/grey = been-there. Applies identically to map pins and the
  journal globe's dots.
- **Contrast is non-negotiable.** Every text-on-photo/gradient moment
  gets a scrim strong enough to hit WCAG AA.
- **Icons** stay outline, single-weight, ink-colored by default; coral
  only for active nav/pin states.
- Corner radius: 14px on cards/sheets, full-pill on chips/tab indicators,
  circular on FABs/glass buttons.
- Empty states are illustrated sparingly with line art, optionally with a
  soft coral-tinted glow behind the icon; CTA button in coral.
```

- [ ] **Step 3: Sanity-check the rule 1 enforcement point is unchanged**

Run: `grep -rn "Color(0xFF" lib --include=*.dart | grep -v "lib/core/theme/app_colors.dart"`
Expected: no output (empty) — confirms `app_colors.dart` is still the only file with raw color literals after Tasks 1-4.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/SPEC.md
git commit -m "docs: codify Immersive Golden Hour rules in CLAUDE.md and SPEC.md §4"
```
