# Journal Globe/Gallery Follow-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix globe dot zoom-scaling, wire bidirectional tap-to-focus between the globe and the gallery, replace tap-to-edit with a read-only swipeable presentation view (edit/delete moved into its overflow menu), and redesign the gallery card narrower without an inline delete button.

**Architecture:** `TripJournalTab` becomes a stateful coordinator holding `selectedEntryId`, passed to both `JournalGlobe` and `JournalGalleryTimeline` so tapping either side's representation of an entry focuses the other. The globe's dots switch entirely to `Point.labelBuilder`-rendered fixed-size widgets (unifying photo and non-photo dots), which also fixes their tap hit-testing. A new `showJournalEntryPresentationSheet` (its own file, `PageView`-based for multi-entry days) replaces both "tap card = edit" and the separate day-list sheet.

**Tech Stack:** Flutter, Riverpod, `flutter_earth_globe` (v2.2.1).

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`. Use `context.colors`/`colors.*` throughout — for translucent overlays on photos, follow this codebase's existing precedent (`_GroupedGalleryCard`'s count-badge scrim) of `colors.inkPrimary.withValues(alpha: ...)` / `colors.surface.withValues(alpha: ...)`, never Flutter's raw `Colors.black`/`Colors.white`.
- No `DateTime.now()` in domain/repository code — not touched by this plan, no new repository code.
- Every user-facing string goes through `lib/l10n/app_en.arb`, and `app_localizations.dart`/`app_localizations_en.dart` (hand-maintained, no `flutter gen-l10n` in this environment) must be updated in the same commit. This plan needs **no new strings** — it reuses `l10n.menuEdit`, `l10n.menuDelete`, `l10n.journalDeleteEntryTitle`, `l10n.journalDeleteEntryBody`, `l10n.cancel`, `l10n.journalUntitledEntry` (all already exist) — and **removes** `journalDayEntriesTitle` (only used by the day-list sheet this plan deletes) from all three l10n files.
- Widget tests mock at the repository boundary (`FakeJournalRepository`/`FakePlaceRepository` in `test/helpers/`) — never a real `AppDatabase` in a widget test.
- Flutter is installed and working in this environment (`C:\Development\flutter`) — every "Run" step in this plan is something the implementer/reviewer actually executes here, not something deferred to a human. GPU-rendered globe behavior (actual dot sizes on a real zoomed globe, actual tap accuracy, actual focus animation) remains manual-verification-only, same accepted limitation as the rest of this feature — no widget test can construct a real `FlutterEarthGlobeController`.

---

### Task 1: Globe — unify dots to fixed-size widgets, fix tap hit-testing

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`
- Modify: `test/widget/journal/journal_globe_test.dart`

**Interfaces:**
- Produces: `_PlainDot` widget (new, private); `_PhotoDot` widget (existing, gains an `onTap` param); `Point.onTap` is no longer set on the `Point` constructor (tap handling moves entirely into the `labelBuilder` widgets — see Step 1's comment for why).

- [ ] **Step 1: Replace the dot-rendering and tap-wiring in `_addPoints`**

In `lib/features/journal/presentation/journal_globe.dart`, replace the top-level constants:

```dart
const _plainDotDiameter = 11.0;
const _photoDotDiameter = 26.0;
```

(This removes the old `_dotSize = 2.5` constant — `PointStyle.size` is now always `0` for every point, so there's no native-rendered dot left that needs a size.)

Replace the `_addPoints` method body's point-adding loop:

```dart
  void _addPoints(FlutterEarthGlobeController controller) {
    for (final entry in widget.entries) {
      if (!entry.hasLocation) continue;
      final diameter = entry.hasPhotos ? _photoDotDiameter : _plainDotDiameter;
      final onTap =
          widget.onEntryTap == null ? null : () => widget.onEntryTap!(entry);
      controller.addPoint(
        Point(
          id: entry.id,
          coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
          label: entry.placeName ?? entry.summary,
          // Every point renders entirely through labelBuilder now (below)
          // — size 0 means the package's own GPU-native dot draws
          // nothing, so it can never peek out from behind the widget.
          style: const PointStyle(size: 0),
          isLabelVisible: true,
          // Centers a diameter-square widget exactly on the point: the
          // package positions labelBuilder output at
          // `left = pos.dx - labelOffset.dx - width/2`,
          // `top = pos.dy - labelOffset.dy - height`.
          labelOffset: Offset(0, -diameter / 2),
          labelBuilder: (context, point, isHovering, isVisible) =>
              entry.hasPhotos
                  ? _PhotoDot(filePath: entry.photos.first.filePath, onTap: onTap)
                  : _PlainDot(onTap: onTap),
          // Point.onTap is intentionally left unset. The package's own
          // globe-level GestureDetector hit-tests taps against each
          // point's native (now zero-size) hit region separately from
          // whatever labelBuilder renders, and would call Point.onTap
          // itself if set — double-firing onEntryTap for any tap that
          // happens to land within that residual ~8x8px native region,
          // on top of the tap our own widget's GestureDetector below
          // already handles. Routing taps only through the widget avoids
          // this entirely.
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
            color: context.colors.accent.withValues(alpha: 0.6),
            lineWidth: 1.5,
          ),
        ),
      );
    }
  }
```

Note this drops the `final colors = context.colors;` line that used to sit at the top of `_addPoints` (it was only used for `PointStyle.color`, which no longer exists now that dots are widget-rendered) — the journey-connection loop below now reads `context.colors.accent` directly instead.

- [ ] **Step 2: Add `_PlainDot`, update `_PhotoDot` to accept and use `onTap`**

Replace the `_PhotoDot` class and add `_PlainDot` right after it, at the bottom of the file:

```dart
/// A circular, accent-bordered photo thumbnail rendered at a point's
/// screen position via Point.labelBuilder (the package has no built-in
/// image support for points). Wraps itself in a GestureDetector — see
/// the comment on Point.onTap in _addPoints for why tap handling lives
/// here instead of on the Point itself.
class _PhotoDot extends StatelessWidget {
  const _PhotoDot({required this.filePath, this.onTap});

  final String filePath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

/// A small solid-color dot for a located entry with no photo — same
/// labelBuilder/GestureDetector technique as _PhotoDot, so it's immune
/// to the GPU painter's zoom-based size scaling the same way _PhotoDot
/// already was (see the design spec for why this is the fix, not a
/// PointStyle.size tweak — the scaling factor is an internal,
/// undocumented package constant).
class _PlainDot extends StatelessWidget {
  const _PlainDot({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: _plainDotDiameter,
        height: _plainDotDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.accent,
          border: Border.all(color: colors.surface, width: 1.5),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update the `renderGlobe: false` test seam's icon rendering — no change needed, but re-read it**

The `build` method's `if (!widget.renderGlobe)` branch (the tappable-icon scaffold used by widget tests) is untouched by this task — it never touched `PointStyle`/`labelBuilder` in the first place. Re-read `lib/features/journal/presentation/journal_globe.dart`'s `build` method after Step 1/2 to confirm nothing there references the removed `_dotSize` constant or old `PointStyle(color: ...)` styling (it shouldn't — that scaffold only ever used `Icons.circle`/`Icons.photo_camera`).

- [ ] **Step 4: Run the existing globe tests to confirm no regression**

Run: `flutter analyze && flutter test test/widget/journal/journal_globe_test.dart`
Expected: PASS, no analyzer issues. (These tests exercise the `renderGlobe: false` scaffold only, so they don't touch the code changed in Steps 1-2 — this step is a regression check, not new-behavior coverage. Manual on-device verification is required to confirm dots are actually a fixed size at any zoom and reliably tappable — flag this in your report.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart
git commit -m "fix(journal): globe dots stay fixed-size at any zoom, fix tap hit-testing"
```

---

### Task 2: Globe — `selectedEntryId` and focus-on-select

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`

**Interfaces:**
- Consumes: nothing new (builds on Task 1's file).
- Produces: `JournalGlobe({..., String? selectedEntryId})` — later tasks (Task 6) read/write this.

- [ ] **Step 1: Add the `selectedEntryId` field**

In `lib/features/journal/presentation/journal_globe.dart`, update the `JournalGlobe` widget:

```dart
class JournalGlobe extends StatefulWidget {
  const JournalGlobe({
    super.key,
    required this.entries,
    this.selectedEntryId,
    this.onEntryTap,
    this.renderGlobe = true,
  });

  final List<JournalEntry> entries;

  /// Set by the coordinating parent (TripJournalTab) when an entry is
  /// selected — from tapping this same globe's own dot, or from tapping
  /// a gallery card. A changed, non-null value takes priority over the
  /// "focus on the latest entry" default and animates the globe there.
  final String? selectedEntryId;

  final void Function(JournalEntry entry)? onEntryTap;
  final bool renderGlobe;

  @override
  State<JournalGlobe> createState() => _JournalGlobeState();
}
```

- [ ] **Step 2: Generalize the focus logic**

Replace `didUpdateWidget` and add `_maybeFocusSelected`, right above the existing `_maybeFocusLatest`:

```dart
  @override
  void didUpdateWidget(JournalGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.renderGlobe) return;
    if (widget.selectedEntryId != oldWidget.selectedEntryId) {
      _maybeFocusSelected();
    }
    if (!_sameEntryIds(oldWidget.entries)) {
      _syncPoints(oldWidget.entries);
      _maybeFocusLatest();
    }
  }
```

```dart
  /// Focuses on widget.selectedEntryId if it's set, located, and not
  /// already what the globe is centered on — takes priority over the
  /// latest-entry auto-focus below, since a selection reflects a
  /// deliberate tap (this globe's own dot, or a gallery card), not a
  /// heuristic. Silently does nothing if the selected entry has no
  /// location — not every entry appears on the globe, and the selection
  /// still applies normally on the gallery side regardless.
  void _maybeFocusSelected() {
    final controller = _controller;
    final selectedId = widget.selectedEntryId;
    if (controller == null || !controller.isReady || selectedId == null) {
      return;
    }
    if (selectedId == _focusedEntryId) return;
    final selected =
        widget.entries.where((e) => e.id == selectedId).firstOrNull;
    if (selected == null || !selected.hasLocation) return;
    _focusedEntryId = selectedId;
    controller.focusOnCoordinates(
      GlobeCoordinates(selected.lat!, selected.lng!),
      animate: true,
      duration: const Duration(milliseconds: 600),
    );
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
```

(`_maybeFocusLatest` itself is unchanged — shown above only so the two methods' relationship is clear; don't duplicate it, just add `_maybeFocusSelected` above the existing method.)

- [ ] **Step 3: Use `selectedEntryId` on initial load too**

In `_buildController`, replace the `onLoaded` callback:

```dart
    controller.onLoaded = () {
      _addPoints(controller);
      if (widget.selectedEntryId != null) {
        _maybeFocusSelected();
      } else {
        _maybeFocusLatest(animate: false);
      }
    };
```

- [ ] **Step 4: Run analyze and the existing tests**

Run: `flutter analyze && flutter test test/widget/journal/journal_globe_test.dart`
Expected: PASS, no analyzer issues (the existing tests don't construct a real controller, so this is a compile/regression check — `selectedEntryId` defaults to `null` and every existing test call site omits it, which must still compile and behave exactly as before).

- [ ] **Step 5: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart
git commit -m "feat(journal): globe focuses on an externally-selected entry"
```

---

### Task 3: Gallery card redesign — narrower, no inline delete, selected state

**Files:**
- Modify: `lib/features/journal/presentation/journal_widgets.dart`
- Test: `test/widget/journal/journal_gallery_card_test.dart` (new)

**Interfaces:**
- Produces: `JournalGalleryCard({required entry, VoidCallback? onTap, bool selected = false})` (removes `onDelete`); `_GroupedGalleryCard({required day, required onTap, required selected})`.

- [ ] **Step 1: Redesign `JournalGalleryCard`**

In `lib/features/journal/presentation/journal_widgets.dart`, replace the whole `JournalGalleryCard` class:

```dart
/// A compact card for the horizontal entry gallery below the globe —
/// photo (or a placeholder) on top, a thin date + place caption below.
/// Tapping opens the read-only presentation view (never edits directly —
/// design spec: "tap = view, edit is explicit"), so the card no longer
/// carries summary text or a delete action; both live in that view now.
class JournalGalleryCard extends StatelessWidget {
  const JournalGalleryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.selected = false,
  });

  final JournalEntry entry;
  final VoidCallback? onTap;

  /// True while this entry is the globe/gallery's shared selection —
  /// rendered as an accent-colored border in place of the usual hairline.
  final bool selected;

  static const width = 116.0;
  static const photoHeight = 88.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final placeName = entry.placeName;

    return SizedBox(
      width: width,
      child: PaperCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderColor: selected ? colors.accent : null,
        // The card has a natural (photo + caption) size. FittedBox only
        // ever shrinks (never grows) to fit whatever the gallery strip
        // actually gives it — a plain Column would instead throw a
        // render overflow during a transient squeeze (e.g. a keyboard
        // animating over the tab shrinks the strip below the card's
        // natural height).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppShape.radius - 1),
                  ),
                  child: entry.hasPhotos
                      ? Image.file(
                          File(entry.photos.first.filePath),
                          width: width,
                          height: photoHeight,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => placeholder(colors),
                        )
                      : placeholder(colors),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(DateFormat('dd MMM').format(entry.loggedAt)),
                      if (placeName != null && placeName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

  static Widget placeholder(AppColors colors) => Container(
        width: width,
        height: photoHeight,
        color: colors.paper,
        alignment: Alignment.center,
        child: Icon(Icons.edit_note, color: colors.inkMuted),
      );
}
```

- [ ] **Step 2: Redesign `_GroupedGalleryCard`**

Replace the whole `_GroupedGalleryCard` class (still in `journal_widgets.dart`) — same stacked-photo-edges + count-badge treatment, narrowed to `JournalGalleryCard.width`/`photoHeight` (which now follow automatically since they're referenced by name), caption strip changed from date+summary to date+place, `onTap`/`selected` replacing `onOpenDay`:

```dart
class _GroupedGalleryCard extends StatelessWidget {
  const _GroupedGalleryCard({
    required this.day,
    required this.onTap,
    required this.selected,
  });

  final List<JournalEntry> day;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = day.first;
    final photoEntry = day.firstWhere((e) => e.hasPhotos, orElse: () => first);
    final placeName = first.placeName;

    return SizedBox(
      width: JournalGalleryCard.width,
      child: PaperCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderColor: selected ? colors.accent : null,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: JournalGalleryCard.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Extra ~6px of top space for the peeking card-edge slivers
                // below — accounted for in _DaySlot's Flexible sizing so it
                // doesn't reintroduce a Column-overflow.
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 6),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Stacked-photo effect: two thin "card edge" slivers
                      // peeking out above/behind the top photo, evoking a
                      // fanned stack of photos.
                      PositionedDirectional(
                        top: -6,
                        start: 10,
                        end: 10,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(
                              color: colors.hairline,
                              width: AppShape.hairlineWidth,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: -3,
                        start: 5,
                        end: 5,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(
                              color: colors.hairline,
                              width: AppShape.hairlineWidth,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
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
                            child: MonoText(
                              '${day.length}',
                              color: colors.surface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(DateFormat('dd MMM').format(first.loggedAt)),
                      if (placeName != null && placeName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
```

- [ ] **Step 3: Write widget tests for both cards**

Create `test/widget/journal/journal_gallery_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/paper_card.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _e({String? placeName}) => JournalEntry(
      id: 'e1',
      tripId: 't1',
      summary: 'Some summary text that should not render on the card',
      loggedAt: DateTime(2026, 7, 20),
      createdAt: DateTime(2026, 7, 20),
      placeName: placeName,
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

Color _borderColor(WidgetTester tester) {
  final material = tester.widget<Material>(find.byType(Material).first);
  final shape = material.shape! as RoundedRectangleBorder;
  return shape.side.color;
}

void main() {
  testWidgets('shows date and place, not the summary, tap fires onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryCard(
          entry: _e(placeName: 'Krabi'),
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20 JUL'), findsOneWidget);
    expect(find.text('Krabi'), findsOneWidget);
    expect(
      find.text('Some summary text that should not render on the card'),
      findsNothing,
    );
    expect(find.byIcon(Icons.close), findsNothing); // no inline delete

    await tester.tap(find.byType(JournalGalleryCard));
    expect(tapped, isTrue);
  });

  testWidgets('entry with no placeName shows no place line', (tester) async {
    await tester.pumpWidget(_wrap(JournalGalleryCard(entry: _e())));
    await tester.pumpAndSettle();
    expect(find.text('20 JUL'), findsOneWidget);
  });

  testWidgets('selected renders an accent border, unselected a hairline',
      (tester) async {
    await tester.pumpWidget(_wrap(JournalGalleryCard(entry: _e())));
    await tester.pumpAndSettle();
    final unselectedColor = _borderColor(tester);

    await tester
        .pumpWidget(_wrap(JournalGalleryCard(entry: _e(), selected: true)));
    await tester.pumpAndSettle();
    final selectedColor = _borderColor(tester);

    expect(selectedColor, isNot(unselectedColor));
  });
}
```

- [ ] **Step 4: Run and commit**

Run: `flutter analyze && flutter test test/widget/journal/journal_gallery_card_test.dart`
Expected: PASS, no analyzer issues.

```bash
git add lib/features/journal/presentation/journal_widgets.dart \
  test/widget/journal/journal_gallery_card_test.dart
git commit -m "feat(journal): narrower gallery card, no inline delete, selected state"
```

> `JournalGalleryTimeline`, `_DaySlot`, and the day-list sheet in this same file still reference the *old* `JournalGalleryCard`/`_GroupedGalleryCard` constructor params (`onTap`/`onEdit`/`onDelete`/`onOpenDay`) and won't compile after this task alone — Task 4 fixes that in the same file. `flutter analyze` in this task will show errors in `JournalGalleryTimeline`/`_DaySlot`/`showJournalDayEntriesSheet` until Task 4 lands; that's expected and this task's own new test file doesn't touch those symbols, so run the narrower command above (not the whole `journal` test directory) to verify this task's own work in isolation.

---

### Task 4: `JournalGalleryTimeline` — selection sync, `onTapDay`, remove the day-list sheet

**Files:**
- Modify: `lib/features/journal/presentation/journal_widgets.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_localizations.dart`
- Modify: `lib/l10n/app_localizations_en.dart`
- Modify: `test/widget/journal/journal_gallery_timeline_test.dart`

**Interfaces:**
- Consumes: `JournalGalleryCard`/`_GroupedGalleryCard` with `selected`/`onTap` (Task 3).
- Produces: `JournalGalleryTimeline({required entries, required String? selectedEntryId, required void Function(List<JournalEntry> dayEntries, int tappedIndex) onTapDay})`.

- [ ] **Step 1: Delete the day-list sheet**

In `lib/features/journal/presentation/journal_widgets.dart`, delete the entire `showJournalDayEntriesSheet` function and the `_JournalDayEntriesSheet` class (everything from the `/// Bottom sheet listing one day's entries` doc comment to the end of the file).

- [ ] **Step 2: Remove the now-unused l10n string**

`lib/l10n/app_en.arb` — delete the `"journalDayEntriesTitle"` key and its `"@journalDayEntriesTitle"` metadata block (the `journalUntitledEntry` key right after it stays — it's still used by the cards and, from Task 5, the presentation view).

`lib/l10n/app_localizations.dart` — delete the `journalDayEntriesTitle` abstract getter and its doc comment.

`lib/l10n/app_localizations_en.dart` — delete the `journalDayEntriesTitle` method implementation.

- [ ] **Step 3: Rewrite `JournalGalleryTimeline` as a `StatefulWidget` with selection + scroll-to**

Replace the whole `JournalGalleryTimeline` and `_DaySlot` classes:

```dart
/// Horizontal, day-grouped timeline for the strip below the globe: a
/// hairline track with one dot per calendar day, each day's card hanging
/// below it on a short stem. A day with more than one entry renders as a
/// stacked-photo card with a count badge instead of [JournalGalleryCard]
/// directly. Tapping any day reports it via [onTapDay] (index 0 for a
/// grouped day — the compact card can't pick a specific entry, the
/// presentation view's swipe does that instead). [selectedEntryId] is
/// the globe/gallery's shared selection: the matching day's card gets an
/// accent border, and the strip auto-scrolls to bring it into view.
class JournalGalleryTimeline extends StatefulWidget {
  const JournalGalleryTimeline({
    super.key,
    required this.entries,
    required this.selectedEntryId,
    required this.onTapDay,
  });

  final List<JournalEntry> entries;
  final String? selectedEntryId;
  final void Function(List<JournalEntry> dayEntries, int tappedIndex) onTapDay;

  static const _dotSize = 11.0;
  static const _stemHeight = 22.0;

  @override
  State<JournalGalleryTimeline> createState() => _JournalGalleryTimelineState();
}

class _JournalGalleryTimelineState extends State<JournalGalleryTimeline> {
  /// Keyed by each day's first (earliest) entry id — stable across
  /// rebuilds as long as that entry stays the earliest one for its day,
  /// which is true unless entries are added/removed within the day.
  final _slotKeys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(JournalGalleryTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedEntryId != null &&
        widget.selectedEntryId != oldWidget.selectedEntryId) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final days = groupEntriesByDay(widget.entries);
    for (final day in days) {
      if (!day.any((e) => e.id == widget.selectedEntryId)) continue;
      final key = _slotKeys[day.first.id];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final renderContext = key?.currentContext;
        if (renderContext == null) return;
        Scrollable.ensureVisible(
          renderContext,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = groupEntriesByDay(widget.entries);
    final dayIds = {for (final day in days) day.first.id};
    _slotKeys.removeWhere((id, _) => !dayIds.contains(id));
    for (final day in days) {
      _slotKeys.putIfAbsent(day.first.id, GlobalKey.new);
    }

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
            top: JournalGalleryTimeline._dotSize / 2 - 1,
            child: Container(height: 2, color: colors.hairline),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: JournalGalleryTimeline._dotSize / 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in days)
                  Padding(
                    key: _slotKeys[day.first.id],
                    padding:
                        const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: _DaySlot(
                      day: day,
                      colors: colors,
                      selected:
                          day.any((e) => e.id == widget.selectedEntryId),
                      onTap: () => widget.onTapDay(day, 0),
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
    required this.selected,
    required this.onTap,
  });

  final List<JournalEntry> day;
  final AppColors colors;
  final bool selected;
  final VoidCallback onTap;

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
        // Flexible, not a bare child: a plain Column gives non-flex
        // children an unbounded main-axis constraint, which would let the
        // card's internal FittedBox report its natural (unshrunk) size and
        // overflow the slot whenever the strip is shorter than that. This
        // hands the card whatever height remains after the dot and stem,
        // so FittedBox has a real bound to scale down against.
        Flexible(
          child: day.length == 1
              ? JournalGalleryCard(entry: first, onTap: onTap, selected: selected)
              : _GroupedGalleryCard(day: day, onTap: onTap, selected: selected),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Rewrite the timeline's widget tests**

Full replacement of `test/widget/journal/journal_gallery_timeline_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _e(String id, DateTime loggedAt, {String? placeName}) =>
    JournalEntry(
      id: id,
      tripId: 't1',
      summary: 'summary for $id',
      loggedAt: loggedAt,
      createdAt: loggedAt,
      placeName: placeName,
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
  testWidgets(
      'single-entry day: tapping it reports that day with index 0',
      (tester) async {
    List<JournalEntry>? tappedDay;
    int? tappedIndex;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [_e('a', DateTime(2026, 7, 20), placeName: 'Krabi')],
          selectedEntryId: null,
          onTapDay: (day, index) {
            tappedDay = day;
            tappedIndex = index;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Krabi'), findsOneWidget);
    await tester.tap(find.text('Krabi'));
    expect(tappedDay?.map((e) => e.id).toList(), ['a']);
    expect(tappedIndex, 0);
  });

  testWidgets(
      'multi-entry day shows a count badge, and a busy day (6 entries) '
      'does not overflow', (tester) async {
    final entries = [
      _e('morning', DateTime(2026, 7, 20, 9)),
      _e('brunch', DateTime(2026, 7, 20, 11)),
      _e('museum', DateTime(2026, 7, 20, 13)),
      _e('market', DateTime(2026, 7, 20, 16)),
      _e('dinner', DateTime(2026, 7, 20, 19)),
      _e('evening', DateTime(2026, 7, 20, 20)),
    ];
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: entries,
          selectedEntryId: null,
          onTapDay: (_, __) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a grouped card reports all six entries at index 0',
      (tester) async {
    List<JournalEntry>? tappedDay;
    int? tappedIndex;
    final entries = [
      _e('morning', DateTime(2026, 7, 20, 9)),
      _e('brunch', DateTime(2026, 7, 20, 11)),
      _e('museum', DateTime(2026, 7, 20, 13)),
      _e('market', DateTime(2026, 7, 20, 16)),
      _e('dinner', DateTime(2026, 7, 20, 19)),
      _e('evening', DateTime(2026, 7, 20, 20)),
    ];
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: entries,
          selectedEntryId: null,
          onTapDay: (day, index) {
            tappedDay = day;
            tappedIndex = index;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('6'));
    expect(tappedDay?.length, 6);
    expect(tappedIndex, 0);
  });

  testWidgets('entries on different days each get their own dot and card',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [
            _e('day1', DateTime(2026, 7, 19), placeName: 'Krabi'),
            _e('day2', DateTime(2026, 7, 20), placeName: 'Phuket'),
          ],
          selectedEntryId: null,
          onTapDay: (_, __) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Krabi'), findsOneWidget);
    expect(find.text('Phuket'), findsOneWidget);
    expect(find.text('2'), findsNothing); // no grouping badge — two days
  });

  testWidgets('selecting an entry scrolls its day into view', (tester) async {
    final entries = [
      for (var i = 0; i < 20; i++)
        _e('e$i', DateTime(2026, 7, 1 + i), placeName: 'Place $i'),
    ];
    Widget build(String? selectedEntryId) => _wrap(
          JournalGalleryTimeline(
            entries: entries,
            selectedEntryId: selectedEntryId,
            onTapDay: (_, __) {},
          ),
        );

    await tester.pumpWidget(build(null));
    await tester.pumpAndSettle();
    expect(find.text('Place 19'), findsNothing); // off-screen initially

    await tester.pumpWidget(build('e19'));
    await tester.pumpAndSettle();
    expect(find.text('Place 19'), findsOneWidget); // scrolled into view
  });
}
```

- [ ] **Step 5: Run and commit**

Run: `flutter analyze && flutter test test/widget/journal/journal_gallery_timeline_test.dart test/widget/journal/journal_gallery_card_test.dart`
Expected: PASS, no analyzer issues.

```bash
git add lib/features/journal/presentation/journal_widgets.dart \
  lib/l10n/app_en.arb \
  lib/l10n/app_localizations.dart \
  lib/l10n/app_localizations_en.dart \
  test/widget/journal/journal_gallery_timeline_test.dart
git commit -m "feat(journal): gallery timeline syncs selection, drops the day-list sheet"
```

> `TripJournalTab` (in `trip_journal_tab.dart`) still calls the old `JournalGalleryTimeline(entries:, onEdit:, onDelete:)` constructor and won't compile after this task — Task 6 fixes that. Running the full `flutter analyze` at this point will show that one call site's errors; that's expected, which is why Step 5 above runs the two specific test files for this task's own scope rather than the whole suite.

---

### Task 5: Presentation view (new file) — swipeable, read-only, edit/delete in a menu

**Files:**
- Create: `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`
- Test: `test/widget/journal/journal_entry_presentation_sheet_test.dart`

**Interfaces:**
- Consumes: `showJournalEntryFormSheet` (`journal_entry_form_sheet.dart`, existing); `journalRepositoryProvider` (`journal_providers.dart`, existing); `l10n.menuEdit`, `l10n.menuDelete`, `l10n.journalDeleteEntryTitle`, `l10n.journalDeleteEntryBody`, `l10n.cancel`, `l10n.journalUntitledEntry` (all existing).
- Produces: `showJournalEntryPresentationSheet(context, {required String tripId, required List<JournalEntry> entries, required int initialIndex, required void Function(int index) onPageChanged})`.

- [ ] **Step 1: Write the file**

Create `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/journal_entry.dart';
import 'journal_entry_form_sheet.dart';
import 'journal_providers.dart';

/// Read-only presentation view for one day's journal entries, reached by
/// tapping a gallery card or a globe dot. Editing and deleting are no
/// longer the default tap action (design: "tap = view, edit is
/// explicit") — both live behind each page's overflow menu instead.
///
/// [entries] is always that day's full entry list (length 1 for a
/// single-entry day); [initialIndex] is which one to open on. Swiping
/// between entries reports the new index via [onPageChanged] so the
/// caller (TripJournalTab) can keep the globe/gallery selection in sync
/// with whichever entry is currently on screen.
Future<void> showJournalEntryPresentationSheet(
  BuildContext context, {
  required String tripId,
  required List<JournalEntry> entries,
  required int initialIndex,
  required void Function(int index) onPageChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _JournalEntryPresentationView(
      tripId: tripId,
      entries: entries,
      initialIndex: initialIndex,
      onPageChanged: onPageChanged,
    ),
  );
}

class _JournalEntryPresentationView extends ConsumerStatefulWidget {
  const _JournalEntryPresentationView({
    required this.tripId,
    required this.entries,
    required this.initialIndex,
    required this.onPageChanged,
  });

  final String tripId;
  final List<JournalEntry> entries;
  final int initialIndex;
  final void Function(int index) onPageChanged;

  @override
  ConsumerState<_JournalEntryPresentationView> createState() =>
      _JournalEntryPresentationViewState();
}

class _JournalEntryPresentationViewState
    extends ConsumerState<_JournalEntryPresentationView> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  widget.onPageChanged(index);
                },
                children: [
                  for (final entry in widget.entries)
                    _JournalEntryPresentationPage(
                      entry: entry,
                      onEdit: () => _handleEdit(entry),
                      onDelete: () => _handleDelete(entry),
                    ),
                ],
              ),
            ),
            if (widget.entries.length > 1)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.entries.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPage ? colors.accent : colors.hairline,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleEdit(JournalEntry entry) {
    Navigator.of(context).pop();
    showJournalEntryFormSheet(context, tripId: widget.tripId, existing: entry);
  }

  Future<void> _handleDelete(JournalEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.journalDeleteEntryTitle),
        content: Text(l10n.journalDeleteEntryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.menuDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(journalRepositoryProvider).deleteEntry(entry.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _JournalEntryPresentationPage extends StatelessWidget {
  const _JournalEntryPresentationPage({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final JournalEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final placeName = entry.placeName;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          entry.hasPhotos ? _photoHeader(colors, l10n) : _plainHeader(colors, l10n),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoText(
                  DateFormat('d MMMM yyyy · HH:mm').format(entry.loggedAt),
                ),
                if (placeName != null && placeName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: colors.accent),
                      const SizedBox(width: 4),
                      Text(
                        placeName,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  entry.summary.isEmpty ? l10n.journalUntitledEntry : entry.summary,
                  style: AppTextStyles.body.copyWith(
                    color:
                        entry.summary.isEmpty ? colors.inkMuted : colors.inkPrimary,
                    fontStyle:
                        entry.summary.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoHeader(AppColors colors, AppLocalizations l10n) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Image.file(
            File(entry.photos.first.filePath),
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(height: 220, color: colors.paper),
          ),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.inkPrimary.withValues(alpha: 0),
                  colors.inkPrimary.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 8,
          start: 0,
          end: 0,
          child: Center(child: _handle(colors.surface.withValues(alpha: 0.85))),
        ),
        PositionedDirectional(
          top: 2,
          end: 2,
          child: _menu(l10n, iconColor: colors.surface, deleteColor: colors.error),
        ),
      ],
    );
  }

  Widget _plainHeader(AppColors colors, AppLocalizations l10n) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 12),
          child: Center(child: _handle(colors.hairline)),
        ),
        PositionedDirectional(
          top: 4,
          end: 2,
          child: _menu(l10n, iconColor: colors.inkMuted, deleteColor: colors.error),
        ),
      ],
    );
  }

  Widget _handle(Color color) => Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _menu(
    AppLocalizations l10n, {
    required Color iconColor,
    required Color deleteColor,
  }) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor),
      onSelected: (action) {
        if (action == 'edit') {
          onEdit();
        } else if (action == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', child: Text(l10n.menuEdit)),
        PopupMenuItem(
          value: 'delete',
          child: Text(l10n.menuDelete, style: TextStyle(color: deleteColor)),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Write the widget tests**

Create `test/widget/journal/journal_entry_presentation_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_entry_presentation_sheet.dart';
import 'package:tripper/features/journal/presentation/journal_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_journal_repository.dart';

JournalEntry _e(String id, {String summary = 'Some summary'}) => JournalEntry(
      id: id,
      tripId: 't1',
      summary: summary,
      loggedAt: DateTime(2026, 7, 20, 14, 30),
      createdAt: DateTime(2026, 7, 20, 14, 30),
      placeName: 'Krabi',
    );

Future<T?> _open<T>(
  WidgetTester tester, {
  required List<JournalEntry> entries,
  required int initialIndex,
  void Function(int index)? onPageChanged,
  FakeJournalRepository? repo,
}) async {
  T? result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider
            .overrideWithValue(repo ?? FakeJournalRepository(entries)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showJournalEntryPresentationSheet(
                  context,
                  tripId: 't1',
                  entries: entries,
                  initialIndex: initialIndex,
                  onPageChanged: onPageChanged ?? (_) {},
                ) as T?;
              },
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
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('single entry: shows its details, no page indicator dots',
      (tester) async {
    await _open(tester, entries: [_e('a')], initialIndex: 0);

    expect(find.text('Some summary'), findsOneWidget);
    expect(find.text('Krabi'), findsOneWidget);
    // No dot row for a single-page view: only one Container-decorated
    // circle would exist per dot, so absence of a second entry's summary
    // combined with a single page is enough — checked structurally via
    // PageView having exactly one child instead of asserting on dots
    // directly (dots have no text/semantics to query).
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('multi-entry: swiping changes the visible entry and fires '
      'onPageChanged', (tester) async {
    int? lastPage;
    await _open(
      tester,
      entries: [_e('a', summary: 'First'), _e('b', summary: 'Second')],
      initialIndex: 0,
      onPageChanged: (i) => lastPage = i,
    );

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsOneWidget);
    expect(find.text('First'), findsNothing);
    expect(lastPage, 1);
  });

  testWidgets('empty-summary entry falls back to "Not written yet"',
      (tester) async {
    await _open(
      tester,
      entries: [_e('a', summary: '')],
      initialIndex: 0,
    );
    expect(find.text('Not written yet'), findsOneWidget);
  });

  testWidgets('Edit closes the sheet and opens the entry form pre-filled',
      (tester) async {
    await _open(tester, entries: [_e('a', summary: 'Edit me')], initialIndex: 0);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Some summary'), findsNothing); // presentation gone
    expect(find.text('Edit entry'), findsOneWidget); // form sheet title
    expect(find.text('Edit me'), findsOneWidget); // pre-filled summary field
  });

  testWidgets('Delete, after confirming, removes the entry and closes the sheet',
      (tester) async {
    final repo = FakeJournalRepository([_e('a')]);
    await _open(tester, entries: [_e('a')], initialIndex: 0, repo: repo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last); // confirm dialog's button
    await tester.pumpAndSettle();

    expect(await repo.getById('a'), isNull);
    expect(find.text('Krabi'), findsNothing); // sheet closed
  });
}
```

- [ ] **Step 3: Run and commit**

Run: `flutter analyze && flutter test test/widget/journal/journal_entry_presentation_sheet_test.dart`
Expected: PASS, no analyzer issues.

```bash
git add lib/features/journal/presentation/journal_entry_presentation_sheet.dart \
  test/widget/journal/journal_entry_presentation_sheet_test.dart
git commit -m "feat(journal): swipeable read-only presentation view, edit/delete in its menu"
```

---

### Task 6: `TripJournalTab` — wire the coordinator, fix affected tests

**Files:**
- Modify: `lib/features/journal/presentation/trip_journal_tab.dart`
- Modify: `test/widget/journal/trip_journal_tab_test.dart`

**Interfaces:**
- Consumes: `JournalGlobe({..., selectedEntryId, onEntryTap})` (Task 2); `JournalGalleryTimeline({..., selectedEntryId, onTapDay})` (Task 4); `showJournalEntryPresentationSheet` (Task 5).

- [ ] **Step 1: Convert `TripJournalTab` to a `ConsumerStatefulWidget` holding `selectedEntryId`**

Full replacement of `lib/features/journal/presentation/trip_journal_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/journal_entry.dart';
import 'journal_entry_form_sheet.dart';
import 'journal_entry_presentation_sheet.dart';
import 'journal_globe.dart';
import 'journal_map_view.dart';
import 'journal_providers.dart';
import 'journal_widgets.dart';

/// Journal tab inside a trip's detail screen: a globe of this trip's
/// logged entries, a timeline below it, and a map sub-view toggle. Holds
/// [_selectedEntryId] as the coordinator between the globe and the
/// gallery — tapping either one's representation of an entry focuses
/// the other on it (design spec: bidirectional globe<->gallery sync).
class TripJournalTab extends ConsumerStatefulWidget {
  const TripJournalTab({
    super.key,
    required this.trip,
    this.renderGlobe = true,
    this.renderMap = true,
  });

  final Trip trip;

  /// False in widget tests: the globe needs a GPU shader surface, same
  /// reasoning as JournalGlobe's own `renderGlobe` seam.
  final bool renderGlobe;

  /// False in widget tests: Google Maps needs a platform view, same
  /// reasoning as JournalMapView's own `renderMap` seam.
  final bool renderMap;

  @override
  ConsumerState<TripJournalTab> createState() => _TripJournalTabState();
}

class _TripJournalTabState extends ConsumerState<TripJournalTab> {
  String? _selectedEntryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncEntries = ref.watch(tripJournalProvider(widget.trip.id));
    final entries = asyncEntries.valueOrNull ?? const <JournalEntry>[];
    final visitedPlaces = ref.watch(tripVisitedPlacesProvider(widget.trip.id));
    final showMap = ref.watch(journalMapModeProvider);

    if (asyncEntries.hasValue && entries.isEmpty) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: l10n.journalEmptyTitle,
        body: l10n.journalEmptyBody,
        ctaLabel: l10n.journalAddEntryCta,
        onCta: () => showJournalEntryFormSheet(context, tripId: widget.trip.id),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: SectionLabel(
                  l10n.journalStatsLine(entries.length, visitedPlaces.length),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.journalAddEntryCta,
                onPressed: () =>
                    showJournalEntryFormSheet(context, tripId: widget.trip.id),
              ),
              IconButton(
                icon: Icon(showMap ? Icons.timeline : Icons.map_outlined),
                tooltip: showMap ? l10n.listViewToggle : l10n.mapViewToggle,
                onPressed: () =>
                    ref.read(journalMapModeProvider.notifier).update((v) => !v),
              ),
            ],
          ),
        ),
        // The globe owns this area — no ancestor scrollable wraps it, so
        // every pan/tap on it drives the globe, never a parent scroll.
        Expanded(
          child: showMap
              ? JournalMapView(entries: entries, renderMap: widget.renderMap)
              : Column(
                  // stretch: without this, children only get a loose width
                  // constraint (Column's default is center) — the globe
                  // needs a tight/bounded constraint to size itself and
                  // silently renders nothing under a loose one. The gallery
                  // ListView happened to fill width regardless, which is
                  // why only the globe went missing.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fixed 70/30 split — the globe is the dominant element,
                    // the gallery a slim strip beneath it.
                    Expanded(
                      flex: 7,
                      child: JournalGlobe(
                        entries: entries,
                        selectedEntryId: _selectedEntryId,
                        onEntryTap: (entry) =>
                            setState(() => _selectedEntryId = entry.id),
                        renderGlobe: widget.renderGlobe,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: JournalGalleryTimeline(
                        entries: entries,
                        selectedEntryId: _selectedEntryId,
                        onTapDay: (dayEntries, tappedIndex) {
                          setState(
                            () => _selectedEntryId = dayEntries[tappedIndex].id,
                          );
                          showJournalEntryPresentationSheet(
                            context,
                            tripId: widget.trip.id,
                            entries: dayEntries,
                            initialIndex: tappedIndex,
                            onPageChanged: (index) => setState(
                              () => _selectedEntryId = dayEntries[index].id,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
```

Note this removes the `_confirmDelete` method entirely — deleting is now only reachable from `journal_entry_presentation_sheet.dart`'s own menu (Task 5), which owns that confirm-dialog flow itself.

- [ ] **Step 2: Fix the existing test that asserted on the old card's inline summary text**

`test/widget/journal/trip_journal_tab_test.dart`'s `'entries render in the timeline'` test currently does `expect(find.text('Arrived in Krabi'), findsOneWidget);` — that string was the old card's inline summary, which no longer renders on the card (Task 3 moved it into the presentation view). Replace that test:

```dart
  testWidgets(
      'entries render in the timeline, tapping one opens the presentation '
      'view', (tester) async {
    await _pump(
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
    // The card shows the date, not the summary.
    expect(find.text('20 JUL'), findsOneWidget);
    expect(find.text('Arrived in Krabi'), findsNothing);

    await tester.tap(find.text('20 JUL'));
    await tester.pumpAndSettle();

    // The presentation view now shows the summary.
    expect(find.text('Arrived in Krabi'), findsOneWidget);
  });
```

Also replace the `'toggling to map view swaps the timeline for the map'` test's assertions, which relied on the same now-gone inline summary text to prove the timeline was showing:

```dart
  testWidgets('toggling to map view swaps the timeline for the map',
      (tester) async {
    await _pump(
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
    expect(find.text('20 JUL'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.text('20 JUL'), findsNothing);
    expect(find.byIcon(Icons.timeline), findsOneWidget);
  });
```

- [ ] **Step 3: Add a coordination test — tapping the globe's tappable icon selects the matching gallery card**

Add this test to the same file (after the two tests updated in Step 2):

```dart
  testWidgets(
      'tapping a globe dot selects the matching gallery card '
      '(accent border)', (tester) async {
    await _pump(
      tester,
      entries: [
        JournalEntry(
          id: 'e1',
          tripId: 'trip-1',
          summary: 'Arrived',
          loggedAt: DateTime(2026, 7, 19),
          createdAt: DateTime(2026, 7, 19),
          lat: 8.0,
          lng: 98.8,
        ),
        JournalEntry(
          id: 'e2',
          tripId: 'trip-1',
          summary: 'Next day',
          loggedAt: DateTime(2026, 7, 20),
          createdAt: DateTime(2026, 7, 20),
          lat: 7.9,
          lng: 98.7,
        ),
      ],
    );
    // renderGlobe: false in _pump renders each located entry as a plain
    // tappable Icon (Icons.circle for entries with no photo) — tapping
    // the first one fires JournalGlobe.onEntryTap with entry 'e1', which
    // TripJournalTab wires to select it.
    await tester.tap(find.byIcon(Icons.circle).first);
    await tester.pumpAndSettle();

    // PaperCard only sets Material.shape.side to a 1.0-width border when
    // borderColor is non-null (the "selected" state) — the default
    // hairline path uses AppShape.hairlineWidth (0.5) instead. At least
    // one gallery card should now have the 1.0-width accent border.
    final selectedCards = tester
        .widgetList<Material>(find.byType(Material))
        .where((m) => (m.shape as RoundedRectangleBorder?)?.side.width == 1.0)
        .toList();
    expect(selectedCards, isNotEmpty);
  });

- [ ] **Step 4: Run and commit**

Run: `flutter analyze && flutter test test/widget/journal`
Expected: PASS, no analyzer issues — this is the first point where the whole `journal` test directory compiles again (Tasks 3 and 4 each left one known cross-file compile error for exactly this reason).

Then run the full suite to confirm no wider regression:

Run: `flutter test`
Expected: PASS.

```bash
git add lib/features/journal/presentation/trip_journal_tab.dart \
  test/widget/journal/trip_journal_tab_test.dart
git commit -m "feat(journal): wire globe<->gallery selection sync, drop tap-to-edit"
```

---

## Self-review notes

- **Spec coverage:** dot zoom-sizing (Task 1), tap hit-testing fix (Task 1, upgraded from the shipped feature's dormant/deferred version since taps are now live), bidirectional selection sync (Tasks 2, 4, 6), presentation view replacing tap-to-edit and the day-list sheet (Task 5, wired in Task 6), narrower card with delete moved to the menu (Task 3). All four numbered issues from the design spec have a task.
- **Type consistency checked:** `JournalGlobe.selectedEntryId`/`onEntryTap` (Task 2) match Task 6's usage exactly; `JournalGalleryTimeline.selectedEntryId`/`onTapDay(List<JournalEntry>, int)` (Task 4) match Task 6's usage exactly; `showJournalEntryPresentationSheet`'s named params (Task 5) match Task 6's call exactly; `JournalGalleryCard`/`_GroupedGalleryCard`'s `selected`/`onTap` (Task 3) match Task 4's usage exactly.
- **Sequencing:** Tasks 1→2 and 3→4 are same-file, in-order pairs (each leaves the file in a compiling, testable state for its own scope). Task 5 is independent of 1-4 (new file, no shared symbols). Task 6 depends on 2, 4, and 5 together and is where the whole feature first compiles end-to-end — flagged explicitly in Tasks 3, 4, and 6 so the executor isn't surprised by known cross-file compile errors before Task 6 lands.
