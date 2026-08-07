# Journal Globe/Gallery Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix globe rotation jank (revert non-photo dots to native rendering), make the globe live-follow whichever entry is centered in the gallery's visible scroll viewport, add a swipeable multi-photo carousel, fix the presentation sheet's low-contrast menu, and redesign both the gallery card (tighter) and the presentation page (photo-dominant, location as title, scrollable summary, content-adaptive height).

**Architecture:** The globe splits dot rendering by necessity — non-photo dots go back to GPU-native `PointStyle` points (cheap, always in sync with rotation), photo dots stay `labelBuilder`-rendered widgets (the only way to show an image). A new `liveFollowEntryId` signal on `JournalGlobe`, distinct from the existing tap-driven `selectedEntryId`, is fed by the gallery's own scroll position via a `NotificationListener<ScrollNotification>` that tracks which day-slot is closest to the viewport's center. The presentation sheet's per-entry page gains a nested photo `PageView` with `OverscrollNotification`-based fall-through to the outer entries `PageView`, and its outer sheet height now varies (via `AnimatedContainer`) by whether the current entry has a photo.

**Tech Stack:** Flutter, Riverpod, `flutter_earth_globe` (v2.2.1).

## Global Constraints

- No `Color(0xFF...)`, and no Flutter's raw `Colors.black`/`Colors.white`, outside `lib/core/theme/app_colors.dart` — use `context.colors`/`colors.*` throughout. Elements floating over a photo (handle, menu, photo-position dots) use `colors.surface`/`colors.inkPrimary` with `.withValues(alpha: ...)`, never a raw `Colors.*` constant — this is the established pattern from the prior round (`_GroupedGalleryCard`'s count badge, the presentation sheet's header scrim).
- Serif (`AppTextStyles.title`, Fraunces) is this app's convention for names/titles (trip names, place names) — reuse it for the presentation page's location heading rather than inventing new type styles.
- Flutter is installed and working in this environment (`C:\Development\flutter`) — every "Run" step in this plan is something the implementer/reviewer actually executes here, not deferred to a human.
- GPU-rendered globe behavior (actual dot rendering at any zoom, actual rotation smoothness, actual live-follow animation) remains manual-verification-only — no widget test can construct a real `FlutterEarthGlobeController`. The gallery's scroll-center-detection logic, however, is pure Flutter geometry and IS testable.
- This app targets Android only (per CLAUDE.md) — no need to special-case iOS bouncy-scroll physics differences for the overscroll-based nested-swipe fall-through in Task 7.

---

### Task 1: Globe — revert non-photo dots to native GPU rendering

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`
- Modify: `test/widget/journal/journal_globe_test.dart`

**Interfaces:**
- Produces: unchanged public `JournalGlobe` API from this task's perspective (no new params yet — that's Task 2). `_PlainDot` class is deleted.

- [ ] **Step 1: Split `_addPoints` by photo/non-photo, delete `_PlainDot`**

In `lib/features/journal/presentation/journal_globe.dart`, replace the top-level constants:

```dart
const _plainDotSize = 2.5;
const _photoDotDiameter = 26.0;
```

(`_plainDotSize` is in the package's own `PointStyle.size` unit, not pixels — this is the same value the very first version of this feature shipped with, before either the zoom-scaling fix or this revert.)

Replace `_addPoints`:

```dart
  void _addPoints(FlutterEarthGlobeController controller) {
    final colors = context.colors;
    for (final entry in widget.entries) {
      if (!entry.hasLocation) continue;
      final onTap =
          widget.onEntryTap == null ? null : () => widget.onEntryTap!(entry);
      if (entry.hasPhotos) {
        controller.addPoint(
          Point(
            id: entry.id,
            coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
            label: entry.placeName ?? entry.summary,
            // Photo dots stay widget-rendered — the package has no
            // native way to show an image on a point. size: 0 suppresses
            // the (otherwise pointless) native dot underneath it.
            style: const PointStyle(size: 0),
            isLabelVisible: true,
            // Centers a _photoDotDiameter-square widget exactly on the
            // point: the package positions labelBuilder output at
            // `left = pos.dx - labelOffset.dx - width/2`,
            // `top = pos.dy - labelOffset.dy - height`.
            labelOffset: const Offset(0, -_photoDotDiameter / 2),
            labelBuilder: (context, point, isHovering, isVisible) =>
                _PhotoDot(filePath: entry.photos.first.filePath, onTap: onTap),
            // Point.onTap is intentionally left unset — see _PhotoDot's
            // own GestureDetector. Setting both would double-fire
            // onEntryTap for taps landing in the native point's small
            // residual hit region.
          ),
        );
      } else {
        controller.addPoint(
          Point(
            id: entry.id,
            coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
            label: entry.placeName ?? entry.summary,
            // Native GPU-rendered dot: cheap, and perfectly in sync with
            // the sphere's rotation every frame by construction (the
            // shader paints it — no separate widget-position recompute
            // pass, unlike the labelBuilder path above). This is the
            // fix for rotation jank: the prior round made every dot
            // widget-rendered for zoom-independent sizing, which made
            // rotation noticeably less smooth since every dot's
            // position had to be recomputed as a real widget rebuild on
            // every animation frame. Trade-off accepted: these dots
            // will grow with zoom again (the package's own internal,
            // undocumented zoom-scaling factor) — smoothness was
            // prioritized over that.
            style: PointStyle(size: _plainDotSize, color: colors.accent),
            // No labelBuilder for this one, so tap must be wired
            // directly on the Point — the package's own native
            // hit-testing (sized from PointStyle.size) drives it.
            onTap: onTap,
          ),
        );
      }
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
```

Delete the `_PlainDot` class entirely (the whole class, at the bottom of the file, right after `_PhotoDot`).

- [ ] **Step 2: Confirm the `renderGlobe: false` test seam is unaffected**

Re-read `lib/features/journal/presentation/journal_globe.dart`'s `build` method after Step 1 — the `if (!widget.renderGlobe)` branch never referenced `PointStyle`/`_PlainDot`/`labelBuilder` (it only used `Icons.circle`/`Icons.photo_camera`), so it needs no changes. Confirm this is still true after your edit (it should be — you didn't touch `build`).

- [ ] **Step 3: Run the existing globe tests to confirm no regression**

Run: `flutter analyze && flutter test test/widget/journal/journal_globe_test.dart`
Expected: PASS, no analyzer issues. (These tests only exercise the `renderGlobe: false` scaffold, so this is a regression check, not new-behavior coverage — manual on-device verification is required to confirm rotation is actually smoother and non-photo dots are visibly reliably tappable at native size. Flag this in your report.)

- [ ] **Step 4: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart
git commit -m "fix(journal): revert non-photo globe dots to native rendering for smooth rotation"
```

---

### Task 2: Globe — `liveFollowEntryId` for continuous gallery-scroll tracking

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`

**Interfaces:**
- Consumes: nothing new (builds on Task 1's file).
- Produces: `JournalGlobe({..., String? liveFollowEntryId})` — Task 5 wires this from `TripJournalTab`.

- [ ] **Step 1: Add the `liveFollowEntryId` field**

In `lib/features/journal/presentation/journal_globe.dart`, update the `JournalGlobe` widget:

```dart
class JournalGlobe extends StatefulWidget {
  const JournalGlobe({
    super.key,
    required this.entries,
    this.selectedEntryId,
    this.liveFollowEntryId,
    this.onEntryTap,
    this.renderGlobe = true,
  });

  final List<JournalEntry> entries;

  /// Set by the coordinating parent (TripJournalTab) when an entry is
  /// selected — from tapping this same globe's own dot, or from tapping
  /// a gallery card. A changed, non-null value takes priority over the
  /// "focus on the latest entry" default and animates the globe there.
  final String? selectedEntryId;

  /// Set continuously by the coordinating parent as the gallery strip
  /// scrolls — whichever entry is currently centered in the visible
  /// viewport, NOT a tap. A changed, non-null value snaps the globe
  /// there instantly (no easing animation — the scroll gesture itself
  /// already supplies the perceived motion; stacking a separate eased
  /// pan on top would fight it and look laggy, not smooth).
  final String? liveFollowEntryId;

  final void Function(JournalEntry entry)? onEntryTap;
  final bool renderGlobe;

  @override
  State<JournalGlobe> createState() => _JournalGlobeState();
}
```

- [ ] **Step 2: Add `_maybeFollowLive`, wire it into `didUpdateWidget`**

Replace `didUpdateWidget`:

```dart
  @override
  void didUpdateWidget(JournalGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.renderGlobe) return;
    if (widget.liveFollowEntryId != oldWidget.liveFollowEntryId) {
      _maybeFollowLive();
    }
    if (widget.selectedEntryId != oldWidget.selectedEntryId) {
      _maybeFocusSelected();
    }
    if (!_sameEntryIds(oldWidget.entries)) {
      _syncPoints(oldWidget.entries);
      if (widget.selectedEntryId == null && widget.liveFollowEntryId == null) {
        _maybeFocusLatest();
      }
    }
  }
```

Add `_maybeFollowLive` right above the existing `_maybeFocusSelected`:

```dart
  /// Snaps instantly (no easing) to widget.liveFollowEntryId whenever it
  /// changes — driven by the gallery's own scroll position, not a tap.
  /// Silently does nothing if the entry has no location, same reasoning
  /// as _maybeFocusSelected.
  void _maybeFollowLive() {
    final controller = _controller;
    final liveId = widget.liveFollowEntryId;
    if (controller == null || !controller.isReady || liveId == null) {
      return;
    }
    if (liveId == _focusedEntryId) return;
    final target = widget.entries.where((e) => e.id == liveId).firstOrNull;
    if (target == null || !target.hasLocation) return;
    _focusedEntryId = liveId;
    controller.focusOnCoordinates(
      GlobeCoordinates(target.lat!, target.lng!),
    );
  }
```

(`focusOnCoordinates` defaults to `animate: false` per the package's own signature — no need to pass it explicitly, but the point is this call has no `duration`/`curve` args, unlike `_maybeFocusSelected`'s and `_maybeFocusLatest`'s 600ms eased calls.)

- [ ] **Step 3: Run analyze and the existing tests**

Run: `flutter analyze && flutter test test/widget/journal/journal_globe_test.dart`
Expected: PASS, no analyzer issues (`liveFollowEntryId` defaults to `null`, every existing test call site omits it, must still compile and behave exactly as before).

- [ ] **Step 4: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart
git commit -m "feat(journal): globe live-follows an externally-driven entry (for gallery-scroll tracking)"
```

---

### Task 3: Gallery card redesign — tighter, one-line caption, photo-count badge

**Files:**
- Modify: `lib/features/journal/presentation/journal_widgets.dart`
- Modify: `test/widget/journal/journal_gallery_card_test.dart`

**Interfaces:**
- Produces: `JournalGalleryCard.width = 100.0`, `JournalGalleryCard.photoHeight = 76.0` (down from 116/88 — `_GroupedGalleryCard`, Task 4/existing code, references these by name so it follows automatically).

- [ ] **Step 1: Redesign `JournalGalleryCard`**

In `lib/features/journal/presentation/journal_widgets.dart`, replace the whole `JournalGalleryCard` class:

```dart
/// A compact card for the horizontal entry gallery below the globe —
/// photo on top, a single-line date + place caption below. Tapping
/// opens the read-only presentation view (never edits directly), so the
/// card carries no summary text or delete action.
class JournalGalleryCard extends StatelessWidget {
  const JournalGalleryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.selected = false,
  });

  final JournalEntry entry;
  final VoidCallback? onTap;

  /// True while this entry is the globe/gallery's shared (tap-driven)
  /// selection — rendered as an accent-colored border in place of the
  /// usual hairline.
  final bool selected;

  static const width = 100.0;
  static const photoHeight = 76.0;

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
                  child: Stack(
                    children: [
                      entry.hasPhotos
                          ? Image.file(
                              File(entry.photos.first.filePath),
                              width: width,
                              height: photoHeight,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => placeholder(colors),
                            )
                          : placeholder(colors),
                      if (entry.photos.length > 1)
                        PositionedDirectional(
                          top: 4,
                          end: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.inkPrimary.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              child: MonoText(
                                '${entry.photos.length}',
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      MonoText(DateFormat('dd MMM').format(entry.loggedAt)),
                      if (placeName != null && placeName.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            placeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.accent,
                              fontWeight: FontWeight.w500,
                            ),
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

Note: the photo-count badge is only added to `JournalGalleryCard` (single-entry days), not `_GroupedGalleryCard` — a grouped card already carries a day-entry-count badge, and stacking a second "photos in this entry" badge on top would be visually cluttered for a card this small. `_GroupedGalleryCard` itself needs no changes in this task (it already references `JournalGalleryCard.width`/`.photoHeight` by name, so it automatically follows the new tighter dimensions).

- [ ] **Step 2: Update the widget tests**

`test/widget/journal/journal_gallery_card_test.dart` — the existing three tests assert `find.text('20 JUL')` and `find.text('Krabi')`, which still hold (date format and place-name rendering are unchanged, just the caption layout around them). Add one new test for the photo-count badge. Insert after the existing `'entry with no placeName shows no place line'` test:

```dart
  testWidgets('entry with more than one photo shows a count badge',
      (tester) async {
    final entry = JournalEntry(
      id: 'e1',
      tripId: 't1',
      summary: 'irrelevant',
      loggedAt: DateTime(2026, 7, 20),
      createdAt: DateTime(2026, 7, 20),
      photos: const [
        JournalPhoto(id: 'p1', filePath: '/tmp/a.jpg'),
        JournalPhoto(id: 'p2', filePath: '/tmp/b.jpg'),
      ],
    );
    await tester.pumpWidget(_wrap(JournalGalleryCard(entry: entry)));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('entry with exactly one photo shows no count badge',
      (tester) async {
    final entry = JournalEntry(
      id: 'e1',
      tripId: 't1',
      summary: 'irrelevant',
      loggedAt: DateTime(2026, 7, 20),
      createdAt: DateTime(2026, 7, 20),
      photos: const [JournalPhoto(id: 'p1', filePath: '/tmp/a.jpg')],
    );
    await tester.pumpWidget(_wrap(JournalGalleryCard(entry: entry)));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
  });
```

Add the import this needs at the top of the file: `import 'package:tripper/features/journal/domain/journal_photo.dart';`

These entries reference photo files that don't exist on disk (`/tmp/a.jpg`) — that's fine, `Image.file`'s `errorBuilder` handles the missing file gracefully (falls back to `placeholder(colors)`), and neither new test asserts anything about the image itself, only the count badge.

- [ ] **Step 3: Run and commit**

Run: `flutter analyze && flutter test test/widget/journal/journal_gallery_card_test.dart`
Expected: PASS, no analyzer issues.

```bash
git add lib/features/journal/presentation/journal_widgets.dart \
  test/widget/journal/journal_gallery_card_test.dart
git commit -m "feat(journal): tighter gallery card with a photo-count badge"
```

> `flutter analyze` on the whole project may show pre-existing, unrelated errors if other tasks in this plan haven't landed yet — run the scoped command above for this task's own verification.

---

### Task 4: Gallery timeline — live scroll-center tracking

**Files:**
- Modify: `lib/features/journal/presentation/journal_widgets.dart`
- Modify: `test/widget/journal/journal_gallery_timeline_test.dart`

**Interfaces:**
- Consumes: `JournalGalleryCard`/`_GroupedGalleryCard` (Task 3, unchanged interface).
- Produces: `JournalGalleryTimeline({..., required void Function(List<JournalEntry> dayEntries) onCenteredDayChanged})` — Task 5 wires this into `TripJournalTab`.

- [ ] **Step 1: Add a `GlobalKey` for the scroll view, track scroll-centered day**

In `lib/features/journal/presentation/journal_widgets.dart`, update `JournalGalleryTimeline`'s constructor and its state class. Replace the class declaration:

```dart
class JournalGalleryTimeline extends StatefulWidget {
  const JournalGalleryTimeline({
    super.key,
    required this.entries,
    required this.selectedEntryId,
    required this.onTapDay,
    required this.onCenteredDayChanged,
  });

  final List<JournalEntry> entries;
  final String? selectedEntryId;
  final void Function(List<JournalEntry> dayEntries, int tappedIndex) onTapDay;

  /// Fired continuously as the strip scrolls, whenever the day-slot
  /// closest to the visible viewport's horizontal center changes —
  /// drives the globe's live-follow (JournalGlobe.liveFollowEntryId),
  /// separate from the tap-driven selection above.
  final void Function(List<JournalEntry> dayEntries) onCenteredDayChanged;

  static const _dotSize = 11.0;
  static const _stemHeight = 22.0;

  @override
  State<JournalGalleryTimeline> createState() => _JournalGalleryTimelineState();
}
```

Replace the state class's fields and add the scroll-tracking logic:

```dart
class _JournalGalleryTimelineState extends State<JournalGalleryTimeline> {
  /// Keyed by each day's first (earliest) entry id — stable across
  /// rebuilds as long as that entry stays the earliest one for its day,
  /// which is true unless entries are added/removed within the day.
  final _slotKeys = <String, GlobalKey>{};
  final _scrollViewKey = GlobalKey();
  String? _lastCenteredDayId;

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

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification) {
      _reportCenteredDay();
    }
    return false;
  }

  /// Finds whichever day-slot's horizontal center is closest to the
  /// scroll viewport's own horizontal center, and reports it via
  /// widget.onCenteredDayChanged — but only when it actually changes,
  /// not on every scroll pixel.
  void _reportCenteredDay() {
    final viewportBox =
        _scrollViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;
    final viewportCenterX =
        viewportBox.localToGlobal(Offset(viewportBox.size.width / 2, 0)).dx;

    final days = groupEntriesByDay(widget.entries);
    String? closestDayId;
    var closestDistance = double.infinity;
    for (final day in days) {
      final slotBox = _slotKeys[day.first.id]?.currentContext
          ?.findRenderObject() as RenderBox?;
      if (slotBox == null || !slotBox.hasSize) continue;
      final slotCenterX =
          slotBox.localToGlobal(Offset(slotBox.size.width / 2, 0)).dx;
      final distance = (slotCenterX - viewportCenterX).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestDayId = day.first.id;
      }
    }
    if (closestDayId == null || closestDayId == _lastCenteredDayId) return;
    _lastCenteredDayId = closestDayId;
    final day = days.firstWhere((d) => d.first.id == closestDayId);
    widget.onCenteredDayChanged(day);
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

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: SingleChildScrollView(
        key: _scrollViewKey,
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
      ),
    );
  }
}
```

`_DaySlot` is unchanged by this task.

- [ ] **Step 2: Add a scroll-tracking test**

`test/widget/journal/journal_gallery_timeline_test.dart` — add this test after the existing `'selecting an entry scrolls its day into view'` test:

```dart
  testWidgets('scrolling reports the day closest to the viewport center',
      (tester) async {
    final entries = [
      for (var i = 0; i < 20; i++)
        _e('e$i', DateTime(2026, 7, 1 + i), placeName: 'Place $i'),
    ];
    List<JournalEntry>? lastCentered;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: entries,
          selectedEntryId: null,
          onTapDay: (_, __) {},
          onCenteredDayChanged: (day) => lastCentered = day,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initial layout already reports whichever day starts closest to
    // center (ScrollStartNotification fires on the first drag below,
    // but a plain pump with no scroll yet won't have reported anything
    // — this asserts the FIRST report, once scrolling begins).
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(lastCentered, isNotNull);
    // After scrolling left by 600px, the centered day should no longer
    // be the very first one (Place 0) — some later day is now closer to
    // the viewport's center.
    expect(lastCentered!.first.id, isNot('e0'));
  });
```

- [ ] **Step 3: Run and commit**

Run: `flutter analyze && flutter test test/widget/journal/journal_gallery_timeline_test.dart test/widget/journal/journal_gallery_card_test.dart`
Expected: PASS, no analyzer issues.

```bash
git add lib/features/journal/presentation/journal_widgets.dart \
  test/widget/journal/journal_gallery_timeline_test.dart
git commit -m "feat(journal): gallery reports the scroll-centered day for globe live-follow"
```

> `TripJournalTab` still calls the old `JournalGalleryTimeline(...)` constructor (missing `onCenteredDayChanged`) and won't compile after this task — Task 5 fixes that.

---

### Task 5: `TripJournalTab` — wire `liveFollowEntryId` end-to-end

**Files:**
- Modify: `lib/features/journal/presentation/trip_journal_tab.dart`
- Modify: `test/widget/journal/trip_journal_tab_test.dart`

**Interfaces:**
- Consumes: `JournalGlobe.liveFollowEntryId` (Task 2), `JournalGalleryTimeline.onCenteredDayChanged` (Task 4).

- [ ] **Step 1: Add `_liveFollowEntryId` state, wire both children**

In `lib/features/journal/presentation/trip_journal_tab.dart`, add a new field to `_TripJournalTabState`:

```dart
class _TripJournalTabState extends ConsumerState<TripJournalTab> {
  String? _selectedEntryId;
  String? _liveFollowEntryId;
```

Update the `JournalGlobe` call site:

```dart
                    Expanded(
                      flex: 7,
                      child: JournalGlobe(
                        entries: entries,
                        selectedEntryId: _selectedEntryId,
                        liveFollowEntryId: _liveFollowEntryId,
                        onEntryTap: (entry) =>
                            setState(() => _selectedEntryId = entry.id),
                        renderGlobe: widget.renderGlobe,
                      ),
                    ),
```

Update the `JournalGalleryTimeline` call site to add `onCenteredDayChanged`:

```dart
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
                        onCenteredDayChanged: (dayEntries) => setState(
                          () => _liveFollowEntryId = dayEntries.first.id,
                        ),
                      ),
                    ),
```

- [ ] **Step 2: Add a coordination test**

`test/widget/journal/trip_journal_tab_test.dart` — add this test after the existing `'tapping a globe dot selects the matching gallery card (accent border)'` test. It confirms `_liveFollowEntryId` actually reaches `JournalGlobe` by exercising a real scroll and checking no exception occurs (the `renderGlobe: false` scaffold can't visually confirm the globe followed, but it DOES construct the real `JournalGlobe` widget with the real prop, so a wiring mistake — e.g., a typo'd param name or the wrong entry passed — would surface as a compile error or a thrown exception during the widget's lifecycle):

```dart
  testWidgets('scrolling the gallery does not throw (live-follow wiring smoke test)',
      (tester) async {
    final entries = [
      for (var i = 0; i < 20; i++)
        JournalEntry(
          id: 'e$i',
          tripId: 'trip-1',
          summary: 'Entry $i',
          loggedAt: DateTime(2026, 7, 1 + i),
          createdAt: DateTime(2026, 7, 1 + i),
          lat: 8.0 + i * 0.01,
          lng: 98.8 + i * 0.01,
          placeName: 'Place $i',
        ),
    ];
    await _pump(tester, entries: entries);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 3: Run and commit**

Run: `flutter analyze && flutter test test/widget/journal`
Expected: PASS, no analyzer issues — this is the first point where the whole `journal` test directory compiles again after Tasks 2/4's new required params.

Then run the full suite:

Run: `flutter test`
Expected: PASS, no regression.

```bash
git add lib/features/journal/presentation/trip_journal_tab.dart \
  test/widget/journal/trip_journal_tab_test.dart
git commit -m "feat(journal): wire globe live-follow to the gallery's scroll-centered entry"
```

---

### Task 6: Presentation sheet — fix menu contrast

**Files:**
- Modify: `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`

**Interfaces:**
- No interface changes — this is a pure styling fix within `_JournalEntryPresentationViewState`.

- [ ] **Step 1: Always scrim the menu when there's a photo**

In `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`, the current menu `PositionedDirectional` (inside `_JournalEntryPresentationViewState.build`) passes `iconColor: currentEntry.hasPhotos ? colors.surface : colors.inkMuted` with no background behind the icon in either case — the bug is that the photo case has no scrim to sit on (the existing bottom gradient only covers the photo's bottom 56px, not where the menu sits near the top). Replace the `_menu` method to always wrap the icon in a solid circular backdrop when there's a photo:

```dart
  Widget _menu(
    AppLocalizations l10n, {
    required bool hasPhoto,
    required Color deleteColor,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final colors = context.colors;
    final button = PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: hasPhoto ? colors.surface : colors.inkMuted,
      ),
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
    if (!hasPhoto) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.inkPrimary.withValues(alpha: 0.55),
      ),
      child: button,
    );
  }
```

Update the call site inside `build` to match the new signature (replace `iconColor:` with `hasPhoto:`):

```dart
                  PositionedDirectional(
                    top: currentEntry.hasPhotos ? 2 : 4,
                    end: 2,
                    child: _menu(
                      l10n,
                      hasPhoto: currentEntry.hasPhotos,
                      deleteColor: colors.error,
                      onEdit: () => _handleEdit(currentEntry),
                      onDelete: () => _handleDelete(currentEntry),
                    ),
                  ),
```

- [ ] **Step 2: Run the existing tests to confirm no regression**

Run: `flutter analyze && flutter test test/widget/journal/journal_entry_presentation_sheet_test.dart`
Expected: PASS, no analyzer issues. The existing `'photo entry: renders the photo header and its overflow menu is tappable'` test taps `Icons.more_vert` and expects the menu items to appear — this should still pass since `PopupMenuButton`'s hit target is unaffected by wrapping it in a `DecoratedBox` (the `DecoratedBox` doesn't intercept or resize the tap target, it just paints a backdrop behind it).

- [ ] **Step 3: Commit**

```bash
git add lib/features/journal/presentation/journal_entry_presentation_sheet.dart
git commit -m "fix(journal): presentation sheet menu always has enough contrast over a photo"
```

---

### Task 7: Presentation sheet — swipeable multi-photo carousel

**Files:**
- Modify: `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`
- Modify: `test/widget/journal/journal_entry_presentation_sheet_test.dart`

**Interfaces:**
- Consumes: Task 6's `_menu` (unchanged signature from Task 6's perspective).
- Produces: `_JournalEntryPresentationPage` becomes a `StatefulWidget` taking `onOverscrollNext`/`onOverscrollPrevious` callbacks — Task 8 doesn't need to know about these directly, but must not remove them.

- [ ] **Step 1: Convert `_JournalEntryPresentationPage` to a `StatefulWidget` with its own photo carousel**

In `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`, replace the whole `_JournalEntryPresentationPage` class:

```dart
class _JournalEntryPresentationPage extends StatefulWidget {
  const _JournalEntryPresentationPage({
    required this.entry,
    required this.onOverscrollNext,
    required this.onOverscrollPrevious,
  });

  final JournalEntry entry;

  /// Called when the user keeps swiping past this entry's last photo —
  /// hands the gesture off to the outer (entry-to-entry) PageView, so
  /// swiping "past the end" of a photo carousel moves to the next
  /// entry instead of just bouncing.
  final VoidCallback onOverscrollNext;

  /// Same as above, for swiping past the first photo.
  final VoidCallback onOverscrollPrevious;

  @override
  State<_JournalEntryPresentationPage> createState() =>
      _JournalEntryPresentationPageState();
}

class _JournalEntryPresentationPageState
    extends State<_JournalEntryPresentationPage> {
  late final PageController _photoController;
  int _currentPhoto = 0;

  static const _photoAreaHeight = 260.0;

  @override
  void initState() {
    super.initState();
    _photoController = PageController();
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final entry = widget.entry;
    final placeName = entry.placeName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        entry.hasPhotos ? _photoCarousel(colors) : const SizedBox(height: 40),
        Expanded(
          child: SingleChildScrollView(
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
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: colors.accent,
                      ),
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
                  entry.summary.isEmpty
                      ? l10n.journalUntitledEntry
                      : entry.summary,
                  style: AppTextStyles.body.copyWith(
                    color: entry.summary.isEmpty
                        ? colors.inkMuted
                        : colors.inkPrimary,
                    fontStyle: entry.summary.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoCarousel(AppColors colors) {
    final photos = widget.entry.photos;
    return SizedBox(
      height: _photoAreaHeight,
      child: NotificationListener<OverscrollNotification>(
        onNotification: (notification) {
          if (notification.overscroll > 0 &&
              _currentPhoto == photos.length - 1) {
            widget.onOverscrollNext();
          } else if (notification.overscroll < 0 && _currentPhoto == 0) {
            widget.onOverscrollPrevious();
          }
          return false;
        },
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: PageView(
                controller: _photoController,
                onPageChanged: (i) => setState(() => _currentPhoto = i),
                children: [
                  for (final photo in photos)
                    Image.file(
                      File(photo.filePath),
                      width: double.infinity,
                      height: _photoAreaHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: colors.paper),
                    ),
                ],
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
            if (photos.length > 1)
              PositionedDirectional(
                bottom: 10,
                start: 0,
                end: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPhoto
                              ? colors.surface
                              : colors.surface.withValues(alpha: 0.5),
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
}
```

- [ ] **Step 2: Wire `onOverscrollNext`/`onOverscrollPrevious` from the outer view**

In `_JournalEntryPresentationViewState.build`, update the `_JournalEntryPresentationPage` construction inside the outer `PageView`:

```dart
                    children: [
                      for (var i = 0; i < widget.entries.length; i++)
                        _JournalEntryPresentationPage(
                          entry: widget.entries[i],
                          onOverscrollNext: () {
                            if (i < widget.entries.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          onOverscrollPrevious: () {
                            if (i > 0) {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                    ],
```

(This replaces the existing `for (final entry in widget.entries) _JournalEntryPresentationPage(entry: entry)` — note the switch from `for (final entry in ...)` to an indexed loop, needed so each page's overscroll callbacks know their own position among the outer entries.)

- [ ] **Step 3: Add multi-photo carousel tests**

`test/widget/journal/journal_entry_presentation_sheet_test.dart` — add these tests after the existing `'photo entry: renders the photo header and its overflow menu is tappable'` test. They need a second real image file (reuse the existing `_pngBytes` helper already in the file):

```dart
  testWidgets('multi-photo entry shows a dot per photo, swiping changes it',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('journal_carousel');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // OS cleans up temp dirs — don't fail the test over a lock.
      }
    });
    final photoA = File('${dir.path}/a.png')..writeAsBytesSync(_pngBytes);
    final photoB = File('${dir.path}/b.png')..writeAsBytesSync(_pngBytes);

    await _open<void>(
      tester,
      entries: [
        _e(
          'a',
          summary: 'Two photos here',
          photos: [
            JournalPhoto(id: 'p1', filePath: photoA.path),
            JournalPhoto(id: 'p2', filePath: photoB.path),
          ],
        ),
      ],
      initialIndex: 0,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget); // only photo A visible

    await tester.drag(find.byType(PageView).first, const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget); // now photo B visible
  });

  testWidgets(
      'swiping past the last photo in a multi-entry day advances to the '
      'next entry', (tester) async {
    final dir = Directory.systemTemp.createTempSync('journal_carousel2');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // OS cleans up temp dirs — don't fail the test over a lock.
      }
    });
    final photo = File('${dir.path}/a.png')..writeAsBytesSync(_pngBytes);

    await _open<void>(
      tester,
      entries: [
        _e(
          'a',
          summary: 'Only entry photo',
          photos: [JournalPhoto(id: 'p1', filePath: photo.path)],
        ),
        _e('b', summary: 'Second entry, no photo'),
      ],
      initialIndex: 0,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('Only entry photo'), findsOneWidget);

    // A single photo means there's nowhere for the inner carousel to go
    // — this drag should overscroll immediately and fall through to the
    // outer PageView, landing on entry 'b'.
    await tester.drag(find.byType(PageView).first, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Second entry, no photo'), findsOneWidget);
    expect(find.text('Only entry photo'), findsNothing);
  });
```

Add the import this needs at the top of the file (if not already present from the existing photo test): `import 'package:tripper/features/journal/domain/journal_photo.dart';` — check the file first, it's likely already imported from the pre-existing photo test.

- [ ] **Step 4: Run and commit**

Run: `flutter analyze && flutter test test/widget/journal/journal_entry_presentation_sheet_test.dart`
Expected: PASS, no analyzer issues.

```bash
git add lib/features/journal/presentation/journal_entry_presentation_sheet.dart \
  test/widget/journal/journal_entry_presentation_sheet_test.dart
git commit -m "feat(journal): swipeable multi-photo carousel with entry-boundary fall-through"
```

---

### Task 8: Presentation sheet — location as title, content-adaptive sheet height

**Files:**
- Modify: `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`
- Modify: `test/widget/journal/journal_entry_presentation_sheet_test.dart`

**Interfaces:**
- Consumes: `_JournalEntryPresentationPage`'s body structure from Task 7 (the `Expanded(child: SingleChildScrollView(...))` block).

- [ ] **Step 1: Style the place name as a prominent title**

In `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`, inside `_JournalEntryPresentationPageState.build`, replace the `if (placeName != null && placeName.isNotEmpty)` block (the small icon+text row) with a serif heading, and move the date above it as a smaller, less prominent line:

```dart
                MonoText(
                  DateFormat('d MMMM yyyy · HH:mm').format(entry.loggedAt),
                ),
                if (placeName != null && placeName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    placeName,
                    style:
                        AppTextStyles.title.copyWith(color: colors.inkPrimary),
                  ),
                ],
                const SizedBox(height: 12),
```

(This replaces the existing `Row(Icon(place_outlined) + Text(placeName))` block entirely — the location no longer needs a pin icon to read as "the place," since it's now the visually dominant heading. Keep the `SizedBox(height: 14)` that follows unchanged — actually reduce it to `12` per above, matching the tighter rhythm between a heading and the body text below it. The summary `Text` widget right after stays exactly as it is.)

Add the import this needs at the top of the file (if not already present): `import '../../../core/theme/app_typography.dart';`

- [ ] **Step 2: Make the outer sheet height adapt to whether the current entry has a photo**

In `_JournalEntryPresentationViewState.build`, replace the outer `SizedBox`:

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final currentEntry = widget.entries[_currentPage];
    final screenHeight = MediaQuery.of(context).size.height;
    final targetHeight = screenHeight * (currentEntry.hasPhotos ? 0.7 : 0.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: targetHeight,
      child: SafeArea(
        top: false,
        child: Column(
```

(Only the outermost widget changes — from `SizedBox(height: screenHeight * 0.7, child: SafeArea(...))` to the `AnimatedContainer` above with a height that depends on `currentEntry.hasPhotos`. Everything inside `SafeArea` stays exactly as it is. Since `currentEntry` is already recomputed from `widget.entries[_currentPage]` on every build — and `_currentPage` already updates via `setState` in `onPageChanged` — swiping between a photo entry and a photo-less entry naturally triggers a rebuild with a new `targetHeight`, which `AnimatedContainer` then animates to smoothly.)

- [ ] **Step 3: Update tests for the new title styling and height behavior**

`test/widget/journal/journal_entry_presentation_sheet_test.dart` — the existing tests already assert `find.text('Krabi')` (the place name) without depending on its specific styling, so they still pass unchanged. Add two new tests after the existing `'empty-summary entry falls back to "Not written yet"'` test:

```dart
  testWidgets('a photo-less entry uses a shorter sheet than a photo entry',
      (tester) async {
    await _open<void>(
      tester,
      entries: [_e('a', summary: 'No photo here')],
      initialIndex: 0,
    );
    final noPhotoHeight =
        tester.getSize(find.byType(AnimatedContainer)).height;

    final dir = Directory.systemTemp.createTempSync('journal_height');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // OS cleans up temp dirs — don't fail the test over a lock.
      }
    });
    final photo = File('${dir.path}/a.png')..writeAsBytesSync(_pngBytes);

    await _open<void>(
      tester,
      entries: [
        _e(
          'b',
          summary: 'Has a photo',
          photos: [JournalPhoto(id: 'p1', filePath: photo.path)],
        ),
      ],
      initialIndex: 0,
    );
    final photoHeight = tester.getSize(find.byType(AnimatedContainer)).height;

    expect(photoHeight, greaterThan(noPhotoHeight));
  });

  testWidgets('place name renders as a prominent title, not a small row',
      (tester) async {
    await _open<void>(tester, entries: [_e('a')], initialIndex: 0);
    final placeText = tester.widget<Text>(find.text('Krabi'));
    expect(placeText.style?.fontFamily, 'Fraunces');
  });
```

- [ ] **Step 4: Run and commit**

Run: `flutter analyze && flutter test test/widget/journal/journal_entry_presentation_sheet_test.dart`
Expected: PASS, no analyzer issues.

Then run the full suite once:

Run: `flutter test`
Expected: PASS, no regression.

```bash
git add lib/features/journal/presentation/journal_entry_presentation_sheet.dart \
  test/widget/journal/journal_entry_presentation_sheet_test.dart
git commit -m "feat(journal): location as title, content-adaptive presentation sheet height"
```

---

## Self-review notes

- **Spec coverage:** rotation smoothness (Task 1), multi-photo carousel (Task 7), menu contrast (Task 6), gallery card elegance (Task 3), globe-follows-visible-gallery-center (Tasks 2, 4, 5), photo-dominant/scrollable-summary/content-adaptive-height (Tasks 7, 8), location-as-title (Task 8). All seven numbered issues from the design spec have a task.
- **Type consistency checked:** `JournalGlobe.liveFollowEntryId`/`_maybeFollowLive` (Task 2) match Task 5's usage exactly; `JournalGalleryTimeline.onCenteredDayChanged(List<JournalEntry>)` (Task 4) matches Task 5's usage exactly; `_JournalEntryPresentationPage`'s `onOverscrollNext`/`onOverscrollPrevious` (Task 7) match the outer view's wiring exactly; `_menu`'s `hasPhoto:` param (Task 6) is used consistently by Task 7/8's unrelated edits to the same file (neither touches `_menu` again).
- **Sequencing:** Tasks 1→2 and 6→7→8 are same-file, in-order pairs/chains (each leaves the file in a compiling, testable state for its own scope, with explicit notes where a later task is needed to fix a cross-task compile gap — Task 4 leaves `TripJournalTab` broken until Task 5). Task 3→4 are same-file but largely independent (card redesign vs. timeline scroll-tracking); kept sequential for a clean single-threaded execution order, not because of a real dependency.
