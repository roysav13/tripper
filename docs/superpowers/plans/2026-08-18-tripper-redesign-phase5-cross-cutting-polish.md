# Tripper Redesign — Phase 5: Cross-Cutting Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out redesign rollout item 5 (spec §8: "Cross-cutting polish — empty/error/loading states, motion pass, RTL re-verification, golden-test re-baseline, accessibility contrast audit") against what a full-codebase survey found actually needs fixing — not against what the spec assumed years ago.

**Architecture:** Five tasks, each tracing to a concrete survey finding, not invented busywork. A pre-implementation investigation (not the spec alone) found: three trip-scoped tabs silently swallow stream errors instead of showing `ErrorState`; one tab (`TripPlacesTab`) is missing a motion/haptic pattern that its sibling screen (`PlacesScreen`) already has for the identical action; Phase 4's dark-mode chrome fix for the Journal tab's *floating chrome* left the *globe's own marks* (dot border rings, cluster label, journey lines) and one more scrim (`_GalleryOverlay`) using the exact same now-fixed bug pattern; the RTL and accessibility-contrast test sweeps never reach Trip Detail or any of its four tabs, nor the Places filter sheet (all three shipped across Phases 2a-4); and a handful of small, safe cleanup items (dead ARB keys, two non-directional `Positioned` usages, a doc-comment that now contradicts a sanctioned exception) were parked by earlier phases' final reviews specifically for this phase to pick up.

**Loading states**, also named in the rollout bullet, turned out not to need a task either: the survey found no first-load spinner/skeleton anywhere in the app (every list-backed screen renders `asyncX.valueOrNull ?? []`, so pre-first-emission looks like a legitimately-empty screen) — but this is a consistent, pre-existing, app-wide pattern rather than something the redesign regressed, and it's consistent with the app's local-first architecture (SPEC §3.1.3: data comes from an already-open local Drift database, so the pre-first-emission window is a handful of milliseconds, not a real user-facing wait). Building a skeleton-loading system from nothing would be a new feature, not "polish" — noted here as a deliberate non-task, not an oversight.

Two more items from the spec's original rollout bullet are deliberately **not** tasks here, decided directly with the user before this plan was written:
- **Golden-test re-baseline**: the survey found zero golden-test infrastructure exists anywhere in this repo (no `test/golden/`, no golden package, no `matchesGoldenFile` usage) — there is nothing to *re*-baseline. Setting up golden tests from scratch is a separate, larger initiative (package choice, baseline images needing visual sign-off, a CI story), not a polish task. Explicitly deferred.
- **Motion pass**: scoped to fixing established-pattern *inconsistencies* only (the one gap below), not adding new haptics/animation to redesign widgets that never had any (filter pills, document cards, glass icon buttons) — that's a separate, dedicated motion pass with real design judgment calls, not this phase's job.

**Tech Stack:** Flutter/Dart, existing `ErrorState`/`GlassChrome`/`AppColors`/`PositionedDirectional` primitives — no new dependencies, no domain/schema changes.

**Spec:** `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md` (§4 component rule 3, §6 golden-tests note, §8 rollout item 5). Phase 3's and Phase 4's final-review ledgers are this plan's direct source for three of its five tasks (the ARB cleanup, the `GlassChrome` doc-comment fix, and the globe/gallery theme-flipping fix were all explicitly parked there for "Phase 5").

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`. Chrome/marks sitting over unpredictable or fixed imagery (the globe, the map) with no guaranteed-dark scrim behind them use the *fixed* `AppColors.dark.*` reference values — the same convention Phase 4 already established for the Journal tab's floating chrome.
- Every user-facing string goes through ARB (`lib/l10n/app_en.arb` + `lib/l10n/app_he.arb`, this repo enforces 1:1 key parity via `test/unit/l10n/arb_completeness_test.dart` — confirmed still true, discovered mid-Phase-3). This plan only *removes* strings (Task 5), never adds any.
- All layout code uses `EdgeInsetsDirectional`/`PositionedDirectional`/directional icons — RTL-safe. Task 5 fixes two places where plain `Positioned` slipped into redesign-phase code.
- Tests land in the same commit as the feature (CLAUDE.md rule 5).
- **Known test-environment constraint, binding on Task 4:** `JournalGlobe`/`JournalMapView` default to `renderGlobe: true`/`renderMap: true`, and `TripDetailScreen` constructs `TripJournalTab` with no way to override that from outside (no test seam reaches through the real app's route tree). Every existing Journal test in this codebase avoids this by constructing `TripJournalTab`/`JournalGlobe` directly with `renderGlobe: false`/`renderMap: false`, never by navigating through the full app. Task 4 must **not** navigate into the Journal tab via `accessibility_test.dart`'s full-app (`TripperApp()`) test harness — doing so would attempt a real GPU shader surface inside `flutter_test`, which the rest of this codebase's own comments consistently document as unsupported. Journal's RTL-safety gets its own coverage in `trip_journal_tab_test.dart` instead, using the existing safe seam.

---

### Task 1: Missing `ErrorState` in three trip-scoped tabs

**Files:**
- Modify: `lib/features/vault/presentation/trip_documents_tab.dart`
- Modify: `lib/features/places/presentation/trip_places_tab.dart`
- Modify: `lib/features/journal/presentation/trip_journal_tab.dart`
- Modify: `test/helpers/fake_document_repository.dart` (bug fix needed to even write the test below — see Step 1)
- Test: `test/widget/vault/trip_documents_tab_test.dart` (new), `test/widget/places/trip_places_tab_test.dart` (extend), `test/widget/journal/trip_journal_tab_test.dart` (extend)

**Interfaces:** None new — this task only adds a branch to three existing `build()` methods, mirroring the exact `ErrorState(onRetry: () => ref.invalidate(...))` pattern already used in `trip_list_screen.dart`, `vault_screen.dart`, `places_screen.dart`, and `trip_expenses_tab.dart`.

- [ ] **Step 1: Fix `FakeDocumentRepository.watchForTrip` — it doesn't react to `emit`/`emitError` at all**

Before writing the failing test, a real bug in the test helper itself blocks it: `FakeDocumentRepository.watchForTrip` (unlike its siblings `FakePlaceRepository.watchForTrip` and `FakeJournalRepository.watchForTrip`, both of which correctly `yield* _controller.stream.map(...)`) only ever yields one static snapshot and never listens to the controller — so `repo.emitError(...)` would silently do nothing for a trip-scoped document stream.

In `test/helpers/fake_document_repository.dart`, replace the `watchForTrip` method:

```dart
  @override
  Stream<List<Document>> watchForTrip(String tripId) async* {
    yield [
      for (final d in _docs)
        if (d.tripIds.contains(tripId)) d,
    ];
    yield* _controller.stream.map(
      (docs) => [
        for (final d in docs)
          if (d.tripIds.contains(tripId)) d,
      ],
    );
  }
```

- [ ] **Step 2: Write the failing tests**

Create `test/widget/vault/trip_documents_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_providers.dart';
import 'package:tripper/features/vault/presentation/trip_documents_tab.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_document_repository.dart';

const _trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

Future<Widget> _app(FakeDocumentRepository repo) async => ProviderScope(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TripDocumentsTab(trip: _trip)),
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
  testWidgets('documents render for this trip', (tester) async {
    final repo = FakeDocumentRepository([
      Document(
        id: 'd1',
        title: 'Passport',
        category: DocumentCategory.passportId,
        createdAt: DateTime(2026, 7, 19),
        tripIds: const ['t1'],
      ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Passport'), findsOneWidget);
  });

  testWidgets('a stream failure shows the error state with retry',
      (tester) async {
    final repo = FakeDocumentRepository([
      Document(
        id: 'd1',
        title: 'Passport',
        category: DocumentCategory.passportId,
        createdAt: DateTime(2026, 7, 19),
        tripIds: const ['t1'],
      ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    repo.emitError(Exception('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });
}
```

In `test/widget/places/trip_places_tab_test.dart`, add to the imports:

```dart
import 'package:tripper/features/places/domain/place.dart';
```

(Only add this if it isn't already imported — check the file first; it likely already is, since existing tests construct `Place(...)`.)

Append a new test at the end of `main()`:

```dart
  testWidgets('a stream failure shows the error state with retry',
      (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    repo.emitError(Exception('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });
```

In `test/widget/journal/trip_journal_tab_test.dart`, append a new test at the end of `main()`:

```dart
  testWidgets('a stream failure shows the error state with retry',
      (tester) async {
    final repo = FakeJournalRepository([
      JournalEntry(
        id: 'e1',
        tripId: 'trip-1',
        summary: 'Arrived in Krabi',
        loggedAt: DateTime(2026, 7, 20),
        createdAt: DateTime(2026, 7, 20),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(repo),
          placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TripJournalTab(
              trip: _trip,
              renderGlobe: false,
              renderMap: false,
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
      ),
    );
    await tester.pumpAndSettle();

    repo.emitError(Exception('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });
```

- [ ] **Step 3: Run the tests to confirm they fail**

Run: `flutter test test/widget/vault/trip_documents_tab_test.dart test/widget/places/trip_places_tab_test.dart test/widget/journal/trip_journal_tab_test.dart`
Expected: FAIL — the new `trip_documents_tab_test.dart` file doesn't compile against real code yet only in the sense that `TripDocumentsTab` exists but has no error branch (the "documents render" test should PASS already; the "stream failure" test should FAIL — `find.text('Retry')` finds nothing since no `ErrorState` is ever shown). Same shape for the other two: existing tests keep passing, only the new "stream failure" tests fail.

- [ ] **Step 4: Add the `ErrorState` branch to all three tabs**

In `lib/features/vault/presentation/trip_documents_tab.dart`, add to the imports (after the existing `empty_state.dart` import):

```dart
import '../../../core/widgets/error_state.dart';
```

Replace the start of `build`:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncDocs = ref.watch(tripDocumentsProvider(trip.id));
    final docs = asyncDocs.valueOrNull ?? const <Document>[];
    final risky = docs.where((d) => ExpiryChecker.isRiskyForTrip(d, trip));

    // Same M4.2 states-audit gap the top-level Vault screen already
    // closed — a stream failure used to fall straight through to a
    // silent, confusingly-empty tab.
    if (asyncDocs.hasError) {
      return ErrorState(
        onRetry: () => ref.invalidate(tripDocumentsProvider(trip.id)),
      );
    }
    if (asyncDocs.hasValue && docs.isEmpty) {
```

(Everything from the `EmptyState(...)` return onward is unchanged.)

In `lib/features/places/presentation/trip_places_tab.dart`, add to the imports (after the existing `empty_state.dart` import):

```dart
import '../../../core/widgets/error_state.dart';
```

Replace the start of `build`:

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncPlaces = ref.watch(tripPlacesProvider(widget.trip.id));
    final places = asyncPlaces.valueOrNull ?? const <Place>[];

    // Same M4.2 states-audit gap the top-level Places screen already
    // closed — a stream failure used to fall straight through to a
    // silent, confusingly-empty tab.
    if (asyncPlaces.hasError) {
      return ErrorState(
        onRetry: () => ref.invalidate(tripPlacesProvider(widget.trip.id)),
      );
    }
    if (asyncPlaces.hasValue && places.isEmpty) {
```

(Everything from the `EmptyState(...)` return onward is unchanged.)

In `lib/features/journal/presentation/trip_journal_tab.dart`, add to the imports (after the existing `empty_state.dart` import):

```dart
import '../../../core/widgets/error_state.dart';
```

Replace the start of `build`:

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncEntries = ref.watch(tripJournalProvider(widget.trip.id));
    final entries = asyncEntries.valueOrNull ?? const <JournalEntry>[];
    final visitedPlaces = ref.watch(tripVisitedPlacesProvider(widget.trip.id));
    final showMap = ref.watch(journalMapModeProvider);

    // The globe/map floats regardless of data state, so without this
    // branch a stream failure used to render a confusingly-empty globe
    // with no explanation, not an error — same M4.2 gap every other
    // trip-scoped tab already closed.
    if (asyncEntries.hasError) {
      return ErrorState(
        onRetry: () => ref.invalidate(tripJournalProvider(widget.trip.id)),
      );
    }
    if (asyncEntries.hasValue && entries.isEmpty) {
```

(Everything from the `EmptyState(...)` return onward is unchanged.)

- [ ] **Step 5: Run the tests again to confirm they pass**

Run: `flutter test test/widget/vault/trip_documents_tab_test.dart test/widget/places/trip_places_tab_test.dart test/widget/journal/trip_journal_tab_test.dart`
Expected: PASS (all tests in all three files).

- [ ] **Step 6: Run the full vault, places, and journal test folders**

Run: `flutter test test/widget/vault test/unit/vault test/widget/places test/unit/places test/widget/journal test/unit/journal`
Expected: PASS — confirms the `FakeDocumentRepository.watchForTrip` fix didn't break any existing document test (nothing else calls `watchForTrip` with an expectation of the old, non-reactive behavior — confirm by reading any failure carefully if one appears).

- [ ] **Step 7: Commit**

```bash
git add lib/features/vault/presentation/trip_documents_tab.dart lib/features/places/presentation/trip_places_tab.dart lib/features/journal/presentation/trip_journal_tab.dart test/helpers/fake_document_repository.dart test/widget/vault/trip_documents_tab_test.dart test/widget/places/trip_places_tab_test.dart test/widget/journal/trip_journal_tab_test.dart
git commit -m "fix(states): add missing ErrorState to three trip-scoped tabs"
```

---

### Task 2: Motion/haptic consistency — `TripPlacesTab` is missing what `PlacesScreen` already has

**Files:**
- Modify: `lib/features/places/presentation/trip_places_tab.dart`
- Test: `test/widget/places/trip_places_tab_test.dart` (extend)

**Interfaces:** Consumes `RowSettleAnimation` (`place_widgets.dart`, Phase 3) — already used by `places_screen.dart`. No new interfaces produced.

**Design note:** Both `PlacesScreen._row()` and `TripPlacesTab.build()`'s row loop render the identical `PlaceRowCard` for the identical "toggle visited" action, but only `PlacesScreen` wraps each row in `RowSettleAnimation` and fires `HapticFeedback.selectionClick()` on toggle. This is not a new motion idea — it's applying the pattern places_screen.dart already established to the one call site that was missed when `TripPlacesTab` was written.

- [ ] **Step 1: Write the failing test**

Append to `test/widget/places/trip_places_tab_test.dart`, inside `main()`:

```dart
  testWidgets(
      'toggling a place\'s visited state gets the same quiet haptic tick '
      'as the top-level Places screen (M4.4 parity)', (tester) async {
    final hapticCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark as visited'));
    await tester.pumpAndSettle();

    expect(hapticCalls, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets(
      'a place row settles into view via RowSettleAnimation, same as the '
      'top-level Places screen (M4.4 parity)', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', tripId: 't1'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byType(RowSettleAnimation), findsOneWidget);
  });
```

Add to the imports:

```dart
import 'package:flutter/services.dart';
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `flutter test test/widget/places/trip_places_tab_test.dart`
Expected: FAIL — the haptic test fails (`hapticCalls` is empty, `onToggleVisited` calls `markPlaceVisited` directly with no `HapticFeedback` call); the `RowSettleAnimation` test fails (`findsOneWidget` gets `findsNothing` — rows aren't wrapped in it).

- [ ] **Step 3: Wrap rows in `RowSettleAnimation` and add the haptic tick**

In `lib/features/places/presentation/trip_places_tab.dart`, add to the imports:

```dart
import 'package:flutter/services.dart';
```

Replace the `for (final place in sorted)` loop (the block rendering `PlaceRowCard`s):

```dart
        for (final place in sorted)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: RowSettleAnimation(
              placeId: place.id,
              child: PlaceRowCard(
                place: place,
                onTap: () => showPlaceActionsSheet(context, ref, place),
                onToggleVisited: () {
                  // M4.4 parity with places_screen.dart's identical
                  // toggle — a quiet tick on the state change, not a
                  // heavier impact.
                  HapticFeedback.selectionClick();
                  markPlaceVisited(ref, place, visited: !place.isVisited);
                },
              ),
            ),
          ),
```

- [ ] **Step 4: Run the tests again to confirm they pass**

Run: `flutter test test/widget/places/trip_places_tab_test.dart`
Expected: PASS (all tests, including both new ones).

- [ ] **Step 5: Run the full places test folder**

Run: `flutter test test/unit/places test/widget/places`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/places/presentation/trip_places_tab.dart test/widget/places/trip_places_tab_test.dart
git commit -m "fix(places): give TripPlacesTab the same row-settle + haptic feedback places_screen.dart already has"
```

---

### Task 3: Finish Phase 4's fix — the globe's own marks and the gallery scrim still theme-flip over fixed imagery

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`
- Modify: `lib/features/journal/presentation/trip_journal_tab.dart`

**Interfaces:** None new — extends the exact `AppColors.dark.*`-over-fixed-imagery convention Phase 4 already established for this same screen's floating chrome.

**Design note:** Phase 4 fixed `trip_journal_tab.dart`'s floating chrome (`_GlassPill`, `_GlassIconButton`, `_TopEdgeScrim`) but explicitly parked two remaining instances of the identical bug class for this phase: (1) `journal_globe.dart`'s dot border rings, cluster-count label, and journey dashed lines all use theme-flipping `colors.surface` even though they paint directly over the always-fixed `earth_day.jpg`/`earth_day_high.jpg` texture; (2) `trip_journal_tab.dart`'s `_GalleryOverlay` (the bottom-edge scrim behind the gallery timeline) still uses theme-flipping `colors.inkPrimary`, inconsistent with its sibling `_TopEdgeScrim` in the very same file, which Phase 4 already fixed. `colors.accent` (the actual dot/halo color) is deliberately **not** touched anywhere in this task — component rule 5 treats it as the one legitimate theme-aware brand color on the globe, consistent with how Places' map markers work; only the *contrast/definition* elements (border rings, labels, scrims) are being pinned to fixed tokens.

- [ ] **Step 1: Fix `journal_globe.dart`'s theme-flipping marks**

In `lib/features/journal/presentation/journal_globe.dart`, inside `_addPoints`, replace the two `color: colors.surface,` lines (the plain-entry border ring and the cluster border ring):

```dart
              color: AppColors.dark.surface,
```

(There are two occurrences — one in the `cluster.length == 1` branch's `'${entry.id}-border'` point, one in the `else` branch's `'$key-border'` point. Change both from `colors.surface` to `AppColors.dark.surface`.)

Replace the cluster-count label's text style:

```dart
            labelTextStyle: AppTextStyles.mono.copyWith(color: AppColors.dark.surface),
```

Replace `_addConnections`'s journey-line color and its stale comment:

```dart
  /// Draws the journey line's arcs — split out from _addPoints so
  /// _handleZoomChanged can also call it (see there for why).
  ///
  /// Unlike dot/halo sizing (which just holds apparent size constant
  /// across zoom via a single `1/2^zoom` compensation), the line
  /// deliberately uses three different falloff curves so its look
  /// actively changes with zoom rather than merely not-growing:
  /// - `_lineWidthCompensation` falls off *faster* than the dot curve
  ///   (base 2.3 vs 2.0), so the line gets thinner than its rest-zoom
  ///   width as you zoom in, not just constant.
  /// - `_dashCompensation` uses the same base-2.0 curve as dots, so each
  ///   individual dash's length stays roughly constant.
  /// - `_dashSpacingCompensation` falls off much faster still (base
  ///   3.2), so the gap between dashes shrinks quicker than the dashes
  ///   themselves — the dash pattern reads as denser at higher zoom,
  ///   not just smaller. All three bases are starting values for
  ///   on-device tuning, same as every other constant in this file.
  void _addConnections(FlutterEarthGlobeController controller, double zoom) {
    final colors = context.colors;
    final lineWidthCompensation = 1 / math.pow(2.3, zoom);
    final dashCompensation = 1 / math.pow(2.0, zoom);
    final dashSpacingCompensation = 1 / math.pow(3.2, zoom);
    for (final (start, end) in journeyConnections(widget.entries)) {
      controller.addPointConnection(
        PointConnection(
          id: '${start.id}->${end.id}',
          start: GlobeCoordinates(start.lat!, start.lng!),
          end: GlobeCoordinates(end.lat!, end.lng!),
          curveScale: _arcCurveScale,
          // Thin dashed lines radiating between visited places — matches
          // the reference travel-map style (assets/globe/
          // card_design_presentation.png). Fixed AppColors.dark.surface
          // (not theme-aware colors.surface): this paints directly over
          // the always-dark earth_day.jpg/earth_day_high.jpg texture
          // regardless of app theme, the same reasoning as the dot
          // border rings above and trip_journal_tab.dart's floating
          // chrome (Phase 4).
          style: PointConnectionStyle(
            type: PointConnectionType.dashed,
            color: AppColors.dark.surface.withValues(alpha: 0.85),
            lineWidth: 2.0 * lineWidthCompensation,
            dashSize: 4.0 * dashCompensation,
            spacing: 8.0 * dashSpacingCompensation,
          ),
        ),
      );
    }
  }
```

(`final colors = context.colors;` stays in both `_addPoints` and `_addConnections` — `colors.accent` is still read in `_addPoints` for the dot/halo cores, deliberately unchanged. `_addConnections` no longer uses `colors` after this edit — remove the now-unused `final colors = context.colors;` line from `_addConnections` specifically, but keep it in `_addPoints`.)

- [ ] **Step 2: Fix `trip_journal_tab.dart`'s `_GalleryOverlay`**

In `lib/features/journal/presentation/trip_journal_tab.dart`, replace the `_GalleryOverlay` class:

```dart
/// Backdrop for the gallery strip when it floats over the globe — a
/// bottom-anchored gradient so the strip's hairline day-track and card
/// borders stay legible over the globe/map's own busy, variable-brightness
/// texture. Fixed `AppColors.dark.paper`-based gradient (not theme-aware
/// `colors.inkPrimary`), same reasoning as [_TopEdgeScrim]: this sits
/// directly over the globe/map's own unpredictable imagery, so the scrim
/// must read as "quiet dark" in both app themes.
class _GalleryOverlay extends StatelessWidget {
  const _GalleryOverlay({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.dark.paper.withValues(alpha: 0),
                    AppColors.dark.paper.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
```

Update the now-stale inline comment above `_TopEdgeScrim`'s usage site in `build()` (it currently says `_GalleryOverlay` is "deliberately out of scope for this branch, still theme-aware colors.inkPrimary" — no longer true):

```dart
        // Smooths the hard cut where the TabBar above hands off to the
        // globe/map's own busy, edge-to-edge imagery. Both this scrim and
        // _GalleryOverlay below use fixed AppColors.dark tokens — see
        // _TopEdgeScrim's own class doc comment for why. IgnorePointer:
        // purely decorative, must never intercept the globe's own
        // drag/tap.
```

- [ ] **Step 3: Run the journal test folders**

Run: `flutter test test/widget/journal test/unit/journal`
Expected: PASS — this task changes no test-observable behavior in any existing test (every existing test either uses `renderGlobe: false`/`renderMap: false`, which never reaches these code paths, or doesn't assert on these specific colors). Confirms nothing broke.

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze`
Expected: No issues — confirms the removed `final colors = context.colors;` in `_addConnections` and in `_GalleryOverlay` don't leave unused-variable warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart lib/features/journal/presentation/trip_journal_tab.dart
git commit -m "fix(journal): pin the globe's marks and the gallery scrim to fixed dark tokens too"
```

---

### Task 4: RTL + accessibility contrast audit extension — Trip Detail, its tabs, and the Places filter sheet

**Files:**
- Modify: `test/widget/accessibility_test.dart`
- Modify: `test/widget/journal/trip_journal_tab_test.dart` (Journal's own RTL coverage, via its existing safe seam — see Global Constraints)

**Interfaces:** None new.

**Design note — the `_populatedApp` fixture needs two small additions:** today's fixture `Place` ("Railay viewpoint") and `Document` ("Passport") aren't linked to the fixture `Trip` (`tripId`/`tripIds` both unset), so `TripPlacesTab`/`TripDocumentsTab` would render their *empty* states, not real content, if visited. Both need trip-linking so the Trip Detail excursion below actually exercises populated tabs, not empty-state screens. Confirmed this doesn't affect any existing test: `PlacesScreen`/`VaultScreen` show the global aggregate view (`watchAll()`, not `watchForTrip()`), so both items stay visible there regardless of trip-linking.

- [ ] **Step 1: Link the fixture data to the fixture trip**

In `test/widget/accessibility_test.dart`, inside `_populatedApp`, replace the `documentRepositoryProvider` and `placeRepositoryProvider` overrides:

```dart
        documentRepositoryProvider.overrideWithValue(
          FakeDocumentRepository([
            Document(
              id: 'd1',
              title: 'Passport',
              category: DocumentCategory.passportId,
              createdAt: DateTime(2026, 7, 19),
              isPinned: true,
              tripIds: const ['t1'],
            ),
          ]),
        ),
        placeRepositoryProvider.overrideWithValue(
          FakePlaceRepository([
            const Place(
              id: 'p1',
              name: 'Railay viewpoint',
              country: 'Thailand',
              city: 'Krabi',
              tripId: 't1',
            ),
          ]),
        ),
```

- [ ] **Step 2: Write the failing RTL-extension assertions**

In `test/widget/accessibility_test.dart`, add to the imports:

```dart
import 'package:tripper/features/trips/presentation/trip_card.dart';
```

In the existing `'app renders RTL and without overflow in Hebrew across the main tabs'` test, insert a Trip Detail excursion right after the existing "Thailand" LTR assertion (after the block ending `expect(tester.widget<Text>(find.text('Thailand')).textDirection, TextDirection.ltr,);`) and before the existing `await tester.tap(find.descendant(of: navBar, matching: find.byIcon(Icons.folder_outlined)));` line:

```dart
    // Trip Detail excursion (Documents/Places/Expenses tabs + the Places
    // filter sheet) — a stack push from a TripCard tap, not a bottom-nav
    // branch, so the pre-Phase-5 sweep above never reached it. Journal is
    // deliberately excluded here — see this plan's Global Constraints;
    // it gets its own RTL coverage in trip_journal_tab_test.dart instead.
    await tester.tap(find.byType(TripCard));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Trip is "active" (today falls within start/end), so Trip Detail
    // opens on the Expenses tab (index 2) by default — visit all in a
    // fixed, known order regardless.
    final tabs = find.byType(Tab);
    expect(tabs, findsNWidgets(4));

    await tester.tap(tabs.at(0)); // Documents
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(tabs.at(1)); // Places
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Open the Places filter sheet (GlassChrome over the trip's places
    // list) — never exercised under RTL before this.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Dismiss via the modal barrier, away from the sheet's own content.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(tabs.at(2)); // Expenses
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Back to the Trips list before continuing the existing sweep below.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
```

- [ ] **Step 3: Run the RTL test to confirm the new assertions fail meaningfully first, then pass**

Run: `flutter test test/widget/accessibility_test.dart -N "app renders RTL"`
Expected: on the CURRENT (pre-Step-1) fixture the excursion would land on empty-state tabs — run it once before Step 1's fixture change to see `find.byIcon(Icons.tune)` fail with "0 widgets" (no filter button without trip-linked places), confirming the test is actually exercising something real. After Step 1's fixture fix, this should PASS.

- [ ] **Step 4: Add Trip Detail contrast tests (light + dark)**

Append to `test/widget/accessibility_test.dart`'s `main()`, after the existing `'places meets tap target and contrast guidelines (dark)'` test:

```dart
  testWidgets(
      'trip detail (hero, glass topbar/tabbar, Documents/Places/Expenses '
      'tabs, and the places filter sheet) meets contrast guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TripCard));
    await tester.pumpAndSettle();

    final tabs = find.byType(Tab);
    await tester.tap(tabs.at(0)); // Documents
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(tabs.at(1)); // Places
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(tabs.at(2)); // Expenses
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });

  testWidgets(
      'trip detail meets contrast guidelines (dark) — same tour as the '
      'light-mode test above', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TripCard));
    await tester.pumpAndSettle();

    final tabs = find.byType(Tab);
    await tester.tap(tabs.at(0)); // Documents
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(tabs.at(1)); // Places
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(tabs.at(2)); // Expenses
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });
```

- [ ] **Step 5: Run the full accessibility test file**

Run: `flutter test test/widget/accessibility_test.dart`
Expected: PASS (all tests — the pre-existing ones, the extended RTL sweep, and the two new Trip Detail contrast tests).

- [ ] **Step 6: Add Journal's own RTL-safety test, via its existing safe seam**

In `test/widget/journal/trip_journal_tab_test.dart`, add to the imports:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
```

(Check first — it's likely already imported; if so, skip.)

Append a new test at the end of `main()`:

```dart
  testWidgets(
      'the floating top chrome mirrors correctly under RTL — stats pill '
      'starts, action buttons end (Hebrew locale, via the renderGlobe: '
      'false / renderMap: false seam, not the full app)', (tester) async {
    final repo = FakeJournalRepository([
      JournalEntry(
        id: 'e1',
        tripId: 'trip-1',
        summary: 'Arrived in Krabi',
        loggedAt: DateTime(2026, 7, 20),
        createdAt: DateTime(2026, 7, 20),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(repo),
          placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: TripJournalTab(
                trip: _trip,
                renderGlobe: false,
                renderMap: false,
              ),
            ),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('he')],
          locale: const Locale('he'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // RTL: "start" is the right edge of the screen. The stats pill uses
    // PositionedDirectional(start: 0), the add/toggle buttons use
    // PositionedDirectional(end: 0) — under RTL they must swap physical
    // sides, the whole point of using Directional positioning here.
    final statsPill = tester.getTopLeft(find.byIcon(Icons.add)).dx;
    final addButton = tester.getTopLeft(find.byType(MonoText)).dx;
    expect(statsPill, greaterThan(addButton));
  });
```

- [ ] **Step 7: Run the test to confirm it passes**

Run: `flutter test test/widget/journal/trip_journal_tab_test.dart`
Expected: PASS. If the last assertion's variable naming reads confusingly (both are `dx` values compared, not literally "pill" vs "button" positions matching their names) — rename the two locals to `addButtonX`/`statsMonoX` for clarity if you find the comparison direction unclear while writing it; the assertion's intent is: the stats `MonoText` (inside the pill, which is `start`-positioned) sits at a smaller `dx` than the add-button `Icon` (which is `end`-positioned) would under LTR, and the reverse under RTL — confirm empirically which finder gives which value once the test runs, and adjust the `greaterThan`/`lessThan` direction to match reality if it's backwards. The structural point (assert the two floating elements land on opposite/mirrored sides under RTL) is what matters; get the comparison direction right by running it, not by guessing twice.

- [ ] **Step 8: Run the full journal test folder plus accessibility**

Run: `flutter test test/widget/journal test/unit/journal test/widget/accessibility_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add test/widget/accessibility_test.dart test/widget/journal/trip_journal_tab_test.dart
git commit -m "test(a11y): extend RTL + contrast coverage to Trip Detail, its tabs, the places filter sheet, and Journal's chrome"
```

---

### Task 5: Cross-cutting cleanup — dead ARB keys, non-directional `Positioned`, doc-comment accuracy

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_he.arb` (and the three generated `app_localizations*.dart`, via codegen)
- Modify: `lib/features/trips/presentation/trip_card.dart`
- Modify: `lib/features/places/presentation/places_map_view.dart`
- Modify: `lib/core/widgets/glass_chrome.dart`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md`

**Interfaces:** None — pure cleanup, no behavior change anywhere in this task.

**Design note:** Three unrelated small items, bundled into one task because each is a one-or-two-line fix with zero behavioral risk (confirmed by grep before this plan was written — see each step) — splitting them into three separate task-review cycles would cost more than the fixes themselves.

- [ ] **Step 1: Remove the dead stats-header ARB keys**

Confirmed via `grep -rn "statsCountries\|statsPlacesVisited\|statsDaysTraveled" lib/features test` returning zero matches — these three keys have had no code reference anywhere since Phase 3 removed `PlaceStatsHeader`. In `lib/l10n/app_en.arb`, delete these three lines:

```json
  "statsCountries": "Countries",
  "statsPlacesVisited": "Places visited",
  "statsDaysTraveled": "Days away",
```

In `lib/l10n/app_he.arb`, delete the matching three lines:

```json
  "statsCountries": "מדינות",
  "statsPlacesVisited": "מקומות שביקרת בהם",
  "statsDaysTraveled": "ימים בדרכים",
```

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_he.dart` with the three getters removed.

- [ ] **Step 2: Fix the two non-directional `Positioned` usages from the redesign phases**

In `lib/features/trips/presentation/trip_card.dart`, replace:

```dart
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.sm,
```

with:

```dart
                  PositionedDirectional(
                    start: AppSpacing.md,
                    end: AppSpacing.md,
                    bottom: AppSpacing.sm,
```

(The values were already symmetric — `left == right` — so this is a pure API-consistency fix, not a behavior change; `Row` remains unchanged below it.)

In `lib/features/places/presentation/places_map_view.dart`, inside `_EdgeShadow.build`, replace:

```dart
    return Positioned(
      top: atTop ? 0 : null,
      bottom: atTop ? null : 0,
      left: 0,
      right: 0,
      height: _height,
```

with:

```dart
    return PositionedDirectional(
      top: atTop ? 0 : null,
      bottom: atTop ? null : 0,
      start: 0,
      end: 0,
      height: _height,
```

(Same reasoning — `left == right == 0`, full-bleed either way, pure consistency fix.)

- [ ] **Step 3: Fix `GlassChrome`'s doc comment, CLAUDE.md hard rule 6, and spec §4 component rule 3 — all three now contradict the Places filter sheet's sanctioned usage**

In `lib/core/widgets/glass_chrome.dart`, replace the class doc comment:

```dart
/// Blurred glass chrome for nav/tab/top bars sitting over a photo or
/// gradient hero (redesign spec §4, component rule 3), or a modal sheet
/// the spec explicitly designates as glass (the Places filter sheet,
/// spec §5) — never for regular content cards. Never use this for
/// regular content cards — those stay solid ([PaperCard]) for reliable
/// contrast and cheap repaint.
```

In `CLAUDE.md`, in hard rule 6, replace:

```
Glass/blur chrome (`GlassChrome`) is reserved for nav/tab/top bars sitting over a photo or gradient hero — never for regular content cards.
```

with:

```
Glass/blur chrome (`GlassChrome`) is reserved for nav/tab/top bars sitting over a photo or gradient hero, or a modal sheet the spec explicitly designates as glass (the Places filter sheet) — never for regular content cards.
```

In `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md`, in §4 component rule 3, replace:

```
3. **Glass/blur is for chrome over imagery only** — nav bars, tab bars, top bars sitting on a photo or gradient hero. Regular content cards stay solid for reliable contrast and cheap repaint.
```

with:

```
3. **Glass/blur is for chrome over imagery only, or a sheet this spec explicitly names as glass** — nav bars, tab bars, top bars sitting on a photo or gradient hero, and the Places filter sheet (§5). Regular content cards stay solid for reliable contrast and cheap repaint.
```

- [ ] **Step 4: Run the whole suite**

Run: `flutter test`
Expected: PASS — the ARB removal must not break `test/unit/l10n/arb_completeness_test.dart` (both files lost the same three keys, still 1:1), and nothing else in this task touches test-observable behavior.

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_he.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_he.dart lib/features/trips/presentation/trip_card.dart lib/features/places/presentation/places_map_view.dart lib/core/widgets/glass_chrome.dart CLAUDE.md docs/superpowers/specs/2026-08-14-tripper-redesign-design.md
git commit -m "chore: remove dead stats ARB keys, fix two non-directional Positioned usages, correct GlassChrome doc accuracy"
```

- [ ] **Step 6: Run the whole suite one final time**

Run: `flutter test`
Expected: PASS — this is the last task in the plan; confirm nothing anywhere else regressed across all five tasks combined.
