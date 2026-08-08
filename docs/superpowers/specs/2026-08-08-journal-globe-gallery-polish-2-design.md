# Journal globe/gallery polish, round 2: stale-animation fix, zoom, dot character, card redesign, full-screen photos, optional summary

Status: approved, not yet implemented. Fourth pass on the journal globe/gallery feature, following `2026-08-05-journal-globe-gallery-design.md`, `2026-08-05-journal-globe-gallery-followup-design.md`, and `2026-08-07-journal-globe-gallery-polish-design.md` (all shipped). Two issues from the third round were reported fixed but are not actually resolved on-device; this spec re-diagnoses them from the package's source rather than re-guessing, plus five new issues.

## Problem

Two carried-over issues, confirmed still broken on-device:

1. Globe dots visibly lag/stutter/fight during rotation — the third round's dot-rendering split (native vs. widget-rendered) did not fix this; the actual cause is elsewhere (see §1).
2. The gallery card is still "goofy" — too wide, awkward empty space — despite the third round's redesign to a tighter 100×76 card. Diagnosed via a Polarsteps reference screenshot the user provided (`assets/globe/card_design_presentation.png`): the current card's separate caption block below the photo is itself the likely source of the "empty space" feel.

Five new issues:

3. Entry summary should not be mandatory to save.
4. Tapping a photo in the entry presentation card should open a full-screen, pinch-zoom-capable gallery view of that entry's photos.
5. The globe's native dots are visually flat — no character.
6. The globe's zoom is capped too shallow.
7. Dot rendering glitches: dots sometimes fail to rerender, get stuck, update late, or only self-correct after the user manually drags the globe.

## 1. Root cause: stale animation controller, not dot-rendering technique

Investigated directly against the installed `flutter_earth_globe` 2.2.1 source (`rotating_globe.dart`), not by re-guessing at the dot-rendering approach again.

`focusOnCoordinates(coordinates, {animate, duration, curve})`:

- `animate: true` — disposes any existing `genericAnimationController`, creates a fresh one, and animates rotation toward the target over `duration`.
- `animate: false` — assigns `rotationX/Y/Z` once and calls `setState`. **It does not touch `genericAnimationController` at all.**

`journal_globe.dart` calls this in three places:

- `_maybeFocusSelected()` — tap-driven, `animate: true, duration: 600ms`. Safe: always disposes any prior controller.
- `_maybeFollowLive()` — scroll-driven live-follow, calls with no `animate`/`duration` args, which resolves to the controller-level wrapper's default `animate: false`.
- `_maybeFocusLatest({bool animate = true})` — called with `animate: false` once, from `_buildController()`'s `onLoaded` (the very first focus, on initial load).

**The bug:** if `_maybeFocusSelected`'s 600ms animation is still in flight when `_maybeFollowLive` fires (a completely ordinary sequence — tap a globe dot, then scroll the gallery before 600ms elapses), the live-follow call sets rotation once, but the *original* animation's listener is still ticking and immediately overwrites it back toward the tap-target on the next frame. The globe appears to ignore the live-follow update, "catch up" late once the stale animation finishes, or only visually resolve when a manual drag gesture takes over rotation directly (interrupting the stale controller's influence by driving rotation from pointer deltas instead). This matches every symptom in issue 7, and is a major contributor to issue 1 — a stale animation fighting a real rotation drag reads as jank/lag, independent of how dots are rendered.

**Fix:** never call `animate: false`. Route every "instant" case through `animate: true, duration: Duration.zero` — still visually instant (nothing to animate over), but now goes through the package's own dispose-and-replace path, which is the only path that guarantees no previous controller survives to fight the new state. Concretely:

- `_maybeFollowLive()`: `controller.focusOnCoordinates(coords, animate: true, duration: Duration.zero)`.
- `_maybeFocusLatest`: drop the `animate` parameter entirely; always call with `animate: true`, using `duration: animate ? const Duration(milliseconds: 600) : Duration.zero` internally based on the existing `animate` bool passed by callers (rename the local parameter to avoid confusion with the now-constant `animate: true` argument to `focusOnCoordinates` — e.g. rename the method's own parameter to `bool instant = false` and pass `duration: instant ? Duration.zero : const Duration(milliseconds: 600)`).
- `_maybeFocusSelected()`: unchanged — already safe.

This is GPU rendering / package-internal-animation behavior, so — same as every prior round — it is manual-verification-only; no widget test can construct a real `FlutterEarthGlobeController`. The fix's *shape* (always `animate: true`) is itself directly readable from the diff and reviewable even without running it.

## 2. Zoom limit

`FlutterEarthGlobeController` defaults `maxZoom` to `2.5` (`radius = baseRadius * 2^zoom`, so ~5.7x). We never override it. Add `maxZoom: 5` (~32x) to the controller constructed in `_buildController()`. `minZoom` (zoom-out) is unaffected and stays at the package default.

## 3. Dot character — layered native halo, monochrome teal

`PointStyle` (the native, GPU-rendered dot style used for smoothness) only exposes `size`, `color`, `altitude`, `transitionDuration`, `merge` — no border, glow, or gradient. Getting visual richness without reintroducing the widget-rendered-dot smoothness cost means layering multiple native points at the same coordinates.

**Non-photo dots:** add a second native `Point` — a "halo" — at the same coordinates as the existing solid dot, using `id: '${entry.id}-halo'` (so `addPoint`/`removePoint` in `_syncPoints` can manage it independently of the core dot's `id: entry.id`). Halo: larger `size`, `colors.accent.withValues(alpha: ~0.28)`. Core dot: unchanged (`_plainDotSize`, full-opacity `colors.accent`). The halo point must be added to the controller *before* the core point in `_addPoints`, so it paints first and sits behind the core visually if the package draws points in insertion order — this ordering assumption needs on-device confirmation (GPU rendering, same manual-verification-only caveat as the rest of this section).

**Photo dots:** add the identical halo point (same id convention, same color/alpha) beneath the existing `_PhotoDot` widget position, for visual consistency between the two dot types and closer to the Polarsteps reference's glow-ring-around-photo look. `_PhotoDot` itself is unchanged.

Both halo points must be removed alongside their corresponding core point in `_syncPoints`'s existing removal loop.

## 4. Gallery card — photo-dominant, caption burned into the photo

Both `JournalGalleryCard` (single entry) and `_GroupedGalleryCard` (multi-entry day) move from 100×76 with a separate caption row to **150×130** with the caption overlaid directly on the photo via a bottom gradient scrim — matching the structural idea from the Polarsteps reference, rendered in Tripper's own visual language rather than copied literally:

- Place name: Fraunces serif, ~17px, `colors.surface` (on-photo-safe token, not a raw color), positioned bottom-left over the scrim.
- Date: mono, smaller, `colors.surface.withValues(alpha: 0.75)`, directly above the place name.
- Scrim: bottom ~60% of the card height, `LinearGradient` from `colors.inkPrimary.withValues(alpha: 0)` to `colors.inkPrimary.withValues(alpha: 0.85)` — same token family already used for the presentation sheet's photo-carousel gradient.
- Photo-count badge: unchanged position/style (top-right, `colors.inkPrimary.withValues(alpha: 0.72)` pill), shown when the entry (or the grouped day's representative photo entry) has more than one photo.
- No-photo placeholder case: no scrim (nothing to darken) — same caption content and position, but in normal ink-on-paper coloring (`colors.inkPrimary` for the place name, `colors.inkMuted` for the date) directly on the flat placeholder background.
- Hairline border (existing `PaperCard` convention) instead of a drop shadow — no change to that mechanism, just the new dimensions.

`_GroupedGalleryCard` mirrors this exactly (same caption approach, same 150×130 footprint) rather than repeating the divergence the previous round's final review already had to fix once (grouped card rendering visibly smaller than single-entry cards via the shared `FittedBox(fit: BoxFit.scaleDown)` in `_DaySlot`). `_DaySlot`'s `Flexible`-based sizing is unaffected by the dimension change — it already adapts to whatever height the card reports.

## 5. Full-screen photo viewer

`photo_view` is already resolved in `pubspec.lock` as a transitive dependency (0.15.0, pulled in by an existing package) — promoting it to a direct dependency at the same version is dependency-tree-neutral.

Tapping a photo inside `_JournalEntryPresentationPageState._photoCarousel`'s `PageView` pushes a new full-screen route (`Navigator.push`, no named route needed) containing `PhotoViewGallery.builder`:

- `itemCount`/`builder` over `entry.photos`, `imageProvider: FileImage(File(photo.filePath))`.
- `pageController` initialized to the carousel's current `_currentPhoto` index, so the viewer opens on the photo that was tapped.
- `heroAttributes: PhotoViewHeroAttributes(tag: photo.id)` per photo, paired with a matching `Hero(tag: photo.id, ...)` wrapping each `Image.file` in the carousel, for a tap-to-expand transition.
- `backgroundDecoration: BoxDecoration(color: colors.inkPrimary)` — CLAUDE.md's hard rule against raw `Colors.*` constants has no carve-out for a full-screen viewer, so this uses the theme's existing near-black ink tone rather than literal `Colors.black`.
- Default `minScale`/`maxScale` (`PhotoViewComputedScale.contained` / `.covered * 2`) — no custom zoom limits needed.
- A close affordance (back button, top-left, on a small scrim) and swipe-down-to-dismiss via `PhotoView`'s own gesture handling (falls back to the close button if swipe-to-dismiss isn't natively supported by this package version — confirm during implementation).
- `onPageChanged` keeps the underlying carousel's `_currentPhoto` in sync, so backing out of the full-screen viewer leaves the carousel showing whatever photo the user ended on.

## 6. Summary optional

The DB column (`min: 0`), domain model, and repository layer already support an empty summary, and the presentation sheet already has a "Not written yet" display fallback for it. The only blocker is `journal_entry_form_sheet.dart`'s `_save()`:

```dart
if (_summary.text.trim().isEmpty) {
  setState(() => _summaryError = true);
  return;
}
```

Remove this check, the `_summaryError` field, and its use in the `TextField`'s `errorText`. Remove the now-unused `errJournalSummaryRequired` ARB entry (and regenerate `app_localizations*.dart` via `flutter gen-l10n`, triggered automatically by `flutter pub get`/`flutter test` since `generate: true` is set). Replace the existing test `'saving without a summary shows a validation error, no save'` with a test confirming a summary-less entry saves successfully (mirroring the existing empty-summary-stub pattern from `markPlaceVisited`).

## Testing

- §1 (stale-animation fix) and §3 (dot halo) are GPU/package-animation behavior — manual-verification-only, same standing limitation as every prior round. The fix's *shape* is diff-reviewable.
- §2 (zoom) is a single constructor argument — no dedicated test, covered by the existing "globe builds without throwing" scaffolding.
- §4 (gallery card redesign) is standard widget-test territory, following `journal_gallery_card_test.dart`'s existing patterns (dimensions, caption text presence, badge visibility).
- §5 (full-screen viewer) is testable at the "tapping a photo pushes a route containing `PhotoViewGallery`" level; `photo_view`'s own internal gesture/zoom behavior is the package's responsibility, not re-tested here.
- §6 (optional summary) is straightforward widget-test territory — replace the one existing test as described above.
- No new network calls anywhere in this round — consistent with CLAUDE.md's offline-first rule.
