# Journal globe/gallery polish: smoothness, multi-photo, contrast, elegance

Status: approved, not yet implemented. Third pass on the journal globe/gallery feature, following `2026-08-05-journal-globe-gallery-design.md` and `2026-08-05-journal-globe-gallery-followup-design.md` (both already shipped).

## Problem

Seven follow-up issues:

1. Globe dots visibly lag/stutter behind the sphere's surface during rotation/drag.
2. An entry with more than one photo has no way to view the others — everywhere (gallery card, presentation page) only ever shows `photos.first`.
3. The presentation sheet's overflow menu (⋮) has poor contrast and is hard to see.
4. The gallery card is too wide with awkward empty space — needs a more elegant, tighter design.
5. The globe should track whichever entry is currently centered in the gallery's *visible, on-screen* strip as the user scrolls — not a fixed "middle of all entries" notion.
6. On the presentation page, the photo should dominate; the summary belongs at the bottom, scrollable if it doesn't fit.
7. On the presentation page, the location name should read as the entry's title — prominent, not a small icon+text row.

Confirmed via mockups (`.superpowers/brainstorm/3463-1786094395/content/`, gitignored) and direct investigation of the `flutter_earth_globe` package's animation loop before writing this spec.

## 1. Globe rotation smoothness — split dot rendering by necessity, not uniformly

**Root cause** (confirmed by reading `rotating_globe.dart`): the sphere's rotation animation drives `setState` every frame, and every point's screen position is recomputed each frame regardless of how it's rendered. Before the previous round, only photo dots were `Point.labelBuilder` widgets (real Flutter widget trees rebuilt every frame); the previous round's zoom-scaling fix converted *every* dot — including the (usually more numerous) non-photo ones — to the same widget-rendered technique, multiplying the per-frame widget-rebuild cost during rotation. That's the jank.

**Fix:** un-unify the two dot types. Non-photo entries go back to native, GPU-rendered `PointStyle` dots — cheap, and perfectly in sync with the sphere's rotation by construction (the shader paints them, no separate widget-position recompute pass). Photo entries stay `labelBuilder`-rendered (unavoidable — native points can't display an image), keeping their zoom-independent sizing from before.

- Non-photo dots: `PointStyle(size: <small fixed value>, color: colors.accent)`, and — since there's no longer a widget-level `GestureDetector` for these — `Point.onTap` is set directly on the `Point` for them.
- Photo dots: unchanged from the current implementation (`PointStyle(size: 0)`, `labelBuilder` returning the photo-thumbnail widget with its own `GestureDetector`, `Point.onTap` left unset to avoid the double-fire risk already documented in the code).

This reintroduces zoom-based size growth for non-photo dots specifically (the trade-off the user explicitly chose to accept in order to fix smoothness first). Manual on-device verification is required either way — GPU rendering behavior has never been testable in this environment.

## 2. Multi-photo carousel

Each presentation page gains an inner swipeable carousel across `entry.photos` (a nested `PageView`, independent of the outer PageView that swipes between different *entries* in the same day), with its own small dot indicator drawn on the photo itself — visually distinct from the day/entry-position indicator below the sheet. The gallery card shows a small photo-count badge (e.g., a dark pill with the count) in the corner of its photo when `entry.photos.length > 1`.

## 3. Menu contrast

The persistent ⋮ menu overlay (already hoisted out of per-page code in the prior round) always renders on a solid, low-alpha-dark circular scrim (`colors.inkPrimary.withValues(alpha: ~0.55)`) whenever the current entry has a photo — fixing the case where it previously sat directly on a bright photo with no backing. For a photo-less entry it stays a plain muted icon with no scrim, matching the existing (already-adequate) contrast against the plain surface there.

## 4. Gallery card redesign (Direction B, confirmed via mockup)

Tighter rectangle: 100×76 photo (down from 116×88), with the caption compressed to a single row (mono date + accent-colored place name side by side) instead of today's two-line block below the photo. Photo-count badge sits on the photo itself when the entry has more than one photo (per §2).

## 5. Globe follows the gallery's visible-center entry, live

A new signal, independent of tap-driven selection: as the user scrolls the gallery horizontally, whichever day-slot is currently centered in the *visible* strip drives the globe's camera live — recomputed on every scroll update (not just at rest), applied as an instant reposition (no separate easing animation, since the scroll gesture itself already supplies the perceived motion; stacking a 600ms eased pan on top would fight the scroll and look laggy, not smooth).

This is deliberately kept separate from `selectedEntryId` (tap-driven): scrolling never changes which card shows the accent border or opens the presentation sheet — only the globe's orientation follows live. A grouped (multi-entry) day-slot's representative for this purpose is its first entry, consistent with how tapping a grouped card already opens at index 0.

Mechanism: the gallery's scroll view is wrapped in a `NotificationListener<ScrollNotification>`; on each update, every visible day-slot's on-screen horizontal center (via its existing per-slot `GlobalKey`) is compared against the viewport's own center, and the closest slot's representative entry is reported upward only when it changes (not on every pixel of scroll). `JournalGlobe` gains a new `liveFollowEntryId` parameter distinct from `selectedEntryId`; a changed value triggers an unanimated `focusOnCoordinates` call and updates the same internal "currently centered on" tracking `selectedEntryId`-driven focus already uses, so a subsequent tap on the now-centered entry correctly no-ops instead of re-animating to where the globe already is.

## 6 & 7. Presentation page: photo-dominant, location as title, scrollable summary

- The photo (or photo carousel, §2) fills most of the sheet's height, unchanged in width.
- The place name renders as a large serif headline (Fraunces, matching CLAUDE.md's "serif for names/titles" rule) directly below the photo — the entry's title. The date drops to a small mono line above/beside it, no longer the most prominent element.
- The summary sits below that in a scrollable region, so a long summary never has to compete with the photo for space and never forces the sheet taller than intended.
- **Sheet height adapts to content**, rather than always claiming a fixed tall fraction of the screen: a photo entry keeps the current generous height (photo needs the room); a photo-less entry uses a shorter fixed height (roughly half), sized for just the header chrome, date, title, and a few lines of summary (still internally scrollable as a safety net for an unusually long summary, not for normal layout). When swiping between a photo entry and a photo-less entry within the same multi-entry day, the sheet's height animates smoothly between the two rather than snapping.

## Testing

- Globe: dot-rendering split, live-follow-on-scroll, and rotation smoothness are GPU-rendering behavior — same accepted manual-verification-only limitation as every prior round; no widget test can construct a real `FlutterEarthGlobeController`. The scroll-position → centered-entry computation in the gallery, however, IS testable (pure geometry against real `GlobalKey`/`RenderBox` positions in a widget test), as is the `liveFollowEntryId` plumbing through to `JournalGlobe`'s prop (same pattern already used for `selectedEntryId`).
- Multi-photo carousel, menu contrast (scrim presence), gallery card redesign, and the presentation page's photo-dominant/title/scrollable-summary layout and height-adapts-to-content behavior are all standard widget-test territory, following the existing test patterns in `journal_gallery_card_test.dart` and `journal_entry_presentation_sheet_test.dart`.
- No new network calls anywhere in this design — consistent with CLAUDE.md's offline-first rule.
