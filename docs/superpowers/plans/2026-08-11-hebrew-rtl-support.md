# Hebrew / RTL support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn on Hebrew as a second, manually-selectable language: a full
Hebrew translation, a language picker in Settings, dates that stay
Gregorian/Latin regardless of app language, and verified RTL layout.

**Architecture:** `app_he.arb` is a new sibling to the existing
`app_en.arb`, both driven by the existing `flutter gen-l10n` pipeline (no
new tooling). A new `LocaleController`/`localeProvider` mirrors the
existing `ThemeModeController` exactly — a `SharedPreferences`-backed
Riverpod `Notifier`, wired into `MaterialApp.router`'s `locale:` and
`supportedLocales:`. Flutter derives `Directionality` from the resolved
locale automatically; no manual RTL widget work is needed given the
codebase's layout code is already `*Directional`-clean (verified: zero
hardcoded `left`/`right` widgets anywhere in `lib/`).

**Tech Stack:** Flutter/Dart, `flutter_localizations`/`intl` (already
dependencies), Riverpod, `flutter gen-l10n`.

## Global Constraints

(From `CLAUDE.md` and `docs/superpowers/specs/2026-08-11-hebrew-rtl-support-design.md`.)

- Every user-facing string goes through ARB — including the two language
  autonym labels ("English"/"עברית"), which are a deliberate exception to
  *per-locale translation* (an autonym is never translated) but still go
  through the ARB mechanism itself.
- Dates stay Gregorian/Latin-form (`"16 JUL 2026"`-style) in every locale
  — this is an explicit, approved product decision, not a limitation to
  work around later.
- Tests land in the same commit as the feature.
- `EdgeInsetsDirectional`/RTL-safe layout conventions (already followed
  consistently — new code in this plan must not introduce the first
  hardcoded `left`/`right` widget in the codebase).

---

### Task 1: Hebrew translation (`app_he.arb`) + structural completeness test

**Files:**
- Create: `lib/l10n/app_he.arb`
- Create: `test/unit/l10n/arb_completeness_test.dart`

**Interfaces:**
- Produces: `lib/l10n/app_he.arb` — consumed by `flutter gen-l10n`
  (generates `AppLocalizationsHe`) once Task 2 adds `Locale('he')` to
  `supportedLocales`. Not reachable in the running app until Task 2; this
  task is content + a structural test only.

This task is **content-authorship, not code-logic** — the actual
translation work is yours to do as part of implementing this task
(this brief gives you the structural requirements and the trickiest
technical detail to get right, not a pre-written translation to
transcribe).

- [ ] **Step 1: Read the source file**

Read `lib/l10n/app_en.arb` in full (237 keys, ~335 lines) before writing
anything — you need to see every key's actual English text and every
`@`-prefixed placeholder-metadata block to translate correctly.

- [ ] **Step 2: Write `lib/l10n/app_he.arb`**

Translate every non-`@`-prefixed key from `app_en.arb` into natural,
correct Hebrew. Requirements:

1. **Exact same key set.** Every key in `app_en.arb` (except `@@locale`,
   which is metadata, not a string) must appear in `app_he.arb`, and
   nothing extra. Do not add, drop, or rename a key.
2. **`@@locale` at the top**, matching the file's actual language:
   ```json
   "@@locale": "he",
   ```
3. **Every `{placeholder}` token must be preserved exactly**, same name,
   in the Hebrew translation — e.g. if `app_en.arb` has
   `"expiryShort": "Exp {date}"`, the Hebrew value must still contain a
   literal `{date}` token somewhere in the translated sentence (word order
   around it can and should change to read naturally in Hebrew — only the
   token itself is fixed).
4. **Every `@`-prefixed placeholder-metadata block must be mirrored
   verbatim** — same placeholder names, same `"type"` values — since
   `flutter gen-l10n` uses these to generate the Dart method signatures,
   and they must match between locales. Example: `app_en.arb` has
   ```json
   "expiryShort": "Exp {date}",
   "@expiryShort": {
     "placeholders": { "date": { "type": "String" } }
   },
   ```
   `app_he.arb` needs the identical `@expiryShort` block (translate
   nothing inside it — it's structural metadata, not display text), plus
   your Hebrew translation of `"expiryShort"` itself.
5. **The 4 ICU-plural keys need Hebrew's real plural category set, not
   English's copied over.** English `plural` syntax only has `one`/`other`
   categories; Hebrew grammar has four: `one` (exactly 1), `two` (exactly
   2 — Hebrew treats 2 specially, unlike English), `many` (a specific
   large-round-number rule in CLDR, most commonly relevant for multiples
   of 10 and higher counts), and `other` (everything else). Write out all
   four categories with grammatically correct Hebrew for each — do not
   just supply `one`/`other` and let ICU fall back, since that silently
   produces wrong grammar for "2" and for large-number cases in real use.
   The four keys needing this treatment: `expensesConversionPending`,
   `journalGlobeClusterCount`, `tripCountdownNotificationBodyClear`,
   `tripCountdownNotificationBodyWithIssues`. The last one has **two**
   independent `{X, plural, ...}` clauses inside one string (`days` and
   `count`) — both need the full four-category treatment, independently
   of each other.

   Worked example of the shape (illustrative — not real translated text,
   just showing correct ICU structure with Hebrew's four categories):
   ```json
   "journalGlobeClusterCount": "{count, plural, one{ערך אחד} two{שני ערכים} many{{count} ערכים} other{{count} ערכים}}",
   ```
6. **Do not translate `languageEnglish`/`languageHebrew`** — those two
   keys don't exist yet (Task 2 adds them to both files together, with
   identical values in each, since a language's own name in its own
   script is never translated). Nothing for you to do with them here.
7. Valid JSON — the file must parse. Match `app_en.arb`'s existing
   formatting style (one key per line, 2-space indent) for consistency,
   though this isn't functionally required.

- [ ] **Step 3: Confirm `flutter gen-l10n` succeeds**

Run: `flutter gen-l10n`
Expected: completes without error, and generates
`lib/l10n/app_localizations_he.dart` alongside the existing
`app_localizations_en.dart`.

- [ ] **Step 4: Write the failing structural completeness test**

Create `test/unit/l10n/arb_completeness_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> he;

  setUpAll(() {
    en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    he = jsonDecode(File('lib/l10n/app_he.arb').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('app_he.arb has exactly the same keys as app_en.arb', () {
    final enKeys = en.keys.where((k) => k != '@@locale').toSet();
    final heKeys = he.keys.where((k) => k != '@@locale').toSet();

    final missingFromHe = enKeys.difference(heKeys);
    final extraInHe = heKeys.difference(enKeys);

    expect(
      missingFromHe,
      isEmpty,
      reason:
          'app_he.arb is missing keys present in app_en.arb: $missingFromHe',
    );
    expect(
      extraInHe,
      isEmpty,
      reason: 'app_he.arb has keys not present in app_en.arb: $extraInHe',
    );
  });

  test(
      'every @-prefixed placeholder-metadata key has matching placeholder '
      'names in both files', () {
    for (final key in en.keys) {
      if (!key.startsWith('@') || key == '@@locale') continue;
      final enMeta = en[key] as Map<String, dynamic>;
      final heMeta = he[key] as Map<String, dynamic>?;
      expect(heMeta, isNotNull, reason: '$key missing from app_he.arb');
      final enPlaceholders =
          (enMeta['placeholders'] as Map<String, dynamic>?)?.keys.toSet() ??
              {};
      final hePlaceholders =
          (heMeta!['placeholders'] as Map<String, dynamic>?)?.keys.toSet() ??
              {};
      expect(
        hePlaceholders,
        enPlaceholders,
        reason:
            '$key: placeholder names differ between app_en.arb and app_he.arb',
      );
    }
  });

  test(
      'every {placeholder} token used in an English string also appears '
      'in its Hebrew translation', () {
    final placeholderToken = RegExp(r'\{(\w+)');
    for (final key in en.keys) {
      if (key.startsWith('@')) continue;
      final enValue = en[key] as String;
      final heValue = he[key] as String?;
      if (heValue == null) continue; // caught by the key-parity test above
      final enTokens =
          placeholderToken.allMatches(enValue).map((m) => m.group(1)).toSet();
      final heTokens =
          placeholderToken.allMatches(heValue).map((m) => m.group(1)).toSet();
      expect(
        heTokens,
        enTokens,
        reason:
            '$key: placeholder tokens differ — en has $enTokens, he has $heTokens',
      );
    }
  });
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/unit/l10n/arb_completeness_test.dart`
Expected: PASS, all 3 cases. If it fails, fix `app_he.arb` (missing key,
mismatched placeholder, or dropped token) — do not weaken the test to
make it pass.

- [ ] **Step 6: Run analyze**

Run: `flutter analyze test/unit/l10n/arb_completeness_test.dart`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/app_he.arb lib/l10n/app_localizations_he.dart test/unit/l10n/arb_completeness_test.dart
git commit -m "feat(l10n): add Hebrew translation (app_he.arb)"
```

(Note: `lib/l10n/app_localizations.dart` and `app_localizations_en.dart`
are *not* expected to change from this task alone — they only change once
`supportedLocales` actually includes `he`, which is Task 2. If
`flutter gen-l10n` regenerates them anyway with no semantic diff, that's
fine to include; if it produces no changes to those two files, don't force
it.)

---

### Task 2: Locale infrastructure + language picker

**Files:**
- Modify: `lib/core/settings/settings_service.dart`
- Modify: `lib/app.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_he.arb`
- Test: Modify `test/unit/settings/settings_service_test.dart`
- Test: Create `test/widget/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: `app_he.arb` existing (Task 1) — selecting Hebrew must not
  crash/fall back silently once this task wires it in.
- Produces: `localeProvider` (`NotifierProvider<LocaleController,
  Locale>`) — consumed by Task 4's RTL tests via the `app_locale`
  `SharedPreferences` key.

- [ ] **Step 1: Write the failing `LocaleController` tests**

In `test/unit/settings/settings_service_test.dart`, add (same file, same
`containerWith` helper, same style as the existing `ThemeModeController`
tests right above):

```dart
  test('locale defaults to English', () async {
    final container = await containerWith({});
    expect(container.read(localeProvider), const Locale('en'));
  });

  test('stored Hebrew locale is restored', () async {
    final container = await containerWith({'app_locale': 'he'});
    expect(container.read(localeProvider), const Locale('he'));
  });

  test('an unrecognized stored value falls back to English', () async {
    final container = await containerWith({'app_locale': 'fr'});
    expect(container.read(localeProvider), const Locale('en'));
  });

  test('set persists and updates state', () async {
    final container = await containerWith({});
    await container.read(localeProvider.notifier).set(const Locale('he'));
    expect(container.read(localeProvider), const Locale('he'));
    expect(
      container.read(sharedPreferencesProvider).getString('app_locale'),
      'he',
    );
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/unit/settings/settings_service_test.dart`
Expected: FAIL — `localeProvider` doesn't exist yet.

- [ ] **Step 3: Implement `LocaleController`**

In `lib/core/settings/settings_service.dart`, add near the top-level
`const _k...` keys (alongside `_kThemeMode` etc.):
```dart
const _kAppLocale = 'app_locale';
```

Add the `import 'package:flutter/material.dart';` for `Locale` if this
file doesn't already import it (check first — `ThemeMode` comes from
`package:flutter/material.dart` too, so it's very likely already
imported; if so, no new import needed).

Add near `ThemeModeController`/`themeModeProvider`:
```dart
/// English by default — the app doesn't follow system locale (manual
/// picker only, this round — see the design spec's "Out of scope").
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final stored = ref.read(sharedPreferencesProvider).getString(_kAppLocale);
    return stored == 'he' ? const Locale('he') : const Locale('en');
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kAppLocale, locale.languageCode);
  }
}

final localeProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/settings/settings_service_test.dart`
Expected: PASS, all cases (existing + new).

- [ ] **Step 5: Add the ARB strings**

In `lib/l10n/app_en.arb`, add near `settingsHomeCurrency` (or any other
Settings-section-header key — group with the rest of Settings' strings):
```json
  "settingsLanguage": "Language",
  "languageEnglish": "English",
  "languageHebrew": "עברית",
```

In `lib/l10n/app_he.arb`, add the equivalent three keys — translate
`settingsLanguage` into Hebrew (a real, per-locale translation, e.g. "שפה"
or your own correct choice), but `languageEnglish`/`languageHebrew` get
the **identical values** as in `app_en.arb` — these are autonyms, never
translated (see this task's Interfaces note and the design spec).

- [ ] **Step 6: Wire the locale into `MaterialApp.router`**

In `lib/app.dart`, `TripperApp.build` (already a `ConsumerWidget` reading
`themeModeProvider` the same way — add `locale:` alongside the existing
`themeMode:` argument):
```dart
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: ref.watch(localeProvider),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('he')],
    );
```
(Only `locale:` is new and `supportedLocales:` gains `Locale('he')` —
everything else in this call is unchanged; don't restructure the rest of
the widget around this.)

- [ ] **Step 7: Add the Settings screen Language section**

In `lib/features/settings/presentation/settings_screen.dart`, `build()`
reads `ref.watch(localeProvider)` alongside the other settings values
already read there (`themeMode`, `lockEnabled`, `noticeDays`):
```dart
    final locale = ref.watch(localeProvider);
```

Insert this new section right after the existing Appearance section's
`SegmentedButton<ThemeMode>(...)` block, before Security:
```dart
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.settingsLanguage),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<Locale>(
            segments: [
              ButtonSegment(
                value: const Locale('en'),
                label: Text(l10n.languageEnglish),
              ),
              ButtonSegment(
                value: const Locale('he'),
                label: Text(l10n.languageHebrew),
              ),
            ],
            selected: {locale},
            onSelectionChanged: (selection) =>
                ref.read(localeProvider.notifier).set(selection.first),
          ),
```
(Match whatever exact spacing constant the Appearance section already
uses between its own `SectionLabel` and its `SegmentedButton` — read the
surrounding code first rather than assuming `AppSpacing.sm` is exactly
right if the file does something slightly different there.)

`Locale` needs `import 'package:flutter/material.dart';` — this file
likely already imports it for other Material widgets; confirm rather than
assume, and add it if genuinely missing.

- [ ] **Step 8: Write the failing widget test**

Create `test/widget/settings/settings_screen_test.dart`. This screen is
gated behind the vault-lock biometric check
(`ref.read(vaultLockProvider.notifier).ensureUnlocked(...)` in
`initState`), so the fixture needs `biometricAuthenticatorProvider`
overridden to auto-succeed — same pattern already established in
`test/widget/accessibility_test.dart`. `SettingsScreen`'s `build()` only
reads settings-service providers directly (not any document/place/trip
repository — `backupServiceProvider` is only touched lazily inside the
Export/Import button handlers, which this test doesn't need to press), so
the fixture doesn't need repository overrides:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/security/vault_lock.dart';
import 'package:tripper/core/settings/settings_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/settings/presentation/settings_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/test_preferences.dart';

Future<Widget> _app() async => ProviderScope(
      overrides: [
        await testPreferencesOverride(),
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
    );

void main() {
  testWidgets('selecting Hebrew persists and updates localeProvider',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('עברית'));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(SettingsScreen));
    final container2 = ProviderScope.containerOf(element);
    expect(container2.read(localeProvider), const Locale('he'));
    expect(
      container2.read(sharedPreferencesProvider).getString('app_locale'),
      'he',
    );
  });

  testWidgets('English is selected by default', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(SettingsScreen));
    final container = ProviderScope.containerOf(element);
    expect(container.read(localeProvider), const Locale('en'));
  });
}
```

- [ ] **Step 9: Run to verify they fail, then implement, then pass**

Run: `flutter test test/widget/settings/settings_screen_test.dart`
Expected first: FAIL (no Language section exists). After Step 7's
implementation: PASS.

- [ ] **Step 10: Run analyze**

Run: `flutter analyze lib/core/settings/settings_service.dart lib/app.dart lib/features/settings/ test/unit/settings/ test/widget/settings/`
Expected: No issues found.

- [ ] **Step 11: Regenerate localizations and commit**

```bash
flutter gen-l10n
git add lib/core/settings/settings_service.dart lib/app.dart lib/features/settings/presentation/settings_screen.dart lib/l10n/app_en.arb lib/l10n/app_he.arb lib/l10n/app_localizations*.dart test/unit/settings/settings_service_test.dart test/widget/settings/settings_screen_test.dart
git commit -m "feat(settings): add a manual language picker (English/Hebrew)"
```

---

### Task 3: Lock date formatting to English/Gregorian, explicitly

**Files:**
- Modify: `lib/features/vault/presentation/document_widgets.dart`
- Modify: `lib/features/expenses/presentation/expense_form_sheet.dart`
- Modify: `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`
- Modify: `lib/features/journal/presentation/journal_widgets.dart`
- Modify: `lib/features/vault/presentation/document_form_sheet.dart`
- Modify: `lib/features/journal/presentation/journal_entry_form_sheet.dart`
- Modify: `lib/features/expenses/presentation/expense_widgets.dart`
- Modify: `lib/features/trips/presentation/trip_card.dart`
- Modify: `lib/features/vault/domain/document_notifications.dart`
- Modify: `lib/features/places/presentation/place_widgets.dart`
- Test: Create `test/unit/l10n/date_formatting_locale_test.dart`

**Interfaces:** none — this task only changes literal arguments to
existing `DateFormat(...)` calls, no signature changes.

`intl`'s `DateFormat` takes the locale as its **second positional
argument**, not a named one: `DateFormat(pattern, locale)`. Every call
site below gets `'en_US'` added as that second argument — pattern string
itself is unchanged.

- [ ] **Step 1: Write the failing locale-pinning test**

Create `test/unit/l10n/date_formatting_locale_test.dart` — this doesn't
test every call site individually (the fix is mechanically identical
everywhere); it proves the *pattern itself* behaves correctly once pinned,
which is what every call site below relies on:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test(
      'a DateFormat pinned to en_US renders English month names even when '
      "Intl.defaultLocale is Hebrew — the fix this task's call sites rely on",
      () {
    final original = Intl.defaultLocale;
    Intl.defaultLocale = 'he';
    addTearDown(() => Intl.defaultLocale = original);

    final pinned = DateFormat('dd MMM yyyy', 'en_US');
    expect(pinned.format(DateTime(2026, 7, 16)), '16 Jul 2026');

    // Without a pinned locale, the same pattern picks up the active
    // Intl.defaultLocale instead — demonstrating why the pin matters,
    // not just asserting the pinned behavior in isolation.
    final unpinned = DateFormat('dd MMM yyyy');
    expect(unpinned.format(DateTime(2026, 7, 16)), isNot('16 Jul 2026'));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/unit/l10n/date_formatting_locale_test.dart`
Expected: FAIL — before any call-site changes, this test still exercises
`DateFormat` directly (not through app code), so it should actually PASS
already once `intl`'s Hebrew locale data is initialized correctly, since
it's testing `intl`'s own behavior, not this app's code. If it passes
immediately, that's fine — it's establishing the underlying mechanism
this task's remaining steps rely on; treat this as a sanity check you ran
and confirmed passes, then proceed to the call-site changes below (there
is no "not implemented yet" failure state for this particular test, since
it doesn't touch app code — don't force an artificial red state here).

- [ ] **Step 3: Pin every call site**

Each entry below is an exact find → replace within the named file. Only
the shown line(s) change; nothing else in each file.

**`lib/features/vault/presentation/document_widgets.dart`**
```dart
// find:
    l10n.expiryShort(DateFormat('dd/MM/yyyy').format(expiry));
// replace:
    l10n.expiryShort(DateFormat('dd/MM/yyyy', 'en_US').format(expiry));
```

**`lib/features/expenses/presentation/expense_form_sheet.dart`**
```dart
// find:
          label: Text(DateFormat('dd MMM yyyy').format(_date)),
// replace:
          label: Text(DateFormat('dd MMM yyyy', 'en_US').format(_date)),
```

**`lib/features/journal/presentation/journal_entry_presentation_sheet.dart`**
```dart
// find:
                      DateFormat('d MMMM yyyy · HH:mm').format(entry.loggedAt),
// replace:
                      DateFormat('d MMMM yyyy · HH:mm', 'en_US').format(entry.loggedAt),
```

**`lib/features/journal/presentation/journal_widgets.dart`** (two call
sites — both get the same treatment):
```dart
// find (first occurrence, ~line 121):
                                DateFormat('dd MMM').format(entry.loggedAt),
// replace:
                                DateFormat('dd MMM', 'en_US').format(entry.loggedAt),

// find (second occurrence, ~line 542):
                                DateFormat('dd MMM').format(first.loggedAt),
// replace:
                                DateFormat('dd MMM', 'en_US').format(first.loggedAt),
```

**`lib/features/vault/presentation/document_form_sheet.dart`** (two call
sites):
```dart
// find:
                      : DateFormat('dd MMM yyyy').format(_expiry!),
// replace:
                      : DateFormat('dd MMM yyyy', 'en_US').format(_expiry!),

// find:
                  : DateFormat('dd MMM yyyy, HH:mm').format(_departureTime!),
// replace:
                  : DateFormat('dd MMM yyyy, HH:mm', 'en_US').format(_departureTime!),
```

**`lib/features/journal/presentation/journal_entry_form_sheet.dart`** (two
call sites):
```dart
// find:
                        DateFormat('EEEE, d MMMM').format(_loggedAt!),
// replace:
                        DateFormat('EEEE, d MMMM', 'en_US').format(_loggedAt!),

// find:
                        DateFormat('yyyy · HH:mm').format(_loggedAt!),
// replace:
                        DateFormat('yyyy · HH:mm', 'en_US').format(_loggedAt!),
```

**`lib/features/expenses/presentation/expense_widgets.dart`** (four call
sites):
```dart
// find:
                        DateFormat('dd MMM yyyy').format(home!.ratesAt!),
// replace:
                        DateFormat('dd MMM yyyy', 'en_US').format(home!.ratesAt!),

// find:
      DateFormat('dd MMM yyyy').format(expense.date),
// replace:
      DateFormat('dd MMM yyyy', 'en_US').format(expense.date),

// find:
          DateFormat('EEE, MMM d').format(group.periodStart),
// replace:
          DateFormat('EEE, MMM d', 'en_US').format(group.periodStart),

// find:
            DateFormat('MMM d').format(group.periodStart),
// replace:
            DateFormat('MMM d', 'en_US').format(group.periodStart),

// find:
          DateFormat('MMMM yyyy').format(group.periodStart),
// replace:
          DateFormat('MMMM yyyy', 'en_US').format(group.periodStart),
```
(Yes, this file has 5 call sites, not 4 as the file list summary says —
`EEE, MMM d`, `MMM d`, and `MMMM yyyy` are three separate calls inside the
`ExpenseGroupHeader._label` switch expression from the Spend-improvements
work; find and pin all three plus the two others shown above.)

**`lib/features/trips/presentation/trip_card.dart`**
```dart
// find:
  static String single(DateTime d) => DateFormat('dd MMM').format(d);
// replace:
  static String single(DateTime d) => DateFormat('dd MMM', 'en_US').format(d);
```

**`lib/features/vault/domain/document_notifications.dart`**
```dart
// find:
          DateFormat('dd MMM yyyy').format(expiry),
// replace:
          DateFormat('dd MMM yyyy', 'en_US').format(expiry),
```

**`lib/features/places/presentation/place_widgets.dart`**
```dart
// find:
        l10n.visitedOn(DateFormat('dd MMM yyyy').format(place.visitedAt!))
// replace:
        l10n.visitedOn(DateFormat('dd MMM yyyy', 'en_US').format(place.visitedAt!))
```

Before editing each file, read enough surrounding context to confirm
you're changing the exact right occurrence (some patterns like
`'dd MMM yyyy'` repeat across files) — the file path pins you to the
right file, but within a file with more than one `DateFormat` call,
match against the surrounding line shown above, not just the pattern
string alone.

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: PASS — this is a pure literal-argument change to already-tested
formatting calls; no existing test's expected output changes (English
locale was always the implicit behavior before, and still is — this task
makes it explicit, not different).

- [ ] **Step 5: Run analyze**

Run: `flutter analyze lib/features/vault/ lib/features/expenses/ lib/features/journal/ lib/features/trips/ lib/features/places/ test/unit/l10n/`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/vault/presentation/document_widgets.dart lib/features/expenses/presentation/expense_form_sheet.dart lib/features/journal/presentation/journal_entry_presentation_sheet.dart lib/features/journal/presentation/journal_widgets.dart lib/features/vault/presentation/document_form_sheet.dart lib/features/journal/presentation/journal_entry_form_sheet.dart lib/features/expenses/presentation/expense_widgets.dart lib/features/trips/presentation/trip_card.dart lib/features/vault/domain/document_notifications.dart lib/features/places/presentation/place_widgets.dart test/unit/l10n/date_formatting_locale_test.dart
git commit -m "fix(l10n): pin every DateFormat call to en_US, regardless of app language"
```

---

### Task 4: RTL verification

**Files:**
- Modify: `test/widget/accessibility_test.dart`

**Interfaces:**
- Consumes: `localeProvider` (Task 2) — via the `app_locale`
  `SharedPreferences` key, and `supportedLocales` now including
  `Locale('he')` in `lib/app.dart` (Task 2), which this test's existing
  `TripperApp()` fixture picks up automatically with no test-file-level
  `supportedLocales` change needed.

**Scope note:** the design spec described navigating "each of the four
bottom-nav tabs... plus Settings." On closer look at the actual shell
(`lib/core/widgets/app_shell.dart`), there are only **three** bottom-nav
destinations (Trips, Vault, Places) — the spec's "four" conflated these
with the four *inner* tabs of a trip's detail screen, which are
plain-text `Tab(text: ...)` widgets with no icon to navigate by
independent of the (now-Hebrew) translated label text, and Settings has
its own separate entry point. This task scopes to the three real
bottom-nav destinations plus the initial (Trips) screen, navigated by
icon rather than by label text — which stays locale-independent and
avoids the test depending on this plan's own Hebrew word choices. Deeper
trip-detail-tab and Settings RTL coverage is a reasonable follow-up, not
included here.

- [ ] **Step 1: Add a `locale` parameter to the existing fixture**

In `test/widget/accessibility_test.dart`, change:
```dart
Future<Widget> _populatedApp() async => ProviderScope(
      overrides: [
        await testPreferencesOverride(),
```
to:
```dart
Future<Widget> _populatedApp({String locale = 'en'}) async => ProviderScope(
      overrides: [
        await testPreferencesOverride({'app_locale': locale}),
```
(Every other line in `_populatedApp`'s overrides list and the widget tree
below it is unchanged — only the function signature and this one
override call.)

- [ ] **Step 2: Write the failing RTL test**

Add to the same file's `main()`, after the existing `'layout survives
1.3x text scaling without overflow'` test:

```dart
  testWidgets(
      'app renders RTL and without overflow in Hebrew across the main tabs',
      (tester) async {
    await tester.pumpWidget(await _populatedApp(locale: 'he'));
    await tester.pumpAndSettle();

    final rootContext = tester.element(find.byType(MaterialApp));
    expect(Directionality.of(rootContext), TextDirection.rtl);

    // Navigate by icon, not translated label text — the label text is
    // now Hebrew, and this test shouldn't need to know this plan's own
    // word choices to drive navigation.
    final navBar = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(
        of: navBar,
        matching: find.byIcon(Icons.folder_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: navBar,
        matching: find.byIcon(Icons.place_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: navBar,
        matching: find.byIcon(Icons.luggage_outlined),
      ),
    );
    await tester.pumpAndSettle();

    // No RenderFlex overflow surfacing across any of these screens is the
    // actual check — same "reaching this line is the pass" pattern the
    // existing 1.3x text-scale test above already uses.
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 3: Run to verify it fails, then confirm it passes once Tasks 1-3 are in place**

Run: `flutter test test/widget/accessibility_test.dart`

If Tasks 1-3 are already committed on this branch (expected — this is the
last task in the plan), this should PASS immediately: `Locale('he')` is
already in `supportedLocales`, `app_he.arb`/`AppLocalizationsHe` already
exist and are structurally complete (Task 1's test enforces this), so
there's no missing-translation crash risk. If anything fails, the most
likely causes are (a) a genuine `RenderFlex` overflow somewhere under
Hebrew/RTL layout — a real bug this test exists to catch, fix the
overflow, don't loosen the test — or (b) the icon-based navigation finding
zero or multiple matches — adjust the finder, not what it's checking for.

- [ ] **Step 4: Run the full existing accessibility suite**

Run: `flutter test test/widget/accessibility_test.dart`
Expected: PASS, all 5 tests (4 existing + 1 new).

- [ ] **Step 5: Run analyze**

Run: `flutter analyze test/widget/accessibility_test.dart`
Expected: No issues found.

- [ ] **Step 6: Run the full project test suite**

Run: `flutter test`
Expected: PASS — confirms nothing across the whole app regressed from any
task in this plan.

- [ ] **Step 7: Commit**

```bash
git add test/widget/accessibility_test.dart
git commit -m "test(l10n): verify RTL layout and no-overflow in Hebrew across the main tabs"
```

## Self-Review Notes

- **Spec coverage:** manual language picker (Task 2), Hebrew translation
  + structural completeness guard (Task 1), dates staying Gregorian/Latin
  explicitly rather than by accident (Task 3), RTL verification (Task 4).
  "Out of scope" items from the design (auto system-locale detection,
  localized dates, native-speaker translation review, other locales) —
  none introduced.
- **Refinement caught during planning, not left for the review loop:**
  the design spec's Testing section said "four bottom-nav tabs" — on
  reading the actual shell code, there are three (Trips/Vault/Places);
  the fourth was a conflation with a trip-detail screen's four *inner*
  tabs, which are plain-text `Tab` widgets with no locale-independent way
  to navigate by icon. Task 4 documents this and scopes to what's
  actually testable without the test depending on this plan's own word
  choices for Hebrew tab labels.
- **Translation content is delegated, not pre-written**, unlike every
  other task in this plan (and every prior plan this session) — Task 1's
  brief is deliberately structural/procedural rather than literal
  verbatim content, since pre-translating 237 strings into this planning
  document would both bloat it enormously and add no value over giving
  the implementer (equally capable of correct Hebrew) clear structural
  requirements plus the one genuinely tricky technical detail (Hebrew's
  four-category ICU plural rule) spelled out with a worked example.
- **Placeholder scan:** no TBD/TODO in the procedural sense; Task 1 is the
  one deliberate, disclosed exception to "every step has complete code,"
  for the reason above.
- **Type consistency:** `localeProvider`/`LocaleController` (Task 2) is
  consumed identically in Task 4's fixture change. `app_locale` is the one
  `SharedPreferences` key introduced and used consistently across Tasks 2
  and 4.
- **`DateFormat`'s locale argument confirmed positional, not named**
  (`DateFormat(pattern, [locale])`) — Task 3's find/replace pairs all
  reflect this; a plan draft that wrote `DateFormat('dd MMM yyyy', locale:
  'en_US')` would fail to compile, so this was verified against the
  actual `intl` package API before finalizing the task.
