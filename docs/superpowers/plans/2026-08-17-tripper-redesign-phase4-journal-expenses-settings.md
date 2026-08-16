# Tripper Redesign — Phase 4: Journal Chrome + Expenses/Settings Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out redesign rollout item 4 (spec §8: "Journal (globe reskin) + Expenses + Settings — lowest-risk batch, mostly token swaps") — fix a real dark-mode chrome bug in the Journal tab's floating top overlay, clean up three stale pre-redesign comments, and confirm (not invent work for) Expenses and Settings, which turn out to already be fully compliant.

**Architecture:** One task. Investigation against the current codebase (not just the spec) found this phase is much smaller than Phases 1–3: `journal_globe.dart`'s dots already render in coral (Phase 1's `AppColors` rewrite already migrated the actual color globally) and the bottom nav's selected-tab indicator already uses `colors.accent` (`app_theme.dart`'s `navigationBarTheme`) — both only have stale doc comments left over from the old teal/rust naming. The one real defect is `trip_journal_tab.dart`'s floating top chrome (`_GlassPill`, `_GlassIconButton`, `_TopEdgeScrim`): it hand-rolls translucent panels from theme-flipping `colors.inkPrimary`/`colors.surface` instead of the shared `GlassChrome` primitive. Because this chrome floats directly over the globe/map's unpredictable imagery — unlike `TripDetailScreen`'s topbar, which sits over a guaranteed-dark gradient scrim — `colors.inkPrimary` flipping to near-white in dark app-theme turns a "quiet dark glass pill" into a bright, inverted blob. The fix mirrors `TripDetailScreen`'s own topbar `GlassChrome` usage exactly (fixed `tint: AppColors.dark.surface`, fixed `AppColors.dark.inkPrimary` ink) — that widget already solves this exact problem correctly, in an analogous position.

**Tech Stack:** Flutter/Dart, existing `GlassChrome`/`AppColors` primitives (Phase 1) — no new dependencies, no domain/schema changes.

**Spec:** `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md` (§5 Journal globe bullet and Expenses/Settings bullet, §6 `journal_globe.dart` note). Phase 2a's plan (`docs/superpowers/plans/2026-08-15-tripper-redesign-phase2a-trips.md`, Task 5) is this plan's precedent for the `GlassChrome`-with-fixed-`tint`-over-unpredictable-imagery idiom, confirmed still in place at `lib/features/trips/presentation/trip_detail_screen.dart:121-124`.

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`. Chrome sitting over unpredictable imagery uses the *fixed* `AppColors.dark.*` reference values (not `context.colors`, which flips with the theme) — same convention Phase 2a's `GlassChrome`-wrapped topbar and `TripCard`'s cover scrim already established.
- One accent only (coral, `colors.accent` / `AppColors.accent`). This phase touches no interactive elements, only chrome tint and scrim gradients.
- Tests land in the same commit as the feature (CLAUDE.md rule 5).
- **Explicitly out of scope, decided during planning, not an oversight:** `_GalleryOverlay` (the bottom-edge scrim behind the gallery timeline strip) and every other Journal file — `journal_widgets.dart` (gallery cards), `journal_entry_presentation_sheet.dart`, `journal_map_view.dart`, `journal_location_picker.dart`, `journal_photo_viewer.dart` — all predate this redesign, were built and tuned across several earlier, separately-reviewed plans (journal-globe-gallery and its polish rounds), and the spec's own instruction is to "keep the flutter_earth_globe engine as-is" and reskin only "the surrounding chrome (top bar, bottom nav)." Their existing `colors.inkPrimary`/`colors.surface` scrim conventions are untouched by this plan.
- **Expenses and Settings need no code changes.** Confirmed directly (not assumed from the spec): `grep -rn "Color(0x\|Colors\." lib/features/expenses/presentation lib/features/settings/presentation` returns nothing but legitimate `Colors.transparent` sheet backgrounds; both features already use `PaperCard`/`context.colors` tokens exclusively. This plan does not touch either feature.

---

### Task 1: Journal floating chrome — fixed dark `GlassChrome`; stale comment cleanup

**Files:**
- Modify: `lib/features/journal/presentation/trip_journal_tab.dart`
- Modify: `lib/features/journal/presentation/journal_globe.dart` (two doc comments only)
- Modify: `lib/core/widgets/app_shell.dart` (one doc comment only)
- Test: `test/widget/journal/trip_journal_tab_test.dart` (extend)

**Interfaces:**
- Consumes: `GlassChrome` (`lib/core/widgets/glass_chrome.dart`, Phase 1), `AppColors.dark` fixed reference (Phase 2a's established pattern).
- Produces: nothing consumed by a later task — this is the plan's only task.

- [ ] **Step 1: Write the failing test**

The bug only manifests in dark app-theme (in light theme, `colors.inkPrimary` is already near-black, so the existing code happens to look right by coincidence). Add a dark-theme variant of the existing `_pump` helper and a new test, in `test/widget/journal/trip_journal_tab_test.dart`.

Add to the imports:

```dart
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/widgets/glass_chrome.dart';
import 'package:tripper/core/widgets/mono_text.dart';
```

Add a dark-theme pump helper after the existing `_pump` function:

```dart
Future<void> _pumpDark(
  WidgetTester tester, {
  List<JournalEntry> entries = const [],
}) async {
  final repo = FakeJournalRepository(entries);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider.overrideWithValue(repo),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body:
              TripJournalTab(trip: _trip, renderGlobe: false, renderMap: false),
        ),
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
}
```

Append a new test at the end of `main()`:

```dart
  testWidgets(
      'the floating top chrome stays a fixed dark glass panel in dark app '
      'theme, not an inverted bright one (regression: it used to hand-roll '
      'panels from theme-flipping colors.inkPrimary/colors.surface)',
      (tester) async {
    await _pumpDark(
      tester,
      entries: [
        JournalEntry(
          id: 'e1',
          tripId: 'trip-1',
          summary: 'Arrived in Krabi',
          loggedAt: DateTime(2026, 7, 20),
          createdAt: DateTime(2026, 7, 20),
        ),
      ],
    );

    // Both the stats pill and the two icon buttons are GlassChrome now,
    // each pinned to the fixed dark tint regardless of app theme.
    final glassChromes =
        tester.widgetList<GlassChrome>(find.byType(GlassChrome));
    expect(glassChromes.length, greaterThanOrEqualTo(3));
    for (final chrome in glassChromes) {
      expect(chrome.tint, AppColors.dark.surface);
    }

    // The stats line's ink is fixed dark-mode ink, not colors.surface
    // (which would be dark-theme's near-white-on-dark-card tone — wrong
    // against the glass panel's own fixed dark tint).
    final statsMono = tester
        .widgetList<MonoText>(find.byType(MonoText))
        .where((m) => m.text.toUpperCase().contains('ENTRIES'))
        .single;
    expect(statsMono.color, AppColors.dark.inkPrimary);

    // Same for both icon buttons' glyphs.
    expect(
      tester.widget<Icon>(find.byIcon(Icons.add)).color,
      AppColors.dark.inkPrimary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.map_outlined)).color,
      AppColors.dark.inkPrimary,
    );
  });
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `flutter test test/widget/journal/trip_journal_tab_test.dart`
Expected: FAIL — no `GlassChrome` exists anywhere in `TripJournalTab`'s tree yet (`_GlassPill`/`_GlassIconButton` are still hand-rolled `DecoratedBox`/`IconButton.styleFrom` panels), so `find.byType(GlassChrome)` finds nothing and the test fails at the `length` assertion.

- [ ] **Step 3: Migrate `_GlassPill`, `_GlassIconButton`, `_TopEdgeScrim` to fixed-tint `GlassChrome`**

In `lib/features/journal/presentation/trip_journal_tab.dart`, add to the imports (after the existing `flutter_riverpod` import):

```dart
import '../../../core/widgets/glass_chrome.dart';
```

Replace the stats-pill usage (inside `build`, the first `PositionedDirectional` block with the `_GlassPill` child):

```dart
        PositionedDirectional(
          top: 0,
          start: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: _GlassPill(
                child: MonoText(
                  l10n.journalStatsLine(entries.length, visitedPlaces.length),
                  color: AppColors.dark.inkPrimary,
                ),
              ),
            ),
          ),
        ),
```

(Only the `MonoText`'s `color:` argument changes here — from `colors.surface` to `AppColors.dark.inkPrimary`. The surrounding `PositionedDirectional`/`SafeArea`/`Padding` are unchanged.)

Replace the `_GlassPill` class:

```dart
/// A small translucent glass pill — the on-glass equivalent of
/// SectionLabel for content that floats directly over the globe/map.
/// Fixed `AppColors.dark.surface` tint (not theme-aware `colors.surface`):
/// this chrome sits directly over the globe/map's own unpredictable
/// imagery with no guaranteed-dark scrim behind it (unlike
/// TripDetailScreen's cover hero, which has one) — a theme-aware fill
/// would turn near-white in dark app-theme and read as a bright blob
/// instead of a quiet dark tint. Mirrors TripDetailScreen's own topbar
/// GlassChrome usage (trip_detail_screen.dart), the same "floating chrome
/// over unpredictable cover art" position.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassChrome(
      borderRadius: BorderRadius.circular(20),
      tint: AppColors.dark.surface,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.xs,
        ),
        child: child,
      ),
    );
  }
}
```

Replace the `_GlassIconButton` class:

```dart
/// A circular glass icon button on the same fixed-dark backdrop as
/// [_GlassPill] — the add-entry and map/list-toggle actions, floating on
/// the globe itself. See [_GlassPill]'s doc comment for why the tint is
/// fixed rather than theme-aware.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    return GlassChrome(
      borderRadius: BorderRadius.circular(_size / 2),
      tint: AppColors.dark.surface,
      child: IconButton(
        icon: Icon(icon, color: AppColors.dark.inkPrimary, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          minimumSize: const Size(_size, _size),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
```

Replace the `_TopEdgeScrim` class:

```dart
/// A short fade at the very top of the globe/map, smoothing the hairline
/// seam against the TabBar above — fixed `AppColors.dark.paper`-based
/// gradient (not theme-aware `colors.inkPrimary`), same reasoning as
/// [_GlassPill]: this sits directly over the globe/map's own
/// unpredictable imagery, so the scrim must read as "quiet dark" in both
/// app themes, matching TripCard's and TripDetailScreen's cover-scrim
/// convention.
class _TopEdgeScrim extends StatelessWidget {
  const _TopEdgeScrim();

  static const _height = 28.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.dark.paper.withValues(alpha: 0.22),
            AppColors.dark.paper.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test again to confirm it passes**

Run: `flutter test test/widget/journal/trip_journal_tab_test.dart`
Expected: PASS (all tests, including the new dark-theme one).

- [ ] **Step 5: Fix the two stale comments in `journal_globe.dart`**

In `lib/features/journal/presentation/journal_globe.dart`, replace lines 34-36:

```dart
// One accent, coral — component rule 1 ("one accent, not two"; see
// docs/superpowers/specs/2026-08-14-tripper-redesign-design.md §4) means
// the halo has to be a low-alpha version of the same accent, not a new
// hue.
```

(The `const _haloAlpha = 0.28;` line immediately below is unchanged — only the comment above it changes.)

Replace the doc comment on `_GlobeLoadingIndicator` (originally lines 788-791):

```dart
/// Covers the sphere while its surface texture is still decoding — a
/// pulsing coral ring rather than Material's default
/// [CircularProgressIndicator], which reads as generic chrome against this
/// app's serif/mono/hairline visual language.
```

- [ ] **Step 6: Fix the stale comment in `app_shell.dart`**

In `lib/core/widgets/app_shell.dart`, replace the class doc comment (lines 14-17):

```dart
/// Bottom-nav shell: Trips / Vault / Places (SPEC — 3 tabs, coral active).
/// Bar sits on the paper tone with a soft hairline — no hard edge.
/// Also hosts the share-target listener: a file shared into Tripper opens
/// the save-to-vault sheet from any screen.
```

- [ ] **Step 7: Run the journal + app_shell-adjacent test folders**

Run: `flutter test test/widget/journal test/unit/journal`
Expected: PASS — confirms `journal_globe_test.dart`/`journal_globe_zoom_test.dart` (untouched behavior) and every other `trip_journal_tab_test.dart` case (untouched behavior — only the two new assertions target the fix) still pass.

- [ ] **Step 8: Run `flutter analyze` and the whole suite**

Run: `flutter analyze`
Expected: No issues — confirms the removed `final colors = context.colors;` locals in `_GlassPill`/`_GlassIconButton`/`_TopEdgeScrim` (no longer used once the fixed tokens replace them) don't leave an unused-variable warning, and nothing else regressed.

Run: `flutter test`
Expected: PASS — this is the last (and only) task in the plan; confirm nothing anywhere else regressed.

- [ ] **Step 9: Commit**

```bash
git add lib/features/journal/presentation/trip_journal_tab.dart lib/features/journal/presentation/journal_globe.dart lib/core/widgets/app_shell.dart test/widget/journal/trip_journal_tab_test.dart
git commit -m "fix(journal): pin floating chrome to fixed dark glass tokens; retire stale teal comments"
```
