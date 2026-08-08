# Journal Globe/Gallery Polish, Round 2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the globe's stale-animation bug (root cause of both "not smooth" and "rendering glitches"), raise the zoom ceiling, give dots visual character via layered native points, redesign the gallery card as photo-dominant with an overlaid caption, add a full-screen pinch-zoom photo viewer, and make the entry summary optional.

**Architecture:** Five independent-ish changes to the existing journal feature — three touch `journal_globe.dart` conceptually but split into two tasks (mechanical bug fixes vs. visual/GPU-judgment dot styling), one redesigns both gallery card widgets in `journal_widgets.dart`, one adds a new full-screen viewer file plus a small wiring change in the presentation sheet, and one removes a validation check plus its now-dead ARB string.

**Tech Stack:** Flutter/Dart, `flutter_earth_globe` (already a dependency, its internal `rotating_globe.dart` behavior is the root cause fixed in Task 1), `photo_view` (already a transitive dependency, promoted to direct in Task 4).

## Global Constraints

- No `Color(0xFF...)`, and no raw `Colors.black`/`Colors.white`/other `Colors.*` constants, outside `lib/core/theme/app_colors.dart` — use `context.colors`/`colors.*` throughout, including the full-screen photo viewer's background.
- Two accents total (teal `accent` for actions/places, rust `warning` reserved for warnings only, never place/dot states) — the halo dots and gallery card caption use only `accent` and the existing neutral tokens (`inkPrimary`, `surface`, `paper`, `inkMuted`), no new hues.
- Serif (`AppTextStyles.title`, Fraunces) is this app's convention for names/titles — reused (scaled down) for the gallery card's place-name overlay.
- GPU-rendered globe behavior (dot rendering, rotation/animation timing) is manual-verification-only — no widget test can construct a real `FlutterEarthGlobeController`. Per the prior round's already-litigated ruling (ledger, Task 2: "structurally untestable, not just hard to test" — `didUpdateWidget`'s `if (!widget.renderGlobe) return;` skips every animation-related branch in the only mode widget tests can construct), do not write a vacuous test to cover this — the existing `journal_globe_test.dart` suite passing unmodified is the applicable bar.
- Flutter is installed and working in this environment (`C:\Development\flutter`) — every "Run" step in this plan is something the implementer/reviewer actually executes here, not deferred to a human.
- This app targets Android only (per CLAUDE.md).
- No new network calls anywhere in this plan — consistent with CLAUDE.md's offline-first rule.

---

### Task 1: Globe — fix the stale-animation-controller bug, raise the zoom ceiling

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`

**Interfaces:**
- Produces: `_maybeFocusLatest`'s parameter is renamed from `{bool animate = true}` to `{bool instant = false}` — this is a private method with exactly two call sites, both inside this same file, both updated in this task.

- [ ] **Step 1: Route every "instant" focus call through `animate: true, duration: Duration.zero`**

The package's `focusOnCoordinates(animate: false, ...)` only assigns rotation once and never stops a previous `animate: true` call's still-running `AnimationController` — that stale controller then overwrites the "instant" update on its next frame. `animate: true` is the only path that disposes and replaces any in-flight controller, so every call in this file — including the ones that want to look instant — must use it, with `Duration.zero` standing in for "no animation."

In `lib/features/journal/presentation/journal_globe.dart`, replace `_maybeFollowLive`:

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
    // animate: true with a zero duration — not animate: false. The
    // package's focusOnCoordinates only disposes/replaces an in-flight
    // animation controller on the animate: true path; animate: false
    // just assigns rotation once and leaves a still-running prior
    // animation free to overwrite it on the next frame (confirmed by
    // reading rotating_globe.dart directly). Using animate: true here,
    // even for this "instant" snap, is what actually guarantees no
    // stale animation survives to fight this update.
    controller.focusOnCoordinates(
      GlobeCoordinates(target.lat!, target.lng!),
      animate: true,
      duration: Duration.zero,
    );
  }
```

Replace `_maybeFocusLatest`:

```dart
  /// Opens on the most recent entry rather than a fixed default, and
  /// re-focuses only when the latest entry actually changes — not on
  /// every unrelated edit to some other entry. [instant] skips the
  /// animation (used for the very first focus, on initial load); the
  /// default animates over 600ms (used when a new entry becomes the
  /// latest during an active session). Both branches still call
  /// focusOnCoordinates with animate: true — see the comment in
  /// _maybeFollowLive for why animate: false is never used in this file.
  void _maybeFocusLatest({bool instant = false}) {
    final controller = _controller;
    if (controller == null || !controller.isReady) return;
    final latest = latestLocatedEntry(widget.entries);
    if (latest == null || latest.id == _focusedEntryId) return;
    _focusedEntryId = latest.id;
    controller.focusOnCoordinates(
      GlobeCoordinates(latest.lat!, latest.lng!),
      animate: true,
      duration: instant ? Duration.zero : const Duration(milliseconds: 600),
    );
  }
```

- [ ] **Step 2: Update `_maybeFocusLatest`'s one renamed-parameter call site**

In `_buildController()`, find:

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

Change `_maybeFocusLatest(animate: false);` to `_maybeFocusLatest(instant: true);`. The other call site, in `didUpdateWidget` (`_maybeFocusLatest();` with no arguments), needs no change — the new default (`instant: false`) preserves the same 600ms-animated behavior the old default (`animate: true`) had.

- [ ] **Step 3: Raise the zoom ceiling**

In `_buildController()`, find:

```dart
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
```

Add a `maxZoom` argument:

```dart
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
      // Default is 2.5 (~5.7x, radius = baseRadius * 2^zoom) — too shallow
      // to make individual streets/landmarks near a pin legible. 5 is
      // ~32x.
      maxZoom: 5,
    );
```

- [ ] **Step 4: Run the existing test suite and confirm no regression**

Run: `flutter analyze && flutter test test/widget/journal/journal_globe_test.dart`
Expected: PASS, no analyzer issues. This file's tests exercise the `renderGlobe: false` scaffolding, which none of this task's changes touch — they should pass unmodified.

- [ ] **Step 5: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart
git commit -m "fix(journal): stop stale globe animations from fighting focus updates, raise zoom ceiling"
```

---

### Task 2: Globe — layered native halo dots for visual character

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`

**Interfaces:**
- Consumes: nothing from Task 1 beyond the same file compiling.
- Produces: two new native `Point`s per located entry (`entry.id` unchanged core dot, new `'${entry.id}-halo'` halo dot) — Task-1/other-file consumers are unaffected, this is purely internal to `_addPoints`/`_syncPoints`.

- [ ] **Step 1: Add a halo point behind both dot types**

`PointStyle` (the native, GPU-rendered dot style) only supports `size`/`color`/`altitude`/`transitionDuration`/`merge` — no border or glow. Visual character comes from layering a second, larger, lower-alpha native point at the same coordinates underneath the existing dot — still fully GPU-native, so it costs nothing extra during rotation (unlike switching to a widget-rendered dot, which would reintroduce the smoothness regression a previous round already fixed).

In `lib/features/journal/presentation/journal_globe.dart`, replace the top-level constants:

```dart
const _plainDotSize = 2.5;
const _photoDotDiameter = 26.0;
```

with:

```dart
const _plainDotSize = 2.5;
const _haloDotSize = 6.0;
const _photoDotDiameter = 26.0;
const _photoHaloDotSize = 8.0;
// Monochrome teal — CLAUDE.md's two-accents rule (teal for actions/
// places, rust reserved for warnings only) means the halo has to be a
// low-alpha version of the same accent, not a new hue.
const _haloAlpha = 0.28;
```

In `_addPoints`, find:

```dart
  void _addPoints(FlutterEarthGlobeController controller) {
    final colors = context.colors;
    for (final entry in widget.entries) {
      if (!entry.hasLocation) continue;
      final onTap =
          widget.onEntryTap == null ? null : () => widget.onEntryTap!(entry);
      if (entry.hasPhotos) {
```

Insert a halo point before the `if (entry.hasPhotos)` branch, so it's added — and therefore, if the package draws points in insertion order, painted — before the core/photo point it sits behind:

```dart
  void _addPoints(FlutterEarthGlobeController controller) {
    final colors = context.colors;
    for (final entry in widget.entries) {
      if (!entry.hasLocation) continue;
      final onTap =
          widget.onEntryTap == null ? null : () => widget.onEntryTap!(entry);
      // Halo: a larger, low-alpha native point at the same coordinates as
      // the dot below, added first so it paints (and therefore sits)
      // behind it — this needs on-device confirmation like every other
      // dot-visual change in this file; the package's actual draw order
      // isn't guaranteed by its public API.
      controller.addPoint(
        Point(
          id: '${entry.id}-halo',
          coordinates: GlobeCoordinates(entry.lat!, entry.lng!),
          style: PointStyle(
            size: entry.hasPhotos ? _photoHaloDotSize : _haloDotSize,
            color: colors.accent.withValues(alpha: _haloAlpha),
          ),
        ),
      );
      if (entry.hasPhotos) {
```

Leave the rest of the `if (entry.hasPhotos) { ... } else { ... }` block (the existing photo-dot and plain-dot `controller.addPoint` calls) exactly as it is.

- [ ] **Step 2: Remove the halo point alongside its core point**

In `_syncPoints`, find:

```dart
    for (final entry in previous) {
      if (entry.hasLocation) controller.removePoint(entry.id);
    }
```

Replace with:

```dart
    for (final entry in previous) {
      if (entry.hasLocation) {
        controller.removePoint(entry.id);
        controller.removePoint('${entry.id}-halo');
      }
    }
```

- [ ] **Step 3: Run the existing test suite and confirm no regression**

Run: `flutter analyze && flutter test test/widget/journal/journal_globe_test.dart`
Expected: PASS, no analyzer issues. Same reasoning as Task 1 Step 4 — these changes are inside `_addPoints`/`_syncPoints`, which the `renderGlobe: false` test scaffolding never calls.

- [ ] **Step 4: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart
git commit -m "feat(journal): layered halo dots for visual character on the globe"
```

---

### Task 3: Gallery card — photo-dominant, caption overlaid on the photo

**Files:**
- Modify: `lib/features/journal/presentation/journal_widgets.dart`

**Interfaces:**
- Produces: `JournalGalleryCard.width` changes from `100.0` to `150.0`, `JournalGalleryCard.photoHeight` changes from `76.0` to `130.0` — both are `static const`, read by `_GroupedGalleryCard` and `_DaySlot` in the same file, both updated in this task. No other file references these constants.

- [ ] **Step 1: Add the typography import**

At the top of `lib/features/journal/presentation/journal_widgets.dart`, add:

```dart
import '../../../core/theme/app_typography.dart';
```

alongside the existing `core/theme` imports.

- [ ] **Step 2: Redesign `JournalGalleryCard` — bigger, caption overlaid on the photo**

Replace the entire `JournalGalleryCard` class body from `static const width = 100.0;` through the end of `build()` (stop before `static Widget placeholder`) with:

```dart
  static const width = 150.0;
  static const photoHeight = 130.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final placeName = entry.placeName;
    final hasPhoto = entry.hasPhotos;

    return SizedBox(
      width: width,
      child: PaperCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderColor: selected ? colors.accent : null,
        // The card has a natural (photo) size. FittedBox only ever
        // shrinks (never grows) to fit whatever the gallery strip
        // actually gives it — a plain SizedBox would instead throw a
        // render overflow during a transient squeeze (e.g. a keyboard
        // animating over the tab shrinks the strip below the card's
        // natural height).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: width,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppShape.radius - 1),
              child: SizedBox(
                width: width,
                height: photoHeight,
                child: Stack(
                  children: [
                    hasPhoto
                        ? Image.file(
                            File(entry.photos.first.filePath),
                            width: width,
                            height: photoHeight,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => placeholder(colors),
                          )
                        : placeholder(colors),
                    // Bottom gradient scrim so the overlaid caption stays
                    // legible over a bright photo — no scrim on the
                    // placeholder case below, since there's nothing to
                    // darken against.
                    if (hasPhoto)
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        bottom: 0,
                        child: Container(
                          height: photoHeight * 0.6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colors.inkPrimary.withValues(alpha: 0),
                                colors.inkPrimary.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (entry.photos.length > 1)
                      PositionedDirectional(
                        top: 6,
                        end: 6,
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
                    PositionedDirectional(
                      start: 8,
                      end: 8,
                      bottom: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MonoText(
                            DateFormat('dd MMM').format(entry.loggedAt),
                            color: hasPhoto
                                ? colors.surface.withValues(alpha: 0.75)
                                : colors.inkMuted,
                          ),
                          if (placeName != null && placeName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              placeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.title.copyWith(
                                fontSize: 17,
                                color: hasPhoto
                                    ? colors.surface
                                    : colors.inkPrimary,
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
        ),
      ),
    );
  }
```

Leave `static Widget placeholder(AppColors colors) => ...` unchanged — it already references `width`/`photoHeight`, which now resolve to the new values automatically.

- [ ] **Step 3: Mirror the same caption approach in `_GroupedGalleryCard`**

Find the `Padding(padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm, vertical: 6), child: Row(...))` caption block near the end of `_GroupedGalleryCard.build()` — the comment above it reads "Same one-line Row caption as JournalGalleryCard...". Replace `_GroupedGalleryCard.build()` in its entirety with:

```dart
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = day.first;
    final photoEntry = day.firstWhere((e) => e.hasPhotos, orElse: () => first);
    final placeName = first.placeName;
    final hasPhoto = photoEntry.hasPhotos;

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
            // Extra ~6px of top space for the peeking card-edge slivers
            // below — accounted for in _DaySlot's Flexible sizing so it
            // doesn't reintroduce a Column-overflow.
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Stacked-photo effect: two thin "card edge" slivers
                  // peeking out above/behind the top photo, evoking a
                  // fanned stack of photos. Deliberately outside the
                  // ClipRRect below, same as before this redesign — they
                  // need to poke past the card's rounded bounds.
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
                    borderRadius: BorderRadius.circular(AppShape.radius - 1),
                    child: SizedBox(
                      width: JournalGalleryCard.width,
                      height: JournalGalleryCard.photoHeight,
                      child: Stack(
                        children: [
                          hasPhoto
                              ? Image.file(
                                  File(photoEntry.photos.first.filePath),
                                  width: JournalGalleryCard.width,
                                  height: JournalGalleryCard.photoHeight,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      JournalGalleryCard.placeholder(colors),
                                )
                              : JournalGalleryCard.placeholder(colors),
                          if (hasPhoto)
                            PositionedDirectional(
                              start: 0,
                              end: 0,
                              bottom: 0,
                              child: Container(
                                height: JournalGalleryCard.photoHeight * 0.6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      colors.inkPrimary.withValues(alpha: 0),
                                      colors.inkPrimary
                                          .withValues(alpha: 0.85),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          PositionedDirectional(
                            start: 8,
                            end: 8,
                            bottom: 8,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MonoText(
                                  DateFormat('dd MMM').format(first.loggedAt),
                                  color: hasPhoto
                                      ? colors.surface.withValues(alpha: 0.75)
                                      : colors.inkMuted,
                                ),
                                if (placeName != null &&
                                    placeName.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    placeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.title.copyWith(
                                      fontSize: 17,
                                      color: hasPhoto
                                          ? colors.surface
                                          : colors.inkPrimary,
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
                  // Day-count badge stays outside the ClipRRect, same
                  // position as before this redesign — it's always shown
                  // here (unconditionally, unlike the photo-count badge
                  // above) since a grouped card is only ever built for
                  // day.length > 1.
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
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run the existing gallery card tests**

Run: `flutter analyze && flutter test test/widget/journal/journal_gallery_card_test.dart test/widget/journal/journal_gallery_timeline_test.dart`
Expected: PASS, no analyzer issues. These tests assert on text presence, border color, and badge visibility — not layout position — so they should pass against the new structure unmodified.

- [ ] **Step 5: Run the full widget suite for this feature to check for incidental breakage**

Run: `flutter test test/widget/journal`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/journal/presentation/journal_widgets.dart
git commit -m "feat(journal): photo-dominant gallery card with caption overlaid on the photo"
```

---

### Task 4: Full-screen pinch-zoom photo viewer

**Files:**
- Create: `lib/features/journal/presentation/journal_photo_viewer.dart`
- Modify: `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`
- Modify: `pubspec.yaml`
- Test: `test/widget/journal/journal_photo_viewer_test.dart`

**Interfaces:**
- Produces: `Future<void> showJournalPhotoViewer(BuildContext context, {required List<JournalPhoto> photos, required int initialIndex, required void Function(int index) onPageChanged})` — a top-level function in the new file, following the same `show...` naming/signature convention as `showJournalEntryPresentationSheet`.
- Consumes (from `journal_entry_presentation_sheet.dart`'s existing `_photoCarousel`): `widget.entry.photos` (`List<JournalPhoto>`), `_currentPhoto` (`int`).

- [ ] **Step 1: Promote `photo_view` to a direct dependency**

`photo_view` is already resolved as a transitive dependency at `0.15.0` (pulled in by an existing package) — adding it directly at the same version doesn't change dependency resolution.

In `pubspec.yaml`, find the `dependencies:` block and add, alongside the other direct dependencies (e.g. near `image_picker: ^1.2.0`):

```yaml
  photo_view: ^0.15.0
```

Run: `flutter pub get`
Expected: resolves cleanly, `photo_view` moves from `dependency: transitive` to `dependency: direct main` in `pubspec.lock`, still at `0.15.0`.

- [ ] **Step 2: Create the full-screen viewer**

Create `lib/features/journal/presentation/journal_photo_viewer.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/journal_photo.dart';

/// Full-screen, pinch-zoomable gallery for one entry's photos — opened by
/// tapping a photo in the presentation sheet's carousel ([initialIndex]
/// matches whichever photo was showing there). Swiping here reports the
/// new index via [onPageChanged] so the carousel resumes on the same
/// photo after this viewer is dismissed.
Future<void> showJournalPhotoViewer(
  BuildContext context, {
  required List<JournalPhoto> photos,
  required int initialIndex,
  required void Function(int index) onPageChanged,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _JournalPhotoViewer(
        photos: photos,
        initialIndex: initialIndex,
        onPageChanged: onPageChanged,
      ),
    ),
  );
}

class _JournalPhotoViewer extends StatefulWidget {
  const _JournalPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.onPageChanged,
  });

  final List<JournalPhoto> photos;
  final int initialIndex;
  final void Function(int index) onPageChanged;

  @override
  State<_JournalPhotoViewer> createState() => _JournalPhotoViewerState();
}

class _JournalPhotoViewerState extends State<_JournalPhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.inkPrimary,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _controller,
            itemCount: widget.photos.length,
            onPageChanged: widget.onPageChanged,
            backgroundDecoration: BoxDecoration(color: colors.inkPrimary),
            builder: (context, index) => PhotoViewGalleryPageOptions(
              imageProvider: FileImage(File(widget.photos[index].filePath)),
              heroAttributes:
                  PhotoViewHeroAttributes(tag: widget.photos[index].id),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
          PositionedDirectional(
            top: 8,
            start: 8,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.inkPrimary.withValues(alpha: 0.55),
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: colors.surface),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Wire the tap in the presentation sheet's photo carousel**

In `lib/features/journal/presentation/journal_entry_presentation_sheet.dart`, add the import alongside the existing local imports:

```dart
import 'journal_photo_viewer.dart';
```

In `_photoCarousel`, find:

```dart
              child: PageView(
                controller: _photoController,
                onPageChanged: (i) => setState(() {
                  _currentPhoto = i;
                  _handedOff = false;
                }),
                children: [
                  for (final photo in photos)
                    Image.file(
                      File(photo.filePath),
                      width: double.infinity,
                      height: height,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: colors.paper),
                    ),
                ],
              ),
```

Replace with:

```dart
              child: PageView(
                controller: _photoController,
                onPageChanged: (i) => setState(() {
                  _currentPhoto = i;
                  _handedOff = false;
                }),
                children: [
                  for (final photo in photos)
                    GestureDetector(
                      onTap: () => showJournalPhotoViewer(
                        context,
                        photos: photos,
                        initialIndex: _currentPhoto,
                        onPageChanged: (i) =>
                            setState(() => _currentPhoto = i),
                      ),
                      child: Hero(
                        tag: photo.id,
                        child: Image.file(
                          File(photo.filePath),
                          width: double.infinity,
                          height: height,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: colors.paper),
                        ),
                      ),
                    ),
                ],
              ),
```

- [ ] **Step 4: Write the failing test**

Create `test/widget/journal/journal_photo_viewer_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_photo.dart';
import 'package:tripper/features/journal/presentation/journal_photo_viewer.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: child,
    );

void main() {
  testWidgets('opens a full-screen PhotoViewGallery at the given index, '
      'reports page changes, and closes on tap', (tester) async {
    final dir = Directory.systemTemp.createTempSync('journal_photo_viewer');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // OS cleans up temp dirs — don't fail the test over a lock.
      }
    });
    final photoA = File('${dir.path}/a.png')
      ..writeAsBytesSync(_pngBytes);
    final photoB = File('${dir.path}/b.png')
      ..writeAsBytesSync(_pngBytes);
    final photos = [
      JournalPhoto(id: 'p1', filePath: photoA.path),
      JournalPhoto(id: 'p2', filePath: photoB.path),
    ];

    int? reportedIndex;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJournalPhotoViewer(
              context,
              photos: photos,
              initialIndex: 1,
              onPageChanged: (i) => reportedIndex = i,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewGallery), findsOneWidget);

    await tester.drag(find.byType(PhotoViewGallery), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(reportedIndex, 0);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewGallery), findsNothing);
  });
}

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/widget/journal/journal_photo_viewer_test.dart`
Expected: FAIL — `journal_photo_viewer.dart` doesn't exist yet if Step 4 was done before Step 2/3, or the test fails to find `showJournalPhotoViewer` / `PhotoViewGallery` if run before those exist. (If Steps 2–3 are already done by the time this step runs, skip re-verifying failure and proceed to Step 6 — the point of this step is to catch a typo'd test, not to enforce strict ordering.)

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/widget/journal/journal_photo_viewer_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the full widget suite for this feature to check for incidental breakage**

Run: `flutter analyze && flutter test test/widget/journal`
Expected: PASS, no analyzer issues.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock \
  lib/features/journal/presentation/journal_photo_viewer.dart \
  lib/features/journal/presentation/journal_entry_presentation_sheet.dart \
  test/widget/journal/journal_photo_viewer_test.dart
git commit -m "feat(journal): full-screen pinch-zoom photo viewer"
```

---

### Task 5: Entry summary is optional

**Files:**
- Modify: `lib/features/journal/presentation/journal_entry_form_sheet.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/widget/journal/journal_entry_form_sheet_test.dart`

**Interfaces:**
- Produces: `journal_entry_form_sheet.dart` no longer blocks saving on an empty summary. No other file depends on the removed `_summaryError` field or `errJournalSummaryRequired` string.

- [ ] **Step 1: Remove the mandatory-summary validation**

In `lib/features/journal/presentation/journal_entry_form_sheet.dart`, find the field declaration:

```dart
class _JournalEntryFormState extends ConsumerState<_JournalEntryForm> {
  final _summary = TextEditingController();
  DateTime? _loggedAt;
  bool _summaryError = false;
  bool _saving = false;
```

Remove the `bool _summaryError = false;` line:

```dart
class _JournalEntryFormState extends ConsumerState<_JournalEntryForm> {
  final _summary = TextEditingController();
  DateTime? _loggedAt;
  bool _saving = false;
```

Find the `TextField`'s decoration:

```dart
          decoration: InputDecoration(
            hintText: l10n.journalFieldSummary,
            errorText: _summaryError ? l10n.errJournalSummaryRequired : null,
            filled: true,
```

Remove the `errorText:` line entirely:

```dart
          decoration: InputDecoration(
            hintText: l10n.journalFieldSummary,
            filled: true,
```

Find `_save()`:

```dart
  Future<void> _save() async {
    if (_summary.text.trim().isEmpty) {
      setState(() => _summaryError = true);
      return;
    }
    setState(() => _saving = true);
```

Remove the validation block:

```dart
  Future<void> _save() async {
    setState(() => _saving = true);
```

- [ ] **Step 2: Remove the now-unused ARB string**

In `lib/l10n/app_en.arb`, remove the `"errJournalSummaryRequired": "Enter a summary",` entry (and its preceding `@errJournalSummaryRequired` description block, if the ARB file has one — check the lines immediately above/below the key).

Run: `flutter pub get`
Expected: regenerates `lib/l10n/app_localizations.dart` and `lib/l10n/app_localizations_en.dart` without the removed getter (triggered automatically since `pubspec.yaml` has `generate: true`).

- [ ] **Step 3: Replace the mandatory-summary test**

In `test/widget/journal/journal_entry_form_sheet_test.dart`, find:

```dart
  testWidgets('saving without a summary shows a validation error, no save',
      (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a summary'), findsOneWidget);
    expect(await repo.watchForTrip('trip-1').first, isEmpty);
  });
```

Replace with:

```dart
  testWidgets('saving without a summary creates the entry with an empty '
      'summary', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final entries = await repo.watchForTrip('trip-1').first;
    expect(entries, hasLength(1));
    expect(entries.single.summary, isEmpty);
  });
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget/journal/journal_entry_form_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full widget suite for this feature to check for incidental breakage**

Run: `flutter analyze && flutter test test/widget/journal`
Expected: PASS, no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/journal/presentation/journal_entry_form_sheet.dart \
  lib/l10n/app_en.arb lib/l10n/app_localizations.dart \
  lib/l10n/app_localizations_en.dart \
  test/widget/journal/journal_entry_form_sheet_test.dart
git commit -m "feat(journal): entry summary is no longer mandatory to save"
```
