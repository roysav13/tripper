# Hebrew / RTL support

Status: approved, not yet implemented. Fourth of five independent
sub-projects scoped out of a larger batch request (Spend, Place — both
shipped; Hebrew/RTL — this spec; Vault filtering and the trip-subtitle fix
remain).

## Problem

The app is hardcoded to `supportedLocales: const [Locale('en')]` — not
even following the device's system language. `lib/l10n/app_en.arb` (237
keys) is the only ARB file; no `app_he.arb` exists. No `Directionality`
handling exists anywhere because there's only ever been one, LTR, locale
to support. There is no language setting anywhere in the app (Settings
has Appearance, Security, Notifications, Home currency, Backup — no
Language section, and `settings_service.dart` has no locale key).

The layout code itself is already in unusually good shape for this: a
full-codebase grep found **zero** hardcoded `left`/`right`-style widgets
(`EdgeInsets.only(left:`, `Alignment.centerLeft`, `TextAlign.left`,
`Positioned(left:`) anywhere in `lib/` — only the RTL-safe `*Directional`
equivalents (97 occurrences across 29 files). This matches CLAUDE.md's
long-standing rule 3 ("RTL-safe layouts... Hebrew is a future translation
pass") having actually been followed, not just stated. So this project is
close to what SPEC.md always intended it to be: "a translation pass, not
a rewrite" — the remaining work is turning on the second locale, writing
the translation, and *verifying* the RTL layout claim rather than
originating it from scratch.

## Design

### 1. Manual language picker (Settings)

New `LocaleController extends Notifier<Locale>` in
`lib/core/settings/settings_service.dart`, mirroring the existing
`ThemeModeController` exactly (same shape: read a `SharedPreferences`
string key on `build()`, default when unset, `set()` writes through):

```dart
const _kAppLocale = 'app_locale';

/// English by default — the app doesn't yet follow system locale (no
/// prior art for that in this codebase to extend; see Out of Scope).
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

`lib/app.dart`'s `MaterialApp.router` (already a `ConsumerWidget` reading
`themeModeProvider` the same way) gains `locale: ref.watch(localeProvider)`
and `supportedLocales: const [Locale('en'), Locale('he')]`. Flutter derives
`Directionality` from the resolved locale automatically once both are
wired — no manual `Directionality` widget needed anywhere.

Settings screen gets a new "Language" section, positioned right after
Appearance (same visual family: a preference about how the app presents
itself), using the exact same `SegmentedButton` pattern as the existing
Appearance/Notifications sections:

```dart
SectionLabel(l10n.settingsLanguage),
const SizedBox(height: AppSpacing.sm),
SegmentedButton<Locale>(
  segments: [
    ButtonSegment(value: const Locale('en'), label: Text(l10n.languageEnglish)),
    ButtonSegment(value: const Locale('he'), label: Text(l10n.languageHebrew)),
  ],
  selected: {ref.watch(localeProvider)},
  onSelectionChanged: (selection) =>
      ref.read(localeProvider.notifier).set(selection.first),
),
```

`languageEnglish`/`languageHebrew` are a deliberate exception to "every
string is translated *differently* per locale": a language's own name in
its own script (an autonym — "English", "עברית") is conventionally never
translated, in any app — showing "אנגלית" (Hebrew for "English") while
the label for the language itself sits in a Hebrew-language UI would
defeat the point of a picker meant to be usable by someone who can't yet
read the *current* language. Both ARB files carry these two keys with the
identical value on purpose; this still satisfies "every user-facing string
goes through ARB" (rule 3) — it's simply a string whose correct
translation policy is "don't."

### 2. Hebrew translation (`app_he.arb`)

New file, `lib/l10n/app_he.arb`, translating all 237 keys from
`app_en.arb`. Written by Claude directly — flagged plainly, not glossed
over: this is AI-generated Hebrew, not a native speaker's pass. Fine to
ship and iterate on; worth a native-speaker review pass before this is in
front of real Hebrew-speaking users, tracked as a follow-up, not a
blocker for this round.

4 keys use ICU `plural` syntax (`expensesConversionPending`,
`journalGlobeClusterCount`, `tripCountdownNotificationBodyClear`,
`tripCountdownNotificationBodyWithIssues` — the last has *two* independent
plural clauses in one string). Hebrew's plural rule has four categories
(`one`, `two`, `many`, `other`) where English only has two (`one`,
`other`) — each of these four keys gets Hebrew's full category set
written out correctly, not just `one`/`other` copied over with translated
text (that would silently mis-pluralize "2" and large-round-number cases,
which Hebrew grammar treats specially).

**Structural completeness, enforced by a test, not just care at write
time:** a new `test/unit/l10n/arb_completeness_test.dart` parses both ARB
files as JSON and asserts they carry the exact same key set — nothing
present in one and missing from the other (excluding the `@`-prefixed
metadata keys, which only exist where a placeholder needs documenting).
This is a permanent regression guard: the day someone adds a 238th key to
`app_en.arb` and forgets `app_he.arb`, this test catches it instead of a
silent English-string fallback shipping in the Hebrew UI.

### 3. Dates stay Gregorian/Latin, explicitly — not by accident

All 17 existing `DateFormat(pattern)` call sites currently omit the
locale argument, which means they implicitly inherit whatever locale
`intl`'s `Intl.defaultLocale` resolves to — today that's moot (only
English exists), but once `Locale('he')` is wired in, an unlocked
`DateFormat('dd MMM yyyy')` risks silently rendering Hebrew month names,
contradicting the approved decision (dates stay exactly as they render
today, regardless of app language — matching how travel documents are
dated internationally). Every call site gets pinned explicitly:
`DateFormat('dd MMM yyyy', 'en_US')` (`intl`'s `DateFormat` takes the
locale as its second *positional* argument, not a named one). This makes
the "dates never localize" decision a property of the code, not an
accident of what locale happens to be active when it's read.

### 4. RTL verification

Reuses `test/widget/accessibility_test.dart`'s existing `_populatedApp()`
fixture (already builds a fully-populated `ProviderScope` + `TripperApp`)
rather than introducing a new generic test harness — adding
`localeProvider.overrideWith((ref) => LocaleController()..state =
const Locale('he'))` (or equivalent) to that same fixture gives a
Hebrew/RTL variant "for free," reusing the exact populated-data setup the
existing English 1.3×-text-scale overflow test already relies on. New
tests mirror that existing test's shape: pump the app in Hebrew, navigate
into each of the four bottom-nav tabs (Documents, Places, Spend/Journal
tabs inside a trip, Trips list) plus Settings (to reach the new language
picker itself), assert no `RenderFlex` overflow (the same "reaching this
line without an exception is the pass" pattern the existing text-scale
test already uses) and that `Directionality.of(context)` resolves to
`TextDirection.rtl` at the app root.

## Error handling

Nothing here is network-dependent or has a failure-mode branch — this is
static translated content and a locally-persisted preference, no
degraded/offline path needed beyond what already exists for any other
`SharedPreferences`-backed setting.

## Testing

- `arb_completeness_test.dart`: key-set parity between `app_en.arb` and
  `app_he.arb`, pure JSON parsing, no widget dependency.
- `LocaleController` round-trips through `SharedPreferences` — unit test,
  same shape as any other `*Controller` in `settings_service.dart` (none
  currently has a dedicated test file; check whether one should be added
  here or whether `ThemeModeController` already has analogous coverage to
  mirror at plan-writing time).
- Settings screen widget test: selecting "עברית" persists and is
  reflected in `localeProvider`'s state.
- RTL smoke tests per §4 above: no overflow across the app's main screens
  in Hebrew, `Directionality` resolves to `rtl`.
- Date-formatting call sites: spot-check a couple of the 17 (not all 17
  individually — the fix is mechanically identical everywhere) with a
  unit or widget test confirming a Hebrew-locale session still renders
  `"16 JUL 2026"`-style output, not Hebrew month names.

## Out of scope this round

- Following the device's OS system locale automatically — this round is
  the manual picker only (per your approved choice); auto-detect-with-
  override is a natural, cheap follow-up later if wanted, not part of
  this pass.
- Localizing dates into Hebrew (calendar, month names, RTL date order) —
  explicitly rejected per your call; dates stay Gregorian/Latin always.
- A native-speaker review/correction pass on the Hebrew translation
  itself — flagged above as a recommended follow-up, not blocking.
- Hebrew App Store/Play Store metadata, app name, or icon — this is
  in-app UI translation only.
- Any other locale beyond English/Hebrew.
