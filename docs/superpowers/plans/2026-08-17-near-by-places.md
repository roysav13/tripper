# Near By Places Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user search for highly-rated places near their current position or a saved place (e.g. a hotel), see a Wikipedia summary to help decide, and add a result to the wishlist — optionally tagged with a trip day.

**Architecture:** A new `NearbyPlacesFetcher` (Google Places API (New) `searchNearby`, same client/exception/timeout conventions as the existing `GooglePlacesGeocoder`) sits behind a settings toggle (off by default) and a session-scoped, in-memory TTL cache. Results are filtered/sorted client-side ("high rated": `rating >= 4.0 && userRatingCount >= 5`) and rendered on a new pull-based results screen reached from a new entry point on `PlacesScreen`/`TripPlacesTab`. A detail sheet lazily fetches the existing `WikipediaPlaceSummaryFetcher` summary and, on save, creates a normal `Place` via the existing `PlaceRepository` — no rating data is persisted. `Place` gains one new nullable field, `plannedDate`, surfaced only from this flow's detail sheet and rendered as a read-only "DAY N" chip elsewhere.

**Tech Stack:** Flutter, Riverpod (`Provider`, `NotifierProvider`, `ConsumerStatefulWidget`), Drift (schema v14 → v15), `package:http`, hand-maintained ARB + generated localization files (this sandbox cannot run `flutter gen-l10n`).

**Spec:** `docs/superpowers/specs/2026-08-17-near-by-places-design.md`

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`; only `AppColors.accent` (coral) as the one accent (CLAUDE.md rule 1).
- No `DateTime.now()` in domain/data code — inject via `clockProvider` (CLAUDE.md rule 2).
- Every user-facing string goes through `lib/l10n/app_en.arb`, mirrored into `app_he.arb` with a real Hebrew translation (this repo keeps the two in 1:1 sync — verified: both currently have exactly 277 keys). Since `flutter gen-l10n` cannot run in this sandbox, `lib/l10n/app_localizations.dart` (abstract getter + doc comment), `app_localizations_en.dart`, and `app_localizations_he.dart` (implementations) must all be hand-edited to match, in the exact style already used for every existing key.
- Local data is always the source of truth; the network path here is pull-based (an explicit "Find nearby" tap, never auto-fetch) and must degrade to a visible `ErrorState`/`EmptyState`, never a hanging spinner (CLAUDE.md rule 4).
- Every Drift schema bump ships a migration test; widget tests mock at the repository/fetcher boundary; no real network calls in tests (CLAUDE.md rule 5).
- `PaperCard` for solid content rows; `GlassChrome` is not used anywhere in this feature (no photo/gradient hero, not the Places filter sheet).
- Nothing in this plan revives the withdrawn Plan/itinerary tab (`docs/adr/ADR-001-itinerary-redesign.md`) — `plannedDate` is a single nullable field and a read-only chip, nothing else.

---

## Task 1: Settings — nearby toggle + call counter

**Files:**
- Modify: `lib/core/settings/settings_service.dart`
- Test: `test/unit/settings/settings_service_test.dart`

**Interfaces:**
- Produces: `nearbyPlacesEnabledProvider` (`NotifierProvider<NearbyPlacesEnabledController, bool>`), `NearbyPlacesEnabledController.set({required bool enabled})`; `nearbyApiCallCountProvider` (`NotifierProvider<NearbyApiCallCountController, int>`), `NearbyApiCallCountController.increment()`. Both read/write via the existing `sharedPreferencesProvider`.

- [ ] **Step 1: Write the failing tests**

Append to `test/unit/settings/settings_service_test.dart` (inside `main()`, after the existing tests, before the closing `}`):

```dart
  test('nearby places is off by default', () async {
    final container = await containerWith({});
    expect(container.read(nearbyPlacesEnabledProvider), isFalse);
  });

  test('nearby places toggle persists', () async {
    final container = await containerWith({});
    await container
        .read(nearbyPlacesEnabledProvider.notifier)
        .set(enabled: true);
    expect(container.read(nearbyPlacesEnabledProvider), isTrue);
    expect(
      container
          .read(sharedPreferencesProvider)
          .getBool('nearby_places_enabled'),
      isTrue,
    );
  });

  test('stored nearby places toggle is restored', () async {
    final container =
        await containerWith({'nearby_places_enabled': true});
    expect(container.read(nearbyPlacesEnabledProvider), isTrue);
  });

  test('nearby API call count defaults to zero and persists increments',
      () async {
    final container = await containerWith({});
    expect(container.read(nearbyApiCallCountProvider), 0);

    await container.read(nearbyApiCallCountProvider.notifier).increment();
    await container.read(nearbyApiCallCountProvider.notifier).increment();

    expect(container.read(nearbyApiCallCountProvider), 2);
    expect(
      container
          .read(sharedPreferencesProvider)
          .getInt('nearby_api_call_count'),
      2,
    );
  });

  test('stored nearby API call count is restored', () async {
    final container =
        await containerWith({'nearby_api_call_count': 7});
    expect(container.read(nearbyApiCallCountProvider), 7);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/settings/settings_service_test.dart`
Expected: FAIL — `nearbyPlacesEnabledProvider`/`nearbyApiCallCountProvider` undefined.

- [ ] **Step 3: Implement the providers**

In `lib/core/settings/settings_service.dart`, add two new storage keys near the top (after `_kAppLocale`):

```dart
const _kNearbyPlacesEnabled = 'nearby_places_enabled';
const _kNearbyApiCallCount = 'nearby_api_call_count';
```

Then append, after the final comment block at the bottom of the file:

```dart
/// Master gate for the Near By feature (M5-phase2a §5.10) — off by
/// default, since this is the one feature in the app that always costs a
/// real network call and has no offline value. Every nearby-fetch code
/// path checks this itself (not just the UI that shows/hides the entry
/// point), so "off" is a real guarantee.
class NearbyPlacesEnabledController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kNearbyPlacesEnabled) ??
      false;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kNearbyPlacesEnabled, enabled);
  }
}

final nearbyPlacesEnabledProvider =
    NotifierProvider<NearbyPlacesEnabledController, bool>(
  NearbyPlacesEnabledController.new,
);

/// Lifetime count of real `searchNearby` HTTP calls this install has made
/// — incremented once per real fetch, never on a cache hit. No reset
/// action in v1; shown in Settings so a cost is visible before it's a
/// surprise, not to budget against.
class NearbyApiCallCountController extends Notifier<int> {
  @override
  int build() =>
      ref.read(sharedPreferencesProvider).getInt(_kNearbyApiCallCount) ?? 0;

  Future<void> increment() async {
    state = state + 1;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_kNearbyApiCallCount, state);
  }
}

final nearbyApiCallCountProvider =
    NotifierProvider<NearbyApiCallCountController, int>(
  NearbyApiCallCountController.new,
);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/settings/settings_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/settings/settings_service.dart test/unit/settings/settings_service_test.dart
git commit -m "feat(settings): add nearby-places toggle and API call counter"
```

---

## Task 2: Settings screen — Nearby places section

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_he.arb`, `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_he.dart`
- Test: `test/widget/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: `nearbyPlacesEnabledProvider`, `nearbyApiCallCountProvider` (Task 1); `kGoogleMapsApiKey` (`lib/features/places/data/google_places_geocoder.dart`, already exists).

- [ ] **Step 1: Add ARB keys**

In `lib/l10n/app_en.arb`, insert after the `"settingsExpiryNoticeOff": "Off",` line (currently line 327), before `"docExpiryNotificationTitle"`:

```json
  "settingsNearbyPlaces": "Nearby places",
  "settingsNearbyPlacesHint": "Find highly-rated places near you or a saved spot, right from the Places tab.",
  "settingsNearbyPlacesCallCount": "{count, plural, one{1 lookup this install} other{{count} lookups this install}}",
  "@settingsNearbyPlacesCallCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "settingsNearbyPlacesNoKey": "Requires a Maps API key to be configured",
```

In `lib/l10n/app_he.arb`, insert the matching Hebrew block at the same position (after the Hebrew `settingsExpiryNoticeOff` entry):

```json
  "settingsNearbyPlaces": "מקומות בקרבת מקום",
  "settingsNearbyPlacesHint": "מצא מקומות מדורגים גבוה בקרבתך או ליד מקום שמור, ישירות מלשונית המקומות.",
  "settingsNearbyPlacesCallCount": "{count, plural, one{חיפוש אחד בהתקנה זו} other{{count} חיפושים בהתקנה זו}}",
  "@settingsNearbyPlacesCallCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "settingsNearbyPlacesNoKey": "דורש הגדרת מפתח Maps API",
```

In `lib/l10n/app_localizations.dart`, add the matching abstract getters right after the existing `settingsExpiryNoticeOff` getter (search for `String get settingsExpiryNoticeOff;`):

```dart
  /// No description provided for @settingsNearbyPlaces.
  ///
  /// In en, this message translates to:
  /// **'Nearby places'**
  String get settingsNearbyPlaces;

  /// No description provided for @settingsNearbyPlacesHint.
  ///
  /// In en, this message translates to:
  /// **'Find highly-rated places near you or a saved spot, right from the Places tab.'**
  String get settingsNearbyPlacesHint;

  /// No description provided for @settingsNearbyPlacesCallCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 lookup this install} other{{count} lookups this install}}'**
  String settingsNearbyPlacesCallCount(int count);

  /// No description provided for @settingsNearbyPlacesNoKey.
  ///
  /// In en, this message translates to:
  /// **'Requires a Maps API key to be configured'**
  String get settingsNearbyPlacesNoKey;
```

In `lib/l10n/app_localizations_en.dart`, add the implementations right after `String get settingsExpiryNoticeOff => 'Off';`:

```dart
  @override
  String get settingsNearbyPlaces => 'Nearby places';

  @override
  String get settingsNearbyPlacesHint =>
      'Find highly-rated places near you or a saved spot, right from the Places tab.';

  @override
  String settingsNearbyPlacesCallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      one: '1 lookup this install',
      other: '$count lookups this install',
    );
    return _temp0;
  }

  @override
  String get settingsNearbyPlacesNoKey =>
      'Requires a Maps API key to be configured';
```

(Match the exact `intl.Intl.pluralLogic` shape already used by `placesFilterShowResults` in the same file — copy that method's structure, not freehand.)

In `lib/l10n/app_localizations_he.dart`, add the implementations right after the Hebrew `settingsExpiryNoticeOff` getter:

```dart
  @override
  String get settingsNearbyPlaces => 'מקומות בקרבת מקום';

  @override
  String get settingsNearbyPlacesHint =>
      'מצא מקומות מדורגים גבוה בקרבתך או ליד מקום שמור, ישירות מלשונית המקומות.';

  @override
  String settingsNearbyPlacesCallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      one: 'חיפוש אחד בהתקנה זו',
      other: '$count חיפושים בהתקנה זו',
    );
    return _temp0;
  }

  @override
  String get settingsNearbyPlacesNoKey => 'דורש הגדרת מפתח Maps API';
```

- [ ] **Step 2: Write the failing widget tests**

Append to `test/widget/settings/settings_screen_test.dart` (add imports for `tripper/features/places/data/google_places_geocoder.dart` is not needed — the test only asserts on rendered text/switch state):

```dart
  testWidgets('nearby places toggle defaults off and switches on',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    final toggle = find.widgetWithText(SwitchListTile, 'Nearby places');
    expect(toggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(SettingsScreen));
    final container = ProviderScope.containerOf(element);
    expect(container.read(nearbyPlacesEnabledProvider), isTrue);
  });

  testWidgets('nearby places call count subtitle reflects stored count',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          await testPreferencesOverride({'nearby_api_call_count': 3}),
          biometricAuthenticatorProvider.overrideWithValue((_) async => true),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('he')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 lookups this install'), findsOneWidget);
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/widget/settings/settings_screen_test.dart`
Expected: FAIL — no `SwitchListTile` with text "Nearby places" yet.

- [ ] **Step 4: Implement the settings section**

In `lib/features/settings/presentation/settings_screen.dart`, add an import:

```dart
import '../../places/data/google_places_geocoder.dart' show kGoogleMapsApiKey;
```

In `_SettingsScreenState.build`, add two new `ref.watch` calls near the top (after `final noticeDays = ...`):

```dart
    final nearbyEnabled = ref.watch(nearbyPlacesEnabledProvider);
    final nearbyCallCount = ref.watch(nearbyApiCallCountProvider);
```

Insert a new section into the `ListView`'s `children`, after the Notifications section's `SegmentedButton<int>` block and before the `SectionLabel(l10n.settingsHomeCurrency)` block:

```dart
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.settingsNearbyPlaces),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.settingsNearbyPlacesHint,
            style: TextStyle(fontSize: 13, color: colors.inkSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsNearbyPlaces),
            subtitle: Text(
              kGoogleMapsApiKey.isEmpty
                  ? l10n.settingsNearbyPlacesNoKey
                  : l10n.settingsNearbyPlacesCallCount(nearbyCallCount),
              style: TextStyle(fontSize: 12, color: colors.inkMuted),
            ),
            value: nearbyEnabled,
            activeTrackColor: colors.accent,
            onChanged: kGoogleMapsApiKey.isEmpty
                ? null
                : (value) => ref
                    .read(nearbyPlacesEnabledProvider.notifier)
                    .set(enabled: value),
          ),
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/widget/settings/settings_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/settings_screen.dart lib/l10n/ test/widget/settings/settings_screen_test.dart
git commit -m "feat(settings): surface the nearby-places toggle and call counter"
```

---

## Task 3: `Place.plannedDate` domain field

**Files:**
- Modify: `lib/features/places/domain/place.dart`
- Test: `test/unit/places/place_domain_test.dart`

**Interfaces:**
- Produces: `Place.plannedDate` (`DateTime?`), threaded through `copyWith`/`==`/`hashCode`.

- [ ] **Step 1: Write the failing tests**

Append to `test/unit/places/place_domain_test.dart`, inside `main()`:

```dart
  group('Place plannedDate', () {
    test('defaults to null', () {
      const place = Place(id: 'p1', name: 'Test');
      expect(place.plannedDate, isNull);
    });

    test('copyWith sets and clears plannedDate', () {
      const place = Place(id: 'p1', name: 'Test');
      final planned =
          place.copyWith(plannedDate: () => DateTime(2026, 8, 20));
      expect(planned.plannedDate, DateTime(2026, 8, 20));

      final cleared = planned.copyWith(plannedDate: () => null);
      expect(cleared.plannedDate, isNull);
    });

    test('equality includes plannedDate', () {
      final a = Place(
        id: 'p1',
        name: 'Test',
        plannedDate: DateTime(2026, 8, 20),
      );
      final b = Place(
        id: 'p1',
        name: 'Test',
        plannedDate: DateTime(2026, 8, 20),
      );
      final c = Place(
        id: 'p1',
        name: 'Test',
        plannedDate: DateTime(2026, 8, 21),
      );
      expect(a, b);
      expect(a, isNot(c));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/places/place_domain_test.dart`
Expected: FAIL — `plannedDate` is not a named parameter of `Place`.

- [ ] **Step 3: Implement the field**

In `lib/features/places/domain/place.dart`, add to the constructor parameter list (after `this.summaryFetchedAt,`):

```dart
    this.plannedDate,
```

Add the field declaration (after `final DateTime? summaryFetchedAt;`):

```dart
  /// Which day of the trip this place is intended for — a deliberately
  /// minimal successor to the withdrawn Plan tab
  /// (docs/adr/ADR-001-itinerary-redesign.md): no time, no ordering, no
  /// derived anchors. Only ever set via the Near By add flow in this
  /// round; editing it from the general place editor is a later, separate
  /// decision.
  final DateTime? plannedDate;
```

Add to `copyWith`'s parameter list (after `DateTime? Function()? summaryFetchedAt,`):

```dart
    DateTime? Function()? plannedDate,
```

Add to the `Place(...)` constructor call inside `copyWith` (after `summaryFetchedAt: ...`):

```dart
      plannedDate: plannedDate == null ? this.plannedDate : plannedDate(),
```

Add to `operator ==` (after `other.summaryFetchedAt == summaryFetchedAt &&`, note the `&&` needs moving to the new last line):

```dart
      other.plannedDate == plannedDate;
```

Add to `hashCode`'s `Object.hash(...)` argument list (after `summaryFetchedAt,`):

```dart
        plannedDate,
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/places/place_domain_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/places/domain/place.dart test/unit/places/place_domain_test.dart
git commit -m "feat(places): add Place.plannedDate domain field"
```

---

## Task 4: Places table `plannedDate` column + v15 migration

**Files:**
- Modify: `lib/features/places/data/place_tables.dart`
- Modify: `lib/core/database/app_database.dart`
- Test: `test/unit/places/places_migration_test.dart`

**Interfaces:**
- Produces: `Places.plannedDate` Drift column (nullable `DateTimeColumn`), `AppDatabase.schemaVersion == 15`.

- [ ] **Step 1: Write the failing migration tests**

Append to `test/unit/places/places_migration_test.dart`, inside `main()`, before the closing `}`. First add a new fixture constant near the other `createV*Places` constants (after `createV12Places`):

```dart
  /// The v14 places table — summary/summaryFetchedAt added, before
  /// plannedDate existed.
  const createV14Places = '''
CREATE TABLE places (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  lat REAL,
  lng REAL,
  country TEXT NOT NULL DEFAULT '',
  city TEXT NOT NULL DEFAULT '',
  status INTEGER NOT NULL,
  visited_at INTEGER,
  trip_id TEXT REFERENCES trips (id) ON DELETE SET NULL,
  notes TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  category INTEGER,
  summary TEXT,
  summary_fetched_at INTEGER
)''';
```

Then add the tests:

```dart
  test(
      'v14 -> v15 adds the planned_date column to an existing table, null '
      '(= not assigned to a day), keeping existing rows', () async {
    await db.customStatement('DROP TABLE places');
    await db.customStatement(createV14Places);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createPreCoverPhotoTrips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(insertTrip);
    await db.customStatement(
      'INSERT INTO places (id, name, country, city, status, notes, '
      "created_at, category) VALUES ('p1', 'Railay', 'Thailand', 'Krabi', "
      "0, '', 0, 1)",
    );

    await db.migration.onUpgrade(Migrator(db), 14, 15);

    final rows = await db
        .customSelect('SELECT name, planned_date FROM places')
        .get();
    expect(rows.single.read<String>('name'), 'Railay');
    expect(rows.single.read<int?>('planned_date'), isNull);
  });

  test(
      'v4 -> v15 in one jump does NOT try to add a column to a table it '
      'just created (same class of bug as the v4->v12/v4->v14 cases above)',
      () async {
    await db.customStatement('DROP TABLE places');
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DROP TABLE trips');
    await db.customStatement(createV4Trips);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(insertV4Trip);

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 4, 15),
      completes,
    );
    await db
        .customSelect('SELECT category, summary, planned_date FROM places')
        .get();
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/places/places_migration_test.dart`
Expected: FAIL — `AppDatabase.schemaVersion` is still 14, and `places` has no `planned_date` column.

- [ ] **Step 3: Add the column**

In `lib/features/places/data/place_tables.dart`, add to the `Places` table class (after `DateTimeColumn get summaryFetchedAt => dateTime().nullable()();`):

```dart

  /// Which day of the trip this place is intended for — set only via the
  /// Near By add flow. Null = not assigned to a day (every place that
  /// existed before this column shipped, plus most manually-added ones).
  DateTimeColumn get plannedDate => dateTime().nullable()();
```

- [ ] **Step 4: Bump the schema and add the migration step**

In `lib/core/database/app_database.dart`, update the schema history doc comment (append after the `v14` line):

```dart
///   v15 — Places.plannedDate (Near By day-tag — see
///         docs/superpowers/specs/2026-08-17-near-by-places-design.md)
```

Change `int get schemaVersion => 14;` to:

```dart
  int get schemaVersion => 15;
```

In the `onUpgrade` callback, inside the `places` `else` branch, add a new `if` right after the existing `if (from < 14) { ... }` block:

```dart
            if (from < 14) {
              await m.addColumn(places, places.summary);
              await m.addColumn(places, places.summaryFetchedAt);
            }
            if (from < 15) {
              await m.addColumn(places, places.plannedDate);
            }
```

- [ ] **Step 5: Regenerate the Drift `.g.dart` files by hand**

This sandbox cannot run `dart run build_runner build`. Open `lib/core/database/app_database.g.dart` and add the `plannedDate` column/field in every place the existing `summaryFetchedAt` column appears for the `Places` table and `PlaceRow`/`PlacesCompanion` classes: the `GeneratedDatabase` table class's column getter and `$columns`/`$customConstraints`/`map` wiring, the `PlaceRow` data class (field, constructor param, `fromData`, `toColumns`, `copyWith`, `toString`, `==`, `hashCode`), and the `PlacesCompanion` class (field, constructor param, `insert`/`copyWith`/`toColumns`). Mirror the existing `summaryFetchedAt` (a nullable `DateTimeColumn`) entry at every one of those spots exactly, renamed to `plannedDate` / `planned_date`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/unit/places/places_migration_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/places/data/place_tables.dart lib/core/database/app_database.dart lib/core/database/app_database.g.dart test/unit/places/places_migration_test.dart
git commit -m "feat(places): add Places.plannedDate column, bump schema to v15"
```

---

## Task 5: Repository wiring for `plannedDate`

**Files:**
- Modify: `lib/features/places/data/place_repository.dart`
- Modify: `test/helpers/fake_place_repository.dart`
- Test: `test/unit/places/places_dao_test.dart`

**Interfaces:**
- Consumes: `Place.plannedDate` (Task 3), `Places.plannedDate` column (Task 4).
- Produces: `PlaceRepository.createPlace(..., DateTime? plannedDate)`; `DriftPlaceRepository.updatePlace` persists `place.plannedDate`; `DriftPlaceRepository._toDomain` reads it back.

- [ ] **Step 1: Write the failing tests**

Append to `test/unit/places/places_dao_test.dart`, inside `main()`:

```dart
  test('createPlace can set a plannedDate', () async {
    final id = await repo.createPlace(
      name: 'Railay viewpoint',
      plannedDate: DateTime(2026, 8, 20),
    );
    final place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.plannedDate, DateTime(2026, 8, 20));
  });

  test('updatePlace persists a plannedDate change', () async {
    final id = await repo.createPlace(name: 'Railay viewpoint');
    var place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.plannedDate, isNull);

    await repo.updatePlace(
      place.copyWith(plannedDate: () => DateTime(2026, 8, 21)),
    );
    place = (await repo.watchAll().first).singleWhere((p) => p.id == id);
    expect(place.plannedDate, DateTime(2026, 8, 21));
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/places/places_dao_test.dart`
Expected: FAIL — `createPlace` has no `plannedDate` parameter.

- [ ] **Step 3: Implement the repository wiring**

In `lib/features/places/data/place_repository.dart`, add to the `PlaceRepository` interface's `createPlace` signature (after `PlaceCategory? category,`):

```dart
    DateTime? plannedDate,
```

Add the same parameter to `DriftPlaceRepository.createPlace`'s signature, and pass it into the `PlaceRow(...)` constructor call (after `category: category?.index,`):

```dart
        plannedDate: plannedDate,
```

In `DriftPlaceRepository.updatePlace`, add to the `existing.copyWith(...)` call (after `summaryFetchedAt: Value(place.summaryFetchedAt),`):

```dart
        plannedDate: Value(place.plannedDate),
```

In `DriftPlaceRepository._toDomain`, add to the `Place(...)` constructor call (after `summaryFetchedAt: row.summaryFetchedAt,`):

```dart
        plannedDate: row.plannedDate,
```

- [ ] **Step 4: Update the fake repository**

In `test/helpers/fake_place_repository.dart`, add to `FakePlaceRepository.createPlace`'s signature (after `PlaceCategory? category,`):

```dart
    DateTime? plannedDate,
```

Add to the `Place(...)` constructor call inside it (after `category: category,`):

```dart
      plannedDate: plannedDate,
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/unit/places/places_dao_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/places/data/place_repository.dart test/helpers/fake_place_repository.dart test/unit/places/places_dao_test.dart
git commit -m "feat(places): thread plannedDate through PlaceRepository"
```

---

## Task 6: `NearbyPlaceResult` domain + category mapping + distance helper

**Files:**
- Create: `lib/features/places/domain/nearby_place.dart`
- Modify: `lib/features/places/domain/place_sort.dart`
- Test: `test/unit/places/nearby_place_test.dart`
- Test: `test/unit/places/place_sort_test.dart`

**Interfaces:**
- Produces: `NearbyPlaceResult` (fields: `placeId`, `name`, `lat`, `lng`, `rating`, `userRatingCount`, `primaryType`); `nearbyCategoryFor(String? primaryType) -> PlaceCategory?`; `filterAndSortNearbyResults(List<NearbyPlaceResult>, {required double lat, required double lng}) -> List<NearbyPlaceResult>`; `distanceBetweenKm({required double lat1, required double lng1, required double lat2, required double lng2}) -> double` (added to `place_sort.dart`).

- [ ] **Step 1: Write the failing test for the distance helper**

Append to `test/unit/places/place_sort_test.dart`, inside `main()`:

```dart
  group('distanceBetweenKm', () {
    test('matches placeDistanceFromKm for the same two points', () {
      const lat = 13.7563;
      const lng = 100.5018;
      expect(
        distanceBetweenKm(lat1: lat, lng1: lng, lat2: 14.3532, lng2: 100.5686),
        closeTo(67, 5),
      );
    });

    test('the same point is ~0km away', () {
      expect(
        distanceBetweenKm(lat1: 1, lng1: 1, lat2: 1, lng2: 1),
        closeTo(0, 0.01),
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/places/place_sort_test.dart`
Expected: FAIL — `distanceBetweenKm` undefined.

- [ ] **Step 3: Add the distance helper**

In `lib/features/places/domain/place_sort.dart`, append after `placeDistanceFromKm`:

```dart

/// Distance between two raw coordinate pairs, in km — same haversine math
/// as [placeDistanceFromKm], for callers (like [NearbyPlaceResult]) that
/// aren't a [Place].
double distanceBetweenKm({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) =>
    _haversineDistanceKm(lat1, lng1, lat2, lng2);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/places/place_sort_test.dart`
Expected: PASS

- [ ] **Step 5: Write the failing tests for `nearby_place.dart`**

Create `test/unit/places/nearby_place_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';
import 'package:tripper/features/places/domain/place.dart';

NearbyPlaceResult _r(
  String name, {
  double rating = 4.5,
  int userRatingCount = 20,
  double lat = 13.7563,
  double lng = 100.5018,
  String? primaryType,
}) =>
    NearbyPlaceResult(
      placeId: name,
      name: name,
      lat: lat,
      lng: lng,
      rating: rating,
      userRatingCount: userRatingCount,
      primaryType: primaryType,
    );

void main() {
  group('nearbyCategoryFor', () {
    test('maps known Google types to PlaceCategory', () {
      expect(nearbyCategoryFor('restaurant'), PlaceCategory.restaurant);
      expect(nearbyCategoryFor('cafe'), PlaceCategory.coffeeShop);
      expect(nearbyCategoryFor('bar'), PlaceCategory.bar);
      expect(nearbyCategoryFor('museum'), PlaceCategory.museum);
      expect(nearbyCategoryFor('tourist_attraction'), PlaceCategory.attraction);
      expect(nearbyCategoryFor('lodging'), PlaceCategory.hotel);
      expect(nearbyCategoryFor('amusement_park'), PlaceCategory.amusementPark);
      expect(nearbyCategoryFor('beach'), PlaceCategory.beach);
      expect(nearbyCategoryFor('shopping_mall'), PlaceCategory.shopping);
      expect(nearbyCategoryFor('park'), PlaceCategory.nature);
    });

    test('an unmapped or null type is null, never a guess', () {
      expect(nearbyCategoryFor('gas_station'), isNull);
      expect(nearbyCategoryFor(null), isNull);
    });
  });

  group('filterAndSortNearbyResults', () {
    const lat = 13.7563;
    const lng = 100.5018;

    test('drops results below the rating/count threshold', () {
      final results = [
        _r('Too low rated', rating: 3.9),
        _r('Too few ratings', rating: 4.9, userRatingCount: 4),
        _r('Just enough', rating: 4.0, userRatingCount: 5),
      ];
      final kept = filterAndSortNearbyResults(results, lat: lat, lng: lng);
      expect(kept.map((r) => r.name).toList(), ['Just enough']);
    });

    test('sorts by rating descending, distance ascending as tiebreak', () {
      final results = [
        _r('Far, best rated', rating: 4.9, lat: 18.7883, lng: 98.9853),
        _r('Near, tied rating', rating: 4.5, lat: lat, lng: lng),
        _r('Far, tied rating', rating: 4.5, lat: 18.7883, lng: 98.9853),
      ];
      final sorted = filterAndSortNearbyResults(results, lat: lat, lng: lng);
      expect(sorted.map((r) => r.name).toList(), [
        'Far, best rated',
        'Near, tied rating',
        'Far, tied rating',
      ]);
    });

    test('empty input gives an empty list', () {
      expect(filterAndSortNearbyResults(const [], lat: lat, lng: lng), isEmpty);
    });
  });
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `flutter test test/unit/places/nearby_place_test.dart`
Expected: FAIL — `lib/features/places/domain/nearby_place.dart` does not exist.

- [ ] **Step 7: Create `nearby_place.dart`**

Create `lib/features/places/domain/nearby_place.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'place.dart';
import 'place_sort.dart';

/// One result from a Google Places `searchNearby` call — a transient
/// discovery signal, never persisted as-is (CLAUDE.md hard rule: local
/// data is the source of truth). Adding a result creates a normal [Place]
/// via [PlaceRepository]; rating/userRatingCount/primaryType are not
/// carried onto it.
@immutable
class NearbyPlaceResult {
  const NearbyPlaceResult({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.userRatingCount,
    this.primaryType,
  });

  final String placeId;
  final String name;
  final double lat;
  final double lng;
  final double rating;
  final int userRatingCount;

  /// Raw Google type (e.g. "restaurant"). Kept separate from the mapped
  /// [PlaceCategory] so [nearbyCategoryFor] stays a pure, independently
  /// testable function.
  final String? primaryType;
}

/// A handful of common Google types mapped to the existing wishlist
/// category set; anything unmapped is null (uncategorized) — never a
/// guess, mirroring how [Place.category] treats pre-category rows.
const _typeToCategory = <String, PlaceCategory>{
  'restaurant': PlaceCategory.restaurant,
  'cafe': PlaceCategory.coffeeShop,
  'bar': PlaceCategory.bar,
  'museum': PlaceCategory.museum,
  'tourist_attraction': PlaceCategory.attraction,
  'lodging': PlaceCategory.hotel,
  'amusement_park': PlaceCategory.amusementPark,
  'beach': PlaceCategory.beach,
  'shopping_mall': PlaceCategory.shopping,
  'park': PlaceCategory.nature,
};

PlaceCategory? nearbyCategoryFor(String? primaryType) =>
    primaryType == null ? null : _typeToCategory[primaryType];

const _minRating = 4.0;
const _minRatingCount = 5;

/// "High rated" filter + sort, applied client-side after parsing — a fixed
/// threshold and order, not configurable in v1. Sorts by rating
/// descending, then distance from [lat]/[lng] ascending as a tiebreak.
List<NearbyPlaceResult> filterAndSortNearbyResults(
  List<NearbyPlaceResult> results, {
  required double lat,
  required double lng,
}) {
  final filtered = results
      .where((r) => r.rating >= _minRating && r.userRatingCount >= _minRatingCount)
      .toList();
  filtered.sort((a, b) {
    final byRating = b.rating.compareTo(a.rating);
    if (byRating != 0) return byRating;
    final da =
        distanceBetweenKm(lat1: lat, lng1: lng, lat2: a.lat, lng2: a.lng);
    final db =
        distanceBetweenKm(lat1: lat, lng1: lng, lat2: b.lat, lng2: b.lng);
    return da.compareTo(db);
  });
  return filtered;
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/unit/places/nearby_place_test.dart`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/features/places/domain/nearby_place.dart lib/features/places/domain/place_sort.dart test/unit/places/nearby_place_test.dart test/unit/places/place_sort_test.dart
git commit -m "feat(places): add NearbyPlaceResult, category mapping, and rating filter/sort"
```

---

## Task 7: `nearby_places_service.dart` — fetcher + parser

**Files:**
- Create: `lib/features/places/data/nearby_places_service.dart`
- Test: `test/unit/places/nearby_places_service_test.dart`

**Interfaces:**
- Consumes: `NearbyPlaceResult` (Task 6), `GeocodingException` (`lib/features/places/data/geocoding_service.dart`), `kGoogleMapsApiKey` (`lib/features/places/data/google_places_geocoder.dart`).
- Produces: `NearbyPlacesFetcher` (abstract interface, `Future<List<NearbyPlaceResult>> searchNearby({required double lat, required double lng})`); `GoogleNearbyPlacesFetcher implements NearbyPlacesFetcher`; `parseSearchNearby(String body) -> List<NearbyPlaceResult>` (pure parser).

- [ ] **Step 1: Write the failing parser tests**

Create `test/unit/places/nearby_places_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/nearby_places_service.dart';

const _wellFormed = '''
{
  "places": [
    {
      "id": "ChIJraily",
      "displayName": {"text": "Railay Beach Bar", "languageCode": "en"},
      "location": {"latitude": 8.0119, "longitude": 98.8378},
      "rating": 4.6,
      "userRatingCount": 512,
      "primaryType": "bar"
    },
    {
      "id": "ChIJnorating",
      "displayName": {"text": "No Rating Cafe"},
      "location": {"latitude": 8.02, "longitude": 98.84}
    }
  ]
}
''';

const _malformed = '''
{
  "places": [
    {"id": "ChIJnoname", "location": {"latitude": 8.0, "longitude": 98.0}},
    {"id": "ChIJnolocation", "displayName": {"text": "Ghost"}},
    {"displayName": {"text": "No id"}, "location": {"latitude": 8.0, "longitude": 98.0}},
    "not even a map"
  ]
}
''';

const _empty = '{"places": []}';

void main() {
  group('parseSearchNearby', () {
    test('parses a well-formed response, defaulting missing rating fields',
        () {
      final results = parseSearchNearby(_wellFormed);
      expect(results, hasLength(2));
      expect(results[0].placeId, 'ChIJraily');
      expect(results[0].name, 'Railay Beach Bar');
      expect(results[0].lat, 8.0119);
      expect(results[0].lng, 98.8378);
      expect(results[0].rating, 4.6);
      expect(results[0].userRatingCount, 512);
      expect(results[0].primaryType, 'bar');

      expect(results[1].name, 'No Rating Cafe');
      expect(results[1].rating, 0);
      expect(results[1].userRatingCount, 0);
      expect(results[1].primaryType, isNull);
    });

    test('skips entries missing a name, location, or id; skips non-maps', () {
      expect(parseSearchNearby(_malformed), isEmpty);
    });

    test('an empty places array gives an empty list', () {
      expect(parseSearchNearby(_empty), isEmpty);
    });

    test('a non-map body gives an empty list', () {
      expect(parseSearchNearby('[]'), isEmpty);
      expect(parseSearchNearby('not json'), throwsFormatException);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/places/nearby_places_service_test.dart`
Expected: FAIL — `lib/features/places/data/nearby_places_service.dart` does not exist.

- [ ] **Step 3: Create `nearby_places_service.dart`**

Create `lib/features/places/data/nearby_places_service.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nearby_place.dart';
import 'geocoding_service.dart';

/// Fixed radius, no picker in v1 (design decision, easy follow-up).
const _nearbyRadiusMeters = 2000.0;
const _nearbyMaxResults = 20;

/// Widget/unit tests fake at this boundary.
abstract interface class NearbyPlacesFetcher {
  Future<List<NearbyPlaceResult>> searchNearby({
    required double lat,
    required double lng,
  });
}

/// Google Places API (New) `searchNearby` — same client, exception, and
/// timeout conventions as `GooglePlacesGeocoder`. A minimal field mask
/// keeps this in the cheapest SKU tier; no `includedTypes` restriction
/// (all types together, per the approved design).
class GoogleNearbyPlacesFetcher implements NearbyPlacesFetcher {
  GoogleNearbyPlacesFetcher(this._client, {required String apiKey})
      : _apiKey = apiKey;

  final http.Client _client;
  final String _apiKey;

  @override
  Future<List<NearbyPlaceResult>> searchNearby({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.https('places.googleapis.com', '/v1/places:searchNearby'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask': 'places.id,places.displayName,'
                  'places.location,places.rating,places.userRatingCount,'
                  'places.primaryType',
            },
            body: jsonEncode({
              'maxResultCount': _nearbyMaxResults,
              'locationRestriction': {
                'circle': {
                  'center': {'latitude': lat, 'longitude': lng},
                  'radius': _nearbyRadiusMeters,
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw GeocodingException(
          'Nearby search HTTP ${response.statusCode}: '
          '${_truncate(response.body)}',
        );
      }
      return parseSearchNearby(response.body);
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException('Nearby search $e');
    }
  }
}

/// Keeps debug-console noise down when an API error body is a wall of JSON.
String _truncate(String body, [int max = 300]) =>
    body.length <= max ? body : '${body.substring(0, max)}…';

/// Pure parser — unit-tested against fixture JSON, no network. Skips any
/// entry missing an id, a usable location, or a name — never a guess.
List<NearbyPlaceResult> parseSearchNearby(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return const [];
  final places = decoded['places'];
  if (places is! List) return const [];
  final results = <NearbyPlaceResult>[];
  for (final p in places) {
    if (p is! Map<String, dynamic>) continue;
    final id = p['id']?.toString();
    if (id == null || id.isEmpty) continue;
    final location = p['location'];
    if (location is! Map) continue;
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    final displayName = p['displayName'];
    final name = displayName is Map ? displayName['text']?.toString() : null;
    if (name == null || name.isEmpty) continue;
    results.add(
      NearbyPlaceResult(
        placeId: id,
        name: name,
        lat: lat,
        lng: lng,
        rating: (p['rating'] as num?)?.toDouble() ?? 0,
        userRatingCount: (p['userRatingCount'] as num?)?.toInt() ?? 0,
        primaryType: p['primaryType']?.toString(),
      ),
    );
  }
  return results;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/places/nearby_places_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/places/data/nearby_places_service.dart test/unit/places/nearby_places_service_test.dart
git commit -m "feat(places): add GoogleNearbyPlacesFetcher and parseSearchNearby"
```

---

## Task 8: In-memory TTL cache + `NearbyPlacesService` orchestration + providers

**Files:**
- Create: `lib/features/places/data/nearby_places_cache.dart`
- Modify: `lib/features/places/data/nearby_places_service.dart`
- Modify: `lib/features/places/presentation/place_providers.dart`
- Test: `test/unit/places/nearby_places_cache_test.dart`
- Test: `test/unit/places/nearby_places_orchestration_test.dart`

**Interfaces:**
- Consumes: `NearbyPlacesFetcher` (Task 7), `NearbyPlaceResult`/`filterAndSortNearbyResults` (Task 6), `clockProvider` (`lib/core/database/database_provider.dart`), `nearbyApiCallCountProvider` (Task 1), `kGoogleMapsApiKey`.
- Produces: `NearbyPlacesCache` (`lookup(lat, lng, now) -> List<NearbyPlaceResult>?`, `store(lat, lng, results, now)`); `NearbyPlacesService.search({required lat, required lng}) -> Future<List<NearbyPlaceResult>>`; providers `nearbyPlacesFetcherProvider`, `nearbyPlacesCacheProvider`, `nearbyPlacesServiceProvider`.

- [ ] **Step 1: Write the failing cache tests**

Create `test/unit/places/nearby_places_cache_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/nearby_places_cache.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';

const _result = NearbyPlaceResult(
  placeId: 'p1',
  name: 'Railay Beach Bar',
  lat: 8.0119,
  lng: 98.8378,
  rating: 4.6,
  userRatingCount: 512,
);

void main() {
  group('NearbyPlacesCache', () {
    test('a miss on an empty cache returns null', () {
      final cache = NearbyPlacesCache();
      expect(cache.lookup(8.0119, 98.8378, DateTime(2026, 8, 17)), isNull);
    });

    test('a hit within the TTL returns the stored results', () {
      final cache = NearbyPlacesCache();
      final storedAt = DateTime(2026, 8, 17, 10);
      cache.store(8.0119, 98.8378, const [_result], storedAt);

      final hit = cache.lookup(
        8.0119,
        98.8378,
        storedAt.add(const Duration(minutes: 59)),
      );
      expect(hit, const [_result]);
    });

    test('a lookup past the TTL is a miss', () {
      final cache = NearbyPlacesCache();
      final storedAt = DateTime(2026, 8, 17, 10);
      cache.store(8.0119, 98.8378, const [_result], storedAt);

      final miss = cache.lookup(
        8.0119,
        98.8378,
        storedAt.add(const Duration(hours: 1, minutes: 1)),
      );
      expect(miss, isNull);
    });

    test('coordinates rounded to different 3-decimal keys are distinct', () {
      final cache = NearbyPlacesCache();
      final now = DateTime(2026, 8, 17);
      cache.store(8.0119, 98.8378, const [_result], now);

      expect(cache.lookup(8.0219, 98.8378, now), isNull);
    });

    test('coordinates within the same 3-decimal rounding hit the same key',
        () {
      final cache = NearbyPlacesCache();
      final now = DateTime(2026, 8, 17);
      cache.store(8.01190001, 98.83780001, const [_result], now);

      expect(cache.lookup(8.0119, 98.8378, now), const [_result]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/places/nearby_places_cache_test.dart`
Expected: FAIL — `lib/features/places/data/nearby_places_cache.dart` does not exist.

- [ ] **Step 3: Create `nearby_places_cache.dart`**

Create `lib/features/places/data/nearby_places_cache.dart`:

```dart
import '../domain/nearby_place.dart';

/// Session-scoped, in-memory TTL cache — deliberately not persisted
/// (SharedPreferences/Drift would add real complexity for a guard whose
/// job is "don't double-charge a browsing session"; a killed-and-reopened
/// app is a fresh session and a fresh budget). Keyed by lat/lng rounded to
/// 3 decimal places (~110m) — fine-grained enough that "near me" and "near
/// this hotel" don't collide, coarse enough that GPS jitter within the
/// same spot still hits.
class NearbyPlacesCache {
  final _entries =
      <String, ({DateTime fetchedAt, List<NearbyPlaceResult> results})>{};

  static const ttl = Duration(hours: 1);

  String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

  List<NearbyPlaceResult>? lookup(double lat, double lng, DateTime now) {
    final entry = _entries[_key(lat, lng)];
    if (entry == null) return null;
    if (now.difference(entry.fetchedAt) > ttl) return null;
    return entry.results;
  }

  void store(
    double lat,
    double lng,
    List<NearbyPlaceResult> results,
    DateTime now,
  ) {
    _entries[_key(lat, lng)] = (fetchedAt: now, results: results);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/places/nearby_places_cache_test.dart`
Expected: PASS

- [ ] **Step 5: Write the failing orchestration tests**

Create `test/unit/places/nearby_places_orchestration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/nearby_places_cache.dart';
import 'package:tripper/features/places/data/nearby_places_service.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';

class _FakeFetcher implements NearbyPlacesFetcher {
  var callCount = 0;
  List<NearbyPlaceResult> results = const [];

  @override
  Future<List<NearbyPlaceResult>> searchNearby({
    required double lat,
    required double lng,
  }) async {
    callCount++;
    return results;
  }
}

const _highRated = NearbyPlaceResult(
  placeId: 'p1',
  name: 'Railay Beach Bar',
  lat: 8.02,
  lng: 98.84,
  rating: 4.6,
  userRatingCount: 512,
);

void main() {
  group('NearbyPlacesService', () {
    test('a cache miss fetches, caches, filters/sorts, and reports a real fetch',
        () async {
      final fetcher = _FakeFetcher()..results = const [_highRated];
      final cache = NearbyPlacesCache();
      var realFetchCount = 0;
      var now = DateTime(2026, 8, 17, 10);
      final service = NearbyPlacesService(
        fetcher,
        cache,
        () => now,
        () async => realFetchCount++,
      );

      final results = await service.search(lat: 8.0119, lng: 98.8378);

      expect(results, [_highRated]);
      expect(fetcher.callCount, 1);
      expect(realFetchCount, 1);
    });

    test('a cache hit within the TTL skips the fetcher and the counter',
        () async {
      final fetcher = _FakeFetcher()..results = const [_highRated];
      final cache = NearbyPlacesCache();
      var realFetchCount = 0;
      var now = DateTime(2026, 8, 17, 10);
      final service = NearbyPlacesService(
        fetcher,
        cache,
        () => now,
        () async => realFetchCount++,
      );

      await service.search(lat: 8.0119, lng: 98.8378);
      now = now.add(const Duration(minutes: 30));
      final second = await service.search(lat: 8.0119, lng: 98.8378);

      expect(second, [_highRated]);
      expect(fetcher.callCount, 1);
      expect(realFetchCount, 1);
    });

    test('a lookup past the TTL fetches and increments again', () async {
      final fetcher = _FakeFetcher()..results = const [_highRated];
      final cache = NearbyPlacesCache();
      var realFetchCount = 0;
      var now = DateTime(2026, 8, 17, 10);
      final service = NearbyPlacesService(
        fetcher,
        cache,
        () => now,
        () async => realFetchCount++,
      );

      await service.search(lat: 8.0119, lng: 98.8378);
      now = now.add(const Duration(hours: 1, minutes: 1));
      await service.search(lat: 8.0119, lng: 98.8378);

      expect(fetcher.callCount, 2);
      expect(realFetchCount, 2);
    });
  });
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `flutter test test/unit/places/nearby_places_orchestration_test.dart`
Expected: FAIL — `NearbyPlacesService` undefined.

- [ ] **Step 7: Add `NearbyPlacesService` to `nearby_places_service.dart`**

Append to `lib/features/places/data/nearby_places_service.dart`, add the import `import '../domain/nearby_place.dart' show filterAndSortNearbyResults;` is unnecessary since `nearby_place.dart` is already imported — just append this class at the end of the file:

```dart

/// Composes a fetcher, a cache, an injected clock, and a real-fetch side
/// effect (the caller wires this to the settings call counter) — this
/// class itself has no Riverpod dependency, so it's directly unit-testable
/// with fakes for every collaborator.
class NearbyPlacesService {
  NearbyPlacesService(
    this._fetcher,
    this._cache,
    this._clock,
    this._onRealFetch,
  );

  final NearbyPlacesFetcher _fetcher;
  final NearbyPlacesCache _cache;
  final DateTime Function() _clock;
  final Future<void> Function() _onRealFetch;

  Future<List<NearbyPlaceResult>> search({
    required double lat,
    required double lng,
  }) async {
    final now = _clock();
    final cached = _cache.lookup(lat, lng, now);
    final raw = cached ?? await _fetchAndCache(lat, lng, now);
    return filterAndSortNearbyResults(raw, lat: lat, lng: lng);
  }

  Future<List<NearbyPlaceResult>> _fetchAndCache(
    double lat,
    double lng,
    DateTime now,
  ) async {
    final results = await _fetcher.searchNearby(lat: lat, lng: lng);
    _cache.store(lat, lng, results, now);
    await _onRealFetch();
    return results;
  }
}
```

Add the import at the top of the file: `import 'nearby_places_cache.dart';`.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/unit/places/nearby_places_orchestration_test.dart`
Expected: PASS

- [ ] **Step 9: Wire the providers**

In `lib/features/places/presentation/place_providers.dart`, add imports:

```dart
import '../data/google_places_geocoder.dart' show kGoogleMapsApiKey;
import '../data/nearby_places_cache.dart';
import '../data/nearby_places_service.dart';
```

Add the settings import for the call-count provider (already available transitively is not guaranteed — add explicitly):

```dart
import '../../../core/settings/settings_service.dart' show nearbyApiCallCountProvider;
```

Append, at the end of the file:

```dart

/// Constructing this never touches the network by itself — the real HTTP
/// call only happens inside `searchNearby`, gated at the call site by
/// `nearbyPlacesEnabledProvider` (settings + entry-point UI).
final nearbyPlacesFetcherProvider = Provider<NearbyPlacesFetcher>(
  (ref) => GoogleNearbyPlacesFetcher(http.Client(), apiKey: kGoogleMapsApiKey),
);

/// Session-scoped (not autoDispose) — deliberately survives navigating
/// away from the results screen and back, for the same reason it isn't
/// persisted to disk: the cache's job is "don't double-charge a browsing
/// session," and the session is the whole app run.
final nearbyPlacesCacheProvider =
    Provider<NearbyPlacesCache>((ref) => NearbyPlacesCache());

final nearbyPlacesServiceProvider = Provider<NearbyPlacesService>(
  (ref) => NearbyPlacesService(
    ref.watch(nearbyPlacesFetcherProvider),
    ref.watch(nearbyPlacesCacheProvider),
    ref.watch(clockProvider),
    () => ref.read(nearbyApiCallCountProvider.notifier).increment(),
  ),
);
```

- [ ] **Step 10: Run the full places unit test suite**

Run: `flutter test test/unit/places/`
Expected: PASS (all files)

- [ ] **Step 11: Commit**

```bash
git add lib/features/places/data/nearby_places_cache.dart lib/features/places/data/nearby_places_service.dart lib/features/places/presentation/place_providers.dart test/unit/places/nearby_places_cache_test.dart test/unit/places/nearby_places_orchestration_test.dart
git commit -m "feat(places): add nearby-places TTL cache, orchestration service, and providers"
```

---

## Task 9: Entry point — anchor sheet + `PlacesScreen`/`TripPlacesTab` button

**Files:**
- Create: `lib/features/places/presentation/nearby_anchor_sheet.dart`
- Modify: `lib/features/places/presentation/places_screen.dart`
- Modify: `lib/features/places/presentation/trip_places_tab.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_he.arb`, `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_he.dart`
- Test: `test/widget/places/nearby_anchor_sheet_test.dart`
- Test: `test/widget/places/places_screen_test.dart`
- Test: `test/widget/places/trip_places_tab_test.dart`

**Interfaces:**
- Consumes: `nearbyPlacesEnabledProvider` (Task 1), `currentLocationProvider` (`lib/core/location/location_providers.dart`), `Place.hasLocation`.
- Produces: `showNearbyAnchorSheet(BuildContext, WidgetRef, {required List<Place> places, String? tripId})`. `NearbyPlacesScreen` (referenced here, implemented in Task 10 — this task's push call references it by name/constructor shape only).

- [ ] **Step 1: Add ARB keys**

In `lib/l10n/app_en.arb`, insert after the `"placesFilterShowResults"` block (after its closing `},`, currently line 266), before `"journalGlobeLoading"`:

```json
  "nearbyEntryTooltip": "Find nearby",
  "nearbyAnchorNearMe": "Near me",
  "nearbyAnchorNearMeUnavailable": "Turn on location to use this",
  "nearbyAnchorSavedPlace": "Near a saved place",
  "nearbyAnchorNoSavedPlaces": "No saved places with a location yet",
```

In `lib/l10n/app_he.arb`, insert the matching block at the same position:

```json
  "nearbyEntryTooltip": "מצא בקרבת מקום",
  "nearbyAnchorNearMe": "בקרבתי",
  "nearbyAnchorNearMeUnavailable": "הפעל מיקום כדי להשתמש באפשרות זו",
  "nearbyAnchorSavedPlace": "ליד מקום שמור",
  "nearbyAnchorNoSavedPlaces": "אין עדיין מקומות שמורים עם מיקום",
```

In `lib/l10n/app_localizations.dart`, add the abstract getters after `String placesFilterShowResults(int count);`:

```dart
  /// No description provided for @nearbyEntryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Find nearby'**
  String get nearbyEntryTooltip;

  /// No description provided for @nearbyAnchorNearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get nearbyAnchorNearMe;

  /// No description provided for @nearbyAnchorNearMeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Turn on location to use this'**
  String get nearbyAnchorNearMeUnavailable;

  /// No description provided for @nearbyAnchorSavedPlace.
  ///
  /// In en, this message translates to:
  /// **'Near a saved place'**
  String get nearbyAnchorSavedPlace;

  /// No description provided for @nearbyAnchorNoSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'No saved places with a location yet'**
  String get nearbyAnchorNoSavedPlaces;
```

In `lib/l10n/app_localizations_en.dart`, add after `placesFilterShowResults`'s implementation:

```dart
  @override
  String get nearbyEntryTooltip => 'Find nearby';

  @override
  String get nearbyAnchorNearMe => 'Near me';

  @override
  String get nearbyAnchorNearMeUnavailable => 'Turn on location to use this';

  @override
  String get nearbyAnchorSavedPlace => 'Near a saved place';

  @override
  String get nearbyAnchorNoSavedPlaces => 'No saved places with a location yet';
```

In `lib/l10n/app_localizations_he.dart`, add the matching implementations at the same position:

```dart
  @override
  String get nearbyEntryTooltip => 'מצא בקרבת מקום';

  @override
  String get nearbyAnchorNearMe => 'בקרבתי';

  @override
  String get nearbyAnchorNearMeUnavailable => 'הפעל מיקום כדי להשתמש באפשרות זו';

  @override
  String get nearbyAnchorSavedPlace => 'ליד מקום שמור';

  @override
  String get nearbyAnchorNoSavedPlaces => 'אין עדיין מקומות שמורים עם מיקום';
```

- [ ] **Step 2: Write the failing anchor sheet widget tests**

Create `test/widget/places/nearby_anchor_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/location/location_providers.dart';
import 'package:tripper/core/location/location_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/nearby_anchor_sheet.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_location_service.dart';

Place _p(String name, {double? lat, double? lng}) => Place(
      id: name,
      name: name,
      lat: lat,
      lng: lng,
    );

class _OpenSheetButton extends ConsumerWidget {
  const _OpenSheetButton({required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => showNearbyAnchorSheet(context, ref, places: places),
      child: const Text('open'),
    );
  }
}

Widget _app(List<Place> places, {LocationFix? locationFix}) => ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            locationFix ??
                const LocationUnavailable(LocationUnavailableReason.error),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: _OpenSheetButton(places: places)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('Near me is disabled when location is unavailable',
      (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Near me'),
    );
    expect(tile.enabled, isFalse);
    expect(find.text('Turn on location to use this'), findsOneWidget);
  });

  testWidgets('Near me is enabled once a fix is available', (tester) async {
    await tester.pumpWidget(
      _app(const [], locationFix: const LocationAvailable(8.0119, 98.8378)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Near me'),
    );
    expect(tile.enabled, isTrue);
  });

  testWidgets('Near a saved place is disabled with no located places',
      (tester) async {
    await tester.pumpWidget(_app([_p('No location')]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Near a saved place'),
    );
    expect(tile.enabled, isFalse);
    expect(find.text('No saved places with a location yet'), findsOneWidget);
  });

  testWidgets('Near a saved place lists only located places', (tester) async {
    await tester.pumpWidget(
      _app([
        _p('No location'),
        _p('Hotel', lat: 8.0119, lng: 98.8378),
      ]),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Near a saved place'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('No location'), findsNothing);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/widget/places/nearby_anchor_sheet_test.dart`
Expected: FAIL — `lib/features/places/presentation/nearby_anchor_sheet.dart` does not exist.

- [ ] **Step 4: Create `nearby_anchor_sheet.dart`**

Create `lib/features/places/presentation/nearby_anchor_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';
import 'nearby_places_screen.dart';

/// Entry point for Near By: pick an anchor (current position or a saved
/// place with a location), then push the results screen. [places] is the
/// current screen's place list, pre-scoped by the caller (all places for
/// PlacesScreen, just this trip's for TripPlacesTab) — filtered here to
/// ones with a location, since an anchor with no coordinates can't drive a
/// nearby search.
Future<void> showNearbyAnchorSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<Place> places,
  String? tripId,
}) {
  final located = places.where((p) => p.hasLocation).toList();
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    builder: (context) => _NearbyAnchorSheet(places: located, tripId: tripId),
  );
}

class _NearbyAnchorSheet extends ConsumerWidget {
  const _NearbyAnchorSheet({required this.places, required this.tripId});

  final List<Place> places;
  final String? tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fix = ref.watch(currentLocationProvider).valueOrNull;
    final nearMeAvailable = fix is LocationAvailable;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            enabled: nearMeAvailable,
            leading: const Icon(Icons.my_location),
            title: Text(l10n.nearbyAnchorNearMe),
            subtitle: nearMeAvailable
                ? null
                : Text(l10n.nearbyAnchorNearMeUnavailable),
            onTap: !nearMeAvailable
                ? null
                : () {
                    final available = fix as LocationAvailable;
                    Navigator.of(context).pop();
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NearbyPlacesScreen(
                          anchorLat: available.lat,
                          anchorLng: available.lng,
                          tripId: tripId,
                        ),
                      ),
                    );
                  },
          ),
          ListTile(
            enabled: places.isNotEmpty,
            leading: const Icon(Icons.place_outlined),
            title: Text(l10n.nearbyAnchorSavedPlace),
            subtitle:
                places.isEmpty ? Text(l10n.nearbyAnchorNoSavedPlaces) : null,
            onTap: places.isEmpty
                ? null
                : () {
                    Navigator.of(context).pop();
                    _showPlacePicker(context);
                  },
          ),
        ],
      ),
    );
  }

  void _showPlacePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final place in places)
              Builder(
                builder: (context) {
                  final colors = context.colors;
                  final meta = [
                    if (place.city.isNotEmpty) place.city,
                    if (place.country.isNotEmpty) place.country,
                  ].join(' · ');
                  return ListTile(
                    leading: Icon(Icons.place_outlined, color: colors.accent),
                    title: Text(place.name),
                    subtitle: meta.isEmpty ? null : Text(meta),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NearbyPlacesScreen(
                            anchorLat: place.lat!,
                            anchorLng: place.lng!,
                            tripId: tripId,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
```

This references `NearbyPlacesScreen`, implemented in Task 10 — until that task lands, this file will not compile standalone. Proceed to Step 5 below, which adds a minimal stub so this task's tests can run in isolation; Task 10 replaces the stub with the full implementation.

- [ ] **Step 5: Add a minimal `NearbyPlacesScreen` stub**

Create `lib/features/places/presentation/nearby_places_screen.dart` with a placeholder that Task 10 will fully replace:

```dart
import 'package:flutter/material.dart';

/// Placeholder — replaced by the full implementation in the next plan
/// task. Exists only so nearby_anchor_sheet.dart compiles and its own
/// tests (which never navigate past the sheet) can run.
class NearbyPlacesScreen extends StatelessWidget {
  const NearbyPlacesScreen({
    super.key,
    required this.anchorLat,
    required this.anchorLng,
    this.tripId,
  });

  final double anchorLat;
  final double anchorLng;
  final String? tripId;

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/widget/places/nearby_anchor_sheet_test.dart`
Expected: PASS

- [ ] **Step 7: Write the failing entry-point widget tests**

Append to `test/widget/places/places_screen_test.dart`, inside `main()` (add an import for `tripper/core/settings/settings_service.dart` and `../../helpers/test_preferences.dart`, and change `_app` to accept a `nearbyEnabled` flag with a default — see below):

First, update the `_app` helper's overrides list to include a preferences override, and add a `nearbyEnabled` parameter:

```dart
Widget _app(
  List<Place> places, {
  LocationFix? locationFix,
  bool nearbyEnabled = false,
}) =>
    ProviderScope(
      overrides: [
        placeRepositoryProvider
            .overrideWithValue(FakePlaceRepository([...places])),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
        clockProvider.overrideWithValue(() => _today),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            locationFix ??
                const LocationUnavailable(LocationUnavailableReason.error),
          ),
        ),
        nearbyPlacesEnabledProvider.overrideWith(
          () => _FixedNearbyToggle(nearbyEnabled),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PlacesScreen(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

class _FixedNearbyToggle extends NearbyPlacesEnabledController {
  _FixedNearbyToggle(this._value);
  final bool _value;
  @override
  bool build() => _value;
}
```

Add the two imports this needs: `import 'package:tripper/core/settings/settings_service.dart';` and `import 'package:tripper/features/places/presentation/nearby_anchor_sheet.dart';`.

Then append the tests:

```dart
  testWidgets('nearby entry button is hidden when the feature is off',
      (tester) async {
    await tester.pumpWidget(_app([_p('Railay viewpoint')]));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Find nearby'), findsNothing);
  });

  testWidgets('nearby entry button opens the anchor sheet when the feature is on',
      (tester) async {
    await tester.pumpWidget(
      _app([_p('Railay viewpoint')], nearbyEnabled: true),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Find nearby'), findsOneWidget);

    await tester.tap(find.byTooltip('Find nearby'));
    await tester.pumpAndSettle();
    expect(find.text('Near me'), findsOneWidget);
  });
```

- [ ] **Step 8: Run tests to verify they fail**

Run: `flutter test test/widget/places/places_screen_test.dart`
Expected: FAIL — no widget with tooltip "Find nearby" yet.

- [ ] **Step 9: Add the entry-point button to `PlacesScreen`**

In `lib/features/places/presentation/places_screen.dart`, add the import:

```dart
import '../../../core/settings/settings_service.dart';
import 'nearby_anchor_sheet.dart';
```

In `_PlacesScreenBody.build`, add near the top: `final nearbyEnabled = ref.watch(nearbyPlacesEnabledProvider);`. In the `AppBar.actions` list, insert a new entry after the `FilterSortButton` block and before the add `IconButton`:

```dart
          if (nearbyEnabled)
            IconButton(
              icon: Icon(Icons.travel_explore, color: colors.inkSecondary),
              tooltip: l10n.nearbyEntryTooltip,
              onPressed: () =>
                  showNearbyAnchorSheet(context, ref, places: all),
            ),
```

- [ ] **Step 10: Run tests to verify they pass**

Run: `flutter test test/widget/places/places_screen_test.dart`
Expected: PASS

- [ ] **Step 11: Write and implement the `TripPlacesTab` equivalent**

`test/widget/places/trip_places_tab_test.dart` has its own `_app(FakePlaceRepository repo, {LocationFix? locationFix})` helper that hosts `TripPlacesTab(trip: _trip)` directly (no `tripRepositoryProvider` needed — the trip is passed straight in as a constructor arg) against a fixed `const _trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);` with no dates. Add the import `import 'package:tripper/core/settings/settings_service.dart';` and a local `_FixedNearbyToggle` helper class (same shape as the one in `places_screen_test.dart`), then append two self-contained tests that build their own `ProviderScope` (since `_app` has no toggle override):

```dart
class _FixedNearbyToggle extends NearbyPlacesEnabledController {
  _FixedNearbyToggle(this._value);
  final bool _value;
  @override
  bool build() => _value;
}

Widget _appWithNearby(FakePlaceRepository repo, {required bool nearbyEnabled}) =>
    ProviderScope(
      overrides: [
        placeRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            const LocationUnavailable(LocationUnavailableReason.error),
          ),
        ),
        nearbyPlacesEnabledProvider
            .overrideWith(() => _FixedNearbyToggle(nearbyEnabled)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TripPlacesTab(trip: _trip)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  // ... existing tests above ...

  testWidgets('nearby entry button is hidden when the feature is off',
      (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    await tester.pumpWidget(_appWithNearby(repo, nearbyEnabled: false));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Find nearby'), findsNothing);
  });

  testWidgets(
      'nearby entry button opens the anchor sheet when the feature is on',
      (tester) async {
    final repo = FakePlaceRepository([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        lat: 8.0119,
        lng: 98.8378,
      ),
    ]);
    await tester.pumpWidget(_appWithNearby(repo, nearbyEnabled: true));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Find nearby'), findsOneWidget);

    await tester.tap(find.byTooltip('Find nearby'));
    await tester.pumpAndSettle();
    expect(find.text('Near me'), findsOneWidget);
  });
}
```

(Don't duplicate the `void main() {` line — add these two tests inside the file's existing `main()` block, and place the `_FixedNearbyToggle` class and `_appWithNearby` function at top level alongside the existing `_app` function.)

In `lib/features/places/presentation/trip_places_tab.dart`, add the same two imports as Step 9. In `_TripPlacesTabBody.build`, add `final nearbyEnabled = ref.watch(nearbyPlacesEnabledProvider);` near the top. In the header `Row`'s `children`, insert before the `FilterSortButton`:

```dart
              if (nearbyEnabled)
                IconButton(
                  icon: const Icon(Icons.travel_explore),
                  tooltip: l10n.nearbyEntryTooltip,
                  onPressed: () => showNearbyAnchorSheet(
                    context,
                    ref,
                    places: all,
                    tripId: trip.id,
                  ),
                ),
```

- [ ] **Step 12: Run the full places widget suite**

Run: `flutter test test/widget/places/`
Expected: PASS

- [ ] **Step 13: Commit**

```bash
git add lib/features/places/presentation/nearby_anchor_sheet.dart lib/features/places/presentation/nearby_places_screen.dart lib/features/places/presentation/places_screen.dart lib/features/places/presentation/trip_places_tab.dart lib/l10n/ test/widget/places/nearby_anchor_sheet_test.dart test/widget/places/places_screen_test.dart test/widget/places/trip_places_tab_test.dart
git commit -m "feat(places): add Near By entry point and anchor-picking sheet"
```

---

## Task 10: `NearbyPlacesScreen` — results screen

**Files:**
- Modify: `lib/features/places/presentation/nearby_places_screen.dart` (replaces Task 9's stub)
- Modify: `lib/features/places/presentation/place_widgets.dart` (make the distance formatter reusable)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_he.arb`, `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_he.dart`
- Test: `test/widget/places/nearby_places_screen_test.dart`

**Interfaces:**
- Consumes: `nearbyPlacesServiceProvider` (Task 8), `NearbyPlaceResult`/`nearbyCategoryFor` (Task 6), `distanceBetweenKm` (Task 6), `GeocodingException` (`lib/features/places/data/geocoding_service.dart`), `formatPlaceDistance` (new, this task).
- Produces: `NearbyPlacesScreen(anchorLat, anchorLng, {tripId})` (full implementation); `formatPlaceDistance(AppLocalizations, double) -> String` (extracted from `place_widgets.dart`); `showNearbyPlaceDetailSheet` referenced by name only (implemented in Task 11).

- [ ] **Step 1: Extract `formatPlaceDistance`**

In `lib/features/places/presentation/place_widgets.dart`, rename the private `_formatDistance` function to a public top-level function and update its one call site inside `_PlaceRowCardState.build`:

```dart
/// Under 1 km shows meters (no useful decimal at that scale); under 10 km
/// keeps one decimal of km precision; beyond that, whole km — mirrors how
/// map apps taper precision as distance grows. Shared with the Near By
/// results/detail views.
String formatPlaceDistance(AppLocalizations l10n, double km) {
  if (km < 1) return l10n.placeDistanceMetersAway((km * 1000).round());
  final label = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  return l10n.placeDistanceKmAway(label);
}
```

Update the call site (`if (widget.distanceKm case final km?) _formatDistance(l10n, km),`) to `formatPlaceDistance(l10n, km)`.

- [ ] **Step 2: Add ARB keys**

In `lib/l10n/app_en.arb`, insert after the `nearbyAnchorNoSavedPlaces` key added in Task 9:

```json
  "nearbyResultsTitle": "Nearby",
  "nearbyFindButton": "Find nearby",
  "nearbyEmptyTitle": "No highly-rated places found",
  "nearbyEmptyBody": "Try a different anchor, or check back later — nearby results can change.",
```

In `lib/l10n/app_he.arb`, insert the matching block at the same position:

```json
  "nearbyResultsTitle": "בקרבת מקום",
  "nearbyFindButton": "מצא מקומות בקרבת מקום",
  "nearbyEmptyTitle": "לא נמצאו מקומות מדורגים גבוה",
  "nearbyEmptyBody": "נסה נקודת עוגן אחרת, או בדוק שוב מאוחר יותר — תוצאות קרובות יכולות להשתנות.",
```

Add the matching abstract getters to `lib/l10n/app_localizations.dart` (after `nearbyAnchorNoSavedPlaces`):

```dart
  /// No description provided for @nearbyResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearbyResultsTitle;

  /// No description provided for @nearbyFindButton.
  ///
  /// In en, this message translates to:
  /// **'Find nearby'**
  String get nearbyFindButton;

  /// No description provided for @nearbyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No highly-rated places found'**
  String get nearbyEmptyTitle;

  /// No description provided for @nearbyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different anchor, or check back later — nearby results can change.'**
  String get nearbyEmptyBody;
```

Add implementations to `lib/l10n/app_localizations_en.dart`:

```dart
  @override
  String get nearbyResultsTitle => 'Nearby';

  @override
  String get nearbyFindButton => 'Find nearby';

  @override
  String get nearbyEmptyTitle => 'No highly-rated places found';

  @override
  String get nearbyEmptyBody =>
      'Try a different anchor, or check back later — nearby results can change.';
```

Add implementations to `lib/l10n/app_localizations_he.dart`:

```dart
  @override
  String get nearbyResultsTitle => 'בקרבת מקום';

  @override
  String get nearbyFindButton => 'מצא מקומות בקרבת מקום';

  @override
  String get nearbyEmptyTitle => 'לא נמצאו מקומות מדורגים גבוה';

  @override
  String get nearbyEmptyBody =>
      'נסה נקודת עוגן אחרת, או בדוק שוב מאוחר יותר — תוצאות קרובות יכולות להשתנות.';
```

- [ ] **Step 3: Write the failing widget tests**

Create `test/widget/places/nearby_places_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/nearby_places_cache.dart';
import 'package:tripper/features/places/data/nearby_places_service.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';
import 'package:tripper/features/places/presentation/nearby_places_screen.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

class _FakeFetcher implements NearbyPlacesFetcher {
  _FakeFetcher(this.results);
  _FakeFetcher.failing() : results = const [], _shouldFail = true;

  List<NearbyPlaceResult> results;
  final bool _shouldFail;

  @override
  Future<List<NearbyPlaceResult>> searchNearby({
    required double lat,
    required double lng,
  }) async {
    if (_shouldFail) throw const GeocodingException('offline');
    return results;
  }
}

const _highRated = NearbyPlaceResult(
  placeId: 'p1',
  name: 'Railay Beach Bar',
  lat: 8.02,
  lng: 98.84,
  rating: 4.6,
  userRatingCount: 512,
  primaryType: 'bar',
);

Widget _app(NearbyPlacesFetcher fetcher) => ProviderScope(
      overrides: [
        nearbyPlacesFetcherProvider.overrideWithValue(fetcher),
        nearbyPlacesCacheProvider.overrideWithValue(NearbyPlacesCache()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const NearbyPlacesScreen(anchorLat: 8.0119, anchorLng: 98.8378),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('initial state shows only the find button, no list',
      (tester) async {
    await tester.pumpWidget(_app(_FakeFetcher(const [_highRated])));
    await tester.pumpAndSettle();
    expect(find.text('Find nearby'), findsOneWidget);
    expect(find.text('Railay Beach Bar'), findsNothing);
  });

  testWidgets('tapping find renders results with rating and distance',
      (tester) async {
    await tester.pumpWidget(_app(_FakeFetcher(const [_highRated])));
    await tester.tap(find.text('Find nearby'));
    await tester.pumpAndSettle();

    expect(find.text('Railay Beach Bar'), findsOneWidget);
    expect(find.textContaining('4.6'), findsOneWidget);
  });

  testWidgets('no results after the rating filter shows the empty state',
      (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeFetcher(const [
          NearbyPlaceResult(
            placeId: 'low',
            name: 'Low rated place',
            lat: 8.02,
            lng: 98.84,
            rating: 2.0,
            userRatingCount: 50,
          ),
        ]),
      ),
    );
    await tester.tap(find.text('Find nearby'));
    await tester.pumpAndSettle();

    expect(find.text('No highly-rated places found'), findsOneWidget);
  });

  testWidgets('a fetch failure shows the error state with retry',
      (tester) async {
    await tester.pumpWidget(_app(_FakeFetcher.failing()));
    await tester.tap(find.text('Find nearby'));
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `flutter test test/widget/places/nearby_places_screen_test.dart`
Expected: FAIL — the Task 9 stub renders none of this.

- [ ] **Step 5: Implement `NearbyPlacesScreen`**

Replace the contents of `lib/features/places/presentation/nearby_places_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../data/geocoding_service.dart' show GeocodingException;
import '../domain/nearby_place.dart';
import '../domain/place_sort.dart';
import 'nearby_place_detail_sheet.dart';
import 'place_providers.dart';
import 'place_widgets.dart';

enum _LoadState { initial, loading, loaded, error }

/// Pull-based results screen for Near By: no auto-fetch on open, no
/// refetch-on-anything (§5.10) — a single explicit "Find nearby" action.
class NearbyPlacesScreen extends ConsumerStatefulWidget {
  const NearbyPlacesScreen({
    super.key,
    required this.anchorLat,
    required this.anchorLng,
    this.tripId,
  });

  final double anchorLat;
  final double anchorLng;
  final String? tripId;

  @override
  ConsumerState<NearbyPlacesScreen> createState() =>
      _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends ConsumerState<NearbyPlacesScreen> {
  _LoadState _state = _LoadState.initial;
  List<NearbyPlaceResult> _results = const [];

  Future<void> _fetch() async {
    setState(() => _state = _LoadState.loading);
    try {
      final results = await ref.read(nearbyPlacesServiceProvider).search(
            lat: widget.anchorLat,
            lng: widget.anchorLng,
          );
      if (!mounted) return;
      setState(() {
        _results = results;
        _state = _LoadState.loaded;
      });
    } on GeocodingException catch (e) {
      debugPrint('[places] nearby search failed: $e');
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.nearbyResultsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _state == _LoadState.loading ? null : _fetch,
                child: _state == _LoadState.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.nearbyFindButton),
              ),
            ),
          ),
          Expanded(child: _body(l10n, colors)),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l10n, AppColors colors) {
    switch (_state) {
      case _LoadState.initial:
      case _LoadState.loading:
        return const SizedBox.shrink();
      case _LoadState.error:
        return ErrorState(onRetry: _fetch);
      case _LoadState.loaded:
        if (_results.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: l10n.nearbyEmptyTitle,
            body: l10n.nearbyEmptyBody,
            ctaLabel: l10n.nearbyFindButton,
            onCta: _fetch,
          );
        }
        return ListView.builder(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          itemCount: _results.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: _NearbyResultCard(
              result: _results[index],
              anchorLat: widget.anchorLat,
              anchorLng: widget.anchorLng,
              tripId: widget.tripId,
            ),
          ),
        );
    }
  }
}

class _NearbyResultCard extends StatelessWidget {
  const _NearbyResultCard({
    required this.result,
    required this.anchorLat,
    required this.anchorLng,
    required this.tripId,
  });

  final NearbyPlaceResult result;
  final double anchorLat;
  final double anchorLng;
  final String? tripId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final category = nearbyCategoryFor(result.primaryType);
    final distanceKm = distanceBetweenKm(
      lat1: anchorLat,
      lng1: anchorLng,
      lat2: result.lat,
      lng2: result.lng,
    );

    return PaperCard(
      onTap: () => showNearbyPlaceDetailSheet(
        context,
        result: result,
        distanceKm: distanceKm,
        tripId: tripId,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            category == null ? Icons.place_outlined : placeCategoryIcon(category),
            size: 20,
            color: colors.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                MonoText(
                  '${result.rating.toStringAsFixed(1)} '
                  '(${result.userRatingCount}) · '
                  '${formatPlaceDistance(l10n, distanceKm)}',
                  muted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

This references `showNearbyPlaceDetailSheet` from `nearby_place_detail_sheet.dart`, implemented in Task 11. Add a minimal stub so this task compiles standalone (Task 11 replaces it):

Create `lib/features/places/presentation/nearby_place_detail_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../domain/nearby_place.dart';

/// Placeholder — replaced by the full implementation in the next plan
/// task.
Future<void> showNearbyPlaceDetailSheet(
  BuildContext context, {
  required NearbyPlaceResult result,
  required double distanceKm,
  String? tripId,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => const SizedBox(),
  );
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/widget/places/nearby_places_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Run the full places widget suite (regression check for the formatter rename)**

Run: `flutter test test/widget/places/`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lib/features/places/presentation/nearby_places_screen.dart lib/features/places/presentation/nearby_place_detail_sheet.dart lib/features/places/presentation/place_widgets.dart lib/l10n/ test/widget/places/nearby_places_screen_test.dart
git commit -m "feat(places): implement the Near By results screen"
```

---

## Task 11: Detail bottom sheet — Wikipedia summary, day tag, add to wishlist

**Files:**
- Modify: `lib/features/places/presentation/nearby_place_detail_sheet.dart` (replaces Task 10's stub)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_he.arb`, `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_he.dart`
- Test: `test/widget/places/nearby_place_detail_sheet_test.dart`

**Interfaces:**
- Consumes: `placeSummaryFetcherProvider`, `placeRepositoryProvider` (`lib/features/places/presentation/place_providers.dart`), `fetchAndStorePlaceSummary` (`lib/features/places/data/place_summary_service.dart`), `tripListProvider` (`lib/features/trips/presentation/trip_providers.dart`), `Trip.dayNumber` (`lib/features/trips/domain/trip.dart`, already exists), `nearbyCategoryFor`/`NearbyPlaceResult` (Task 6), `formatPlaceDistance` (Task 10).
- Produces: `showNearbyPlaceDetailSheet(BuildContext, {required NearbyPlaceResult result, required double distanceKm, String? tripId})` (full implementation).

- [ ] **Step 1: Add ARB keys**

In `lib/l10n/app_en.arb`, insert after the `nearbyEmptyBody` key added in Task 10:

```json
  "nearbyAddToWishlist": "Add to wishlist",
  "nearbyDayPickerPrompt": "Assign a day",
  "nearbyDayNumber": "Day {n}",
  "@nearbyDayNumber": {
    "placeholders": { "n": { "type": "int" } }
  },
```

In `lib/l10n/app_he.arb`, insert the matching block:

```json
  "nearbyAddToWishlist": "הוסף לרשימת המשאלות",
  "nearbyDayPickerPrompt": "שייך ליום",
  "nearbyDayNumber": "יום {n}",
  "@nearbyDayNumber": {
    "placeholders": { "n": { "type": "int" } }
  },
```

Add the abstract getters to `lib/l10n/app_localizations.dart` (after `nearbyEmptyBody`):

```dart
  /// No description provided for @nearbyAddToWishlist.
  ///
  /// In en, this message translates to:
  /// **'Add to wishlist'**
  String get nearbyAddToWishlist;

  /// No description provided for @nearbyDayPickerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Assign a day'**
  String get nearbyDayPickerPrompt;

  /// No description provided for @nearbyDayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String nearbyDayNumber(int n);
```

Add implementations to `lib/l10n/app_localizations_en.dart`:

```dart
  @override
  String get nearbyAddToWishlist => 'Add to wishlist';

  @override
  String get nearbyDayPickerPrompt => 'Assign a day';

  @override
  String nearbyDayNumber(int n) => 'Day $n';
```

Add implementations to `lib/l10n/app_localizations_he.dart`:

```dart
  @override
  String get nearbyAddToWishlist => 'הוסף לרשימת המשאלות';

  @override
  String get nearbyDayPickerPrompt => 'שייך ליום';

  @override
  String nearbyDayNumber(int n) => 'יום $n';
```

- [ ] **Step 2: Write the failing widget tests**

Create `test/widget/places/nearby_place_detail_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';
import 'package:tripper/features/places/presentation/nearby_place_detail_sheet.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';

class _FakeSummaryFetcher implements PlaceSummaryFetcher {
  _FakeSummaryFetcher(this._summary, {this.delay = Duration.zero});
  final String? _summary;
  final Duration delay;
  var callCount = 0;

  @override
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async {
    callCount++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return _summary;
  }
}

const _result = NearbyPlaceResult(
  placeId: 'p1',
  name: 'Railay Beach Bar',
  lat: 8.02,
  lng: 98.84,
  rating: 4.6,
  userRatingCount: 512,
);

Widget _app({
  required PlaceSummaryFetcher fetcher,
  String? tripId,
  Trip? trip,
}) =>
    ProviderScope(
      overrides: [
        placeSummaryFetcherProvider.overrideWithValue(fetcher),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
        tripRepositoryProvider
            .overrideWithValue(FakeTripRepository(trip == null ? [] : [trip])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showNearbyPlaceDetailSheet(
                context,
                result: _result,
                distanceKm: 1.2,
                tripId: tripId,
              ),
              child: const Text('open'),
            ),
          ),
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('shows a spinner while the summary loads, then the text',
      (tester) async {
    final fetcher = _FakeSummaryFetcher(
      'A quiet cove with cliffside bars.',
      delay: const Duration(milliseconds: 50),
    );
    await tester.pumpWidget(_app(fetcher: fetcher));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('A quiet cove with cliffside bars.'), findsOneWidget);
  });

  testWidgets('a null summary renders nothing extra, no error copy',
      (tester) async {
    await tester.pumpWidget(_app(fetcher: _FakeSummaryFetcher(null)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no day picker without a fully-dated trip', (tester) async {
    await tester.pumpWidget(
      _app(fetcher: _FakeSummaryFetcher(null), tripId: 't1'),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Assign a day'), findsNothing);
  });

  testWidgets('day picker appears for a fully-dated trip, clamped to its range',
      (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const [],
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 10),
    );
    await tester.pumpWidget(
      _app(fetcher: _FakeSummaryFetcher(null), tripId: 't1', trip: trip),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Assign a day'), findsOneWidget);
  });

  testWidgets(
      'adding after the summary resolved calls setSummary directly, not a second fetch',
      (tester) async {
    final fetcher = _FakeSummaryFetcher('A quiet cove.');
    await tester.pumpWidget(_app(fetcher: fetcher));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(fetcher.callCount, 1);

    await tester.tap(find.text('Add to wishlist'));
    await tester.pumpAndSettle();

    expect(fetcher.callCount, 1);
  });

  testWidgets('adding before the summary resolves falls back to the '
      'fire-and-forget path', (tester) async {
    final fetcher = _FakeSummaryFetcher(
      'A quiet cove.',
      delay: const Duration(milliseconds: 200),
    );
    await tester.pumpWidget(_app(fetcher: fetcher));
    await tester.tap(find.text('open'));
    await tester.pump();

    await tester.tap(find.text('Add to wishlist'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(fetcher.callCount, 1);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/widget/places/nearby_place_detail_sheet_test.dart`
Expected: FAIL — the Task 10 stub renders none of this.

- [ ] **Step 4: Implement the detail sheet**

Replace the contents of `lib/features/places/presentation/nearby_place_detail_sheet.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/trip_providers.dart';
import '../data/place_summary_service.dart';
import '../domain/nearby_place.dart';
import 'place_providers.dart';
import 'place_widgets.dart';

/// Detail sheet reached by tapping a Near By result: rating/distance,
/// a lazily-fetched Wikipedia summary to help decide, an editable name,
/// an optional day tag (only for a fully-dated trip), and the "Add to
/// wishlist" action.
Future<void> showNearbyPlaceDetailSheet(
  BuildContext context, {
  required NearbyPlaceResult result,
  required double distanceKm,
  String? tripId,
}) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _NearbyPlaceDetailSheet(
        result: result,
        distanceKm: distanceKm,
        tripId: tripId,
      ),
    ),
  );
}

class _NearbyPlaceDetailSheet extends ConsumerStatefulWidget {
  const _NearbyPlaceDetailSheet({
    required this.result,
    required this.distanceKm,
    required this.tripId,
  });

  final NearbyPlaceResult result;
  final double distanceKm;
  final String? tripId;

  @override
  ConsumerState<_NearbyPlaceDetailSheet> createState() =>
      _NearbyPlaceDetailSheetState();
}

class _NearbyPlaceDetailSheetState
    extends ConsumerState<_NearbyPlaceDetailSheet> {
  late final TextEditingController _name;
  DateTime? _plannedDate;
  bool _saving = false;

  bool _summaryLoading = true;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.result.name);
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    final summary = await ref.read(placeSummaryFetcherProvider).fetchSummary(
          name: widget.result.name,
          lat: widget.result.lat,
          lng: widget.result.lng,
        );
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _summaryLoading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final category = nearbyCategoryFor(widget.result.primaryType);

    Trip? trip;
    if (widget.tripId != null) {
      for (final t in ref.watch(tripListProvider).valueOrNull ?? const []) {
        if (t.id == widget.tripId) {
          trip = t;
          break;
        }
      }
    }
    final showDayPicker =
        trip != null && trip.startDate != null && trip.endDate != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  category == null
                      ? Icons.place_outlined
                      : placeCategoryIcon(category),
                  color: colors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.result.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            MonoText(
              '${widget.result.rating.toStringAsFixed(1)} '
              '(${widget.result.userRatingCount}) · '
              '${formatPlaceDistance(l10n, widget.distanceKm)}',
              muted: true,
            ),
            if (_summaryLoading) ...[
              const SizedBox(height: AppSpacing.md),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else if (_summary != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_summary!, style: TextStyle(color: colors.inkSecondary)),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.placeFormName),
            ),
            if (showDayPicker) ...[
              const SizedBox(height: AppSpacing.md),
              _DayPicker(
                trip: trip!,
                value: _plannedDate,
                onChanged: (date) => setState(() => _plannedDate = date),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.nearbyAddToWishlist),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(placeRepositoryProvider);
    final name = _name.text.trim().isEmpty ? widget.result.name : _name.text;
    final id = await repo.createPlace(
      name: name,
      lat: widget.result.lat,
      lng: widget.result.lng,
      tripId: widget.tripId,
      category: nearbyCategoryFor(widget.result.primaryType),
      plannedDate: _plannedDate,
    );
    if (!_summaryLoading) {
      await repo.setSummary(id, summary: _summary);
    } else {
      // The summary hasn't resolved yet — same fire-and-forget path the
      // manual add flow uses; the save itself doesn't wait on it.
      unawaited(
        fetchAndStorePlaceSummary(
          fetcher: ref.read(placeSummaryFetcherProvider),
          repo: repo,
          placeId: id,
          name: widget.result.name,
          lat: widget.result.lat,
          lng: widget.result.lng,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.trip,
    required this.value,
    required this.onChanged,
  });

  final Trip trip;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayLabel = value == null
        ? l10n.nearbyDayPickerPrompt
        : l10n.nearbyDayNumber(trip.dayNumber(value!)!);

    return OutlinedButton.icon(
      icon: const Icon(Icons.event_outlined, size: 16),
      label: Text(dayLabel),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? trip.startDate!,
          firstDate: trip.startDate!,
          lastDate: trip.endDate!,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/widget/places/nearby_place_detail_sheet_test.dart`
Expected: PASS

- [ ] **Step 6: Run the full places test suite (regression check)**

Run: `flutter test test/unit/places/ test/widget/places/`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/places/presentation/nearby_place_detail_sheet.dart lib/l10n/ test/widget/places/nearby_place_detail_sheet_test.dart
git commit -m "feat(places): implement the Near By detail sheet — summary, day tag, add to wishlist"
```

---

## Task 12: `PlaceRowCard` "DAY N" chip

**Files:**
- Modify: `lib/features/places/presentation/place_widgets.dart`
- Modify: `lib/features/places/presentation/places_screen.dart`
- Modify: `lib/features/places/presentation/trip_places_tab.dart`
- Test: `test/widget/places/places_screen_test.dart`
- Test: `test/widget/places/trip_places_tab_test.dart`

**Interfaces:**
- Consumes: `Place.plannedDate` (Task 3), `Trip.dayNumber` (`lib/features/trips/domain/trip.dart`, pre-existing).
- Produces: `PlaceRowCard` gains an optional `int? dayNumber` parameter, rendered as a mono chip in its metadata row.

- [ ] **Step 1: Write the failing widget tests**

Append to `test/widget/places/places_screen_test.dart`:

```dart
  testWidgets('a place with a plannedDate shows its DAY N chip',
      (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const [],
      startDate: DateTime(2026, 7, 15),
      endDate: DateTime(2026, 7, 25),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeRepositoryProvider.overrideWithValue(
            FakePlaceRepository([
              Place(
                id: 'p1',
                name: 'Railay viewpoint',
                tripId: 't1',
                plannedDate: DateTime(2026, 7, 17),
              ),
            ]),
          ),
          tripRepositoryProvider.overrideWithValue(FakeTripRepository([trip])),
          clockProvider.overrideWithValue(() => _today),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(
              const LocationUnavailable(LocationUnavailableReason.error),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PlacesScreen(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('DAY 3'), findsOneWidget);
  });
```

Add the needed import at the top of the file: `import 'package:tripper/features/trips/domain/trip.dart';`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/places/places_screen_test.dart`
Expected: FAIL — no "DAY 3" text rendered.

- [ ] **Step 3: Add the `dayNumber` param to `PlaceRowCard`**

In `lib/features/places/presentation/place_widgets.dart`, add to the `PlaceRowCard` constructor and fields (after `this.distanceKm,` / `final double? distanceKm;`):

```dart
    this.dayNumber,
```

```dart
  /// 1-based trip day this place is tagged for — `null` when untagged or
  /// the place has no trip. Computed by the caller (`Trip.dayNumber`)
  /// rather than read from global state here.
  final int? dayNumber;
```

In `_PlaceRowCardState.build`, add to the `metaParts` list (after the `distanceKm` line, before the `visited`/`tripName` conditional) — `l10n` is already in scope as a local in `build`:

```dart
      if (widget.dayNumber case final day?) l10n.nearbyDayNumber(day),
```

- [ ] **Step 4: Wire `dayNumber` from `PlacesScreen`**

In `lib/features/places/presentation/places_screen.dart`, in `_PlacesScreenBody.build`, change the trips lookup to build a `Trip`-keyed map alongside the existing name map:

```dart
    final trips = ref.watch(tripListProvider).valueOrNull ?? [];
    final tripsById = {for (final t in trips) t.id: t};
```

(Replace the existing `tripNames` map, or keep both — simplest is to derive `tripNames` from `tripsById` where still needed: `final tripNames = {for (final t in trips) t.id: t.name};` can stay as-is alongside the new `tripsById` map.)

In `_row`, compute the day number and pass it through:

```dart
  Widget _row(
    BuildContext context,
    WidgetRef ref,
    Place place,
    Map<String, String> tripNames,
    Map<String, Trip> tripsById,
  ) {
    final loc = currentLocation;
    final distanceKm = loc != null && place.hasLocation
        ? placeDistanceFromKm(place, lat: loc.lat, lng: loc.lng)
        : null;
    final trip = place.tripId == null ? null : tripsById[place.tripId];
    final dayNumber = (trip?.startDate != null && place.plannedDate != null)
        ? trip!.dayNumber(place.plannedDate!)
        : null;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: RowSettleAnimation(
        placeId: place.id,
        child: PlaceRowCard(
          place: place,
          tripName: place.tripId == null ? null : tripNames[place.tripId],
          distanceKm: distanceKm,
          dayNumber: dayNumber,
          onTap: () => showPlaceActionsSheet(context, ref, place),
          onToggleVisited: () {
            HapticFeedback.selectionClick();
            markPlaceVisited(ref, place, visited: !place.isVisited);
          },
        ),
      ),
    );
  }
```

Update the two call sites of `_row(context, ref, place, tripNames)` (in the `want`/`been` loops inside `_body`) to `_row(context, ref, place, tripNames, tripsById)`. Add the import `import '../../trips/domain/trip.dart';` if not already present (it is not, currently only `trip_providers.dart` is imported).

- [ ] **Step 5: Wire `dayNumber` from `TripPlacesTab`**

In `lib/features/places/presentation/trip_places_tab.dart`, add a private helper method to `_TripPlacesTabBody` (near `_activeFilterStrip`):

```dart
  int? _dayNumberFor(Place place) =>
      (trip.startDate != null && place.plannedDate != null)
          ? trip.dayNumber(place.plannedDate!)
          : null;
```

Then, in the `for (final place in visible)` loop inside `build`, add `dayNumber: _dayNumberFor(place),` to the existing `PlaceRowCard(...)` call (after `place: place,`):

```dart
                child: PlaceRowCard(
                  place: place,
                  dayNumber: _dayNumberFor(place),
                  distanceKm: currentLocation != null && place.hasLocation
                      ? placeDistanceFromKm(
                          place,
                          lat: currentLocation!.lat,
                          lng: currentLocation!.lng,
                        )
                      : null,
                  onTap: () => showPlaceActionsSheet(context, ref, place),
                  onToggleVisited: () {
                    HapticFeedback.selectionClick();
                    markPlaceVisited(ref, place, visited: !place.isVisited);
                  },
                ),
```

- [ ] **Step 6: Add the equivalent test to `trip_places_tab_test.dart`**

Append inside `main()` (this test builds its own dated `Trip`, unlike the file's fixed dateless `const _trip`, so it doesn't use the `_app` helper):

```dart
  testWidgets('a place with a plannedDate shows its DAY N chip',
      (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      startDate: DateTime(2026, 7, 15),
      endDate: DateTime(2026, 7, 25),
    );
    final repo = FakePlaceRepository([
      Place(
        id: 'a',
        name: 'Railay viewpoint',
        tripId: 't1',
        plannedDate: DateTime(2026, 7, 17),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(
              const LocationUnavailable(LocationUnavailableReason.error),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: TripPlacesTab(trip: trip)),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 15 Jul is day 1, so 17 Jul is day 3.
    expect(find.textContaining('DAY 3'), findsOneWidget);
  });
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/widget/places/places_screen_test.dart test/widget/places/trip_places_tab_test.dart`
Expected: PASS

- [ ] **Step 8: Run the full test suite**

Run: `flutter test`
Expected: PASS (every test file in the project)

- [ ] **Step 9: Commit**

```bash
git add lib/features/places/presentation/place_widgets.dart lib/features/places/presentation/places_screen.dart lib/features/places/presentation/trip_places_tab.dart test/widget/places/places_screen_test.dart test/widget/places/trip_places_tab_test.dart
git commit -m "feat(places): render the DAY N chip on PlaceRowCard"
```

---

## Task 13: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Run the complete test suite**

Run: `flutter analyze && flutter test`
Expected: zero analyzer issues, all tests pass.

- [ ] **Step 2: Fix any issues found**

If `flutter analyze` reports issues (most likely candidates: the hand-edited `app_database.g.dart` from Task 4 Step 5, or an import ordering/unused-import lint), fix them in place and re-run Step 1 until clean. This cannot be verified in this sandbox (CLAUDE.md: no Flutter SDK access) — this task is carried out by whoever runs `./scripts/verify.ps1` or the equivalent CI job, per the project's stated verify loop.

- [ ] **Step 3: Report results back**

Report the `flutter analyze`/`flutter test` output (pass/fail, and any remaining failures) back so the implementation can be judged complete.
