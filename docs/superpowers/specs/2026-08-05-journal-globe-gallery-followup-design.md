# Journal globe/gallery follow-up: dot sizing, tap sync, presentation view, card redesign

Status: approved, not yet implemented. Builds on `2026-08-05-journal-globe-gallery-design.md` (already shipped).

## Problem

Four follow-up issues against the shipped journal globe/gallery feature:

1. Non-photo globe dots grow when the user pinches to zoom in; photo dots (already widget-rendered) don't.
2. Tapping a globe dot does nothing — it should re-center the globe there and bring the matching gallery card into view.
3. Tapping a gallery entry jumps straight into editing it. It should open a read-only view first; editing is an explicit action from inside that view.
4. The gallery card is too wide because it has to fit an inline delete button, and doesn't read well now that tapping opens something richer.

Confirmed via mockups (`.superpowers/brainstorm/1931-1785930425/content/`, gitignored) with the user before writing this spec.

## 1. Globe dots: unify rendering, fix hit-testing

**Root cause of the zoom problem** (confirmed by reading the installed `flutter_earth_globe` v2.2.1 source, `gpu_foreground_painter.dart`): native `PointStyle`-rendered dots are scaled by an internal, undocumented `globeScale = radius / 150.0` factor that grows with zoom. Photo dots don't have this problem because they're rendered as a `Point.labelBuilder` Flutter widget positioned at the point's screen coordinates — widget size comes from layout, not the GPU painter.

**Fix:** every point — photo or not — renders via `labelBuilder`, sized as a fixed Flutter widget, so nothing is subject to the painter's zoom scaling. `PointStyle` becomes a zero-size placeholder for every point (`PointStyle(size: 0)` universally, replacing today's `entry.hasPhotos ? 0 : _dotSize` branch).

- New `_PlainDot` widget alongside the existing `_PhotoDot`: a small solid accent-colored circle (~11px, versus the photo dot's 26px), same `labelOffset`-centering technique already documented in the code.
- **Hit-testing fix, now load-bearing (was previously a deferred/dead-code finding):** the GPU painter's hit-test region is derived from `PointStyle.size`, which is now always 0 for every point — so relying on the package's native tap detection would make every dot untappable everywhere, not just for photo dots. Both dot widgets wrap themselves in a `GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: ...)`, calling the `Point`'s own `onTap` directly (available inside the `labelBuilder` closure via the `point` parameter) — tap detection now matches exactly what's drawn, independent of the painter's internal hit-region math.

## 2 & 3. Selection sync + presentation view

### Coordinator

`TripJournalTab` changes from `ConsumerWidget` to `ConsumerStatefulWidget`, holding a single `String? _selectedEntryId`. It's the only place that knows about both the globe and the gallery, so it's the natural owner of "which entry is currently in focus."

- **Tap a globe dot** → `JournalGlobe.onEntryTap` (already exists, wasn't wired) sets `_selectedEntryId`. The globe is already centered on the tapped point; the gallery reacts to the new `selectedEntryId` by scrolling to and outlining that entry's day-slot.
- **Tap a gallery card** → sets `_selectedEntryId` to the tapped entry (or, for a grouped/multi-entry day, the first entry — see below) *and* opens the presentation view. The globe reacts to the new `selectedEntryId` by animating to that entry's coordinates.
- **Swipe inside the presentation view** (multi-entry day) → each page change updates `_selectedEntryId` to match whichever entry is currently showing, keeping globe and gallery in sync with the swiper too.

### Globe: generalized focus

`JournalGlobe` gains a `selectedEntryId` parameter. Today's `_focusedEntryId`/`_maybeFocusLatest` mechanism generalizes: an explicit, changed `selectedEntryId` takes priority and triggers an animated focus to that entry; the existing "focus on the latest entry" behavior remains the fallback for initial load and for when entries change with no explicit selection driving focus. If the selected entry has no location (not every entry does), the globe simply does nothing — there's no point to focus on, and the selection still applies normally on the gallery side.

### Gallery: scroll-to and highlight

`JournalGalleryTimeline` (currently `StatelessWidget`) becomes a `StatefulWidget` holding a `GlobalKey` per day-slot. On a `selectedEntryId` change, it calls `Scrollable.ensureVisible` on the matching day-slot's key to bring it into the visible strip. The matching slot's card gets an accent-colored (~1.5px) border in place of its usual hairline border while selected — the app's existing "hairline border, no shadow" visual language, just teal instead of neutral. For a grouped (multi-entry) day, the whole card is outlined if *any* of its entries is the selected one — the compact card can't indicate which of several.

### Presentation view replaces the day-list sheet

New file `journal_entry_presentation_sheet.dart`: `showJournalEntryPresentationSheet(context, {tripId, entries, initialIndex, onPageChanged})`, where `entries` is the tapped day's full entry list (length 1 for a single-entry day) and `initialIndex` is which one to open on.

- A bottom sheet (`isScrollControlled: true`), not full-screen — confirmed with the user, and consistent with every other journal interaction being a sheet.
- A `PageView` over `entries`, one page per entry, with a small page-position indicator (a row of dots, accent for the active one) shown only when there's more than one page.
- **Per-page layout:** if the entry has a photo, it fills the top of the page edge-to-edge (flush with the sheet's rounded top corners, no gap above it) with a bottom gradient scrim for legibility. The drag handle and a **⋮** overflow-menu button float above the page content as a persistent overlay, at a consistent position whether or not the current page has a photo — this keeps the header from jumping around while swiping between a photo entry and a stub entry in the same day. Below the photo (or, for a photo-less entry, near the top): mono date/time, an accent-colored place chip if the entry has a `placeName`, then the entry's `summary` text — or the existing `journalUntitledEntry` ("Not written yet") fallback if it's empty. There is no separate headline/title field in the data model; `summary` is the only body text, so nothing is fabricated for display. Long summaries scroll within the sheet (`SingleChildScrollView`) rather than growing the sheet past a reasonable height.
- **⋮ menu:** two items, matching the existing app pattern (`place_actions_sheet.dart`) of popping the current sheet before opening the next one:
  - **Edit** — pops the presentation sheet, opens the existing `showJournalEntryFormSheet` for whichever entry is on the current page.
  - **Delete** — the existing confirm-dialog text/flow (moved here from `TripJournalTab._confirmDelete`, which is deleted since this becomes its only caller), then deletes via `journalRepositoryProvider` and closes the presentation sheet. Deleting an entry always closes the sheet back to the gallery, even mid-swipe through a multi-entry day — no attempt to remove just that page from a live `PageView` session.
- **Multi-entry day, opened from a grouped gallery card:** always opens at `initialIndex: 0` (the day's earliest entry) — the compact card has no way to pick a specific one, matching what was confirmed. The day-list sheet (`showJournalDayEntriesSheet`/`_JournalDayEntriesSheet`, and the `journalDayEntriesTitle` l10n string that only it used) is deleted entirely — swiping through the presentation view replaces it.

## 4. Gallery card redesign

Direction B from the mockups, replacing today's wider photo+date+summary card:

- Narrower (~116px vs. today's 148px).
- Photo on top (~88px tall).
- A thin caption strip below: `MonoText` date, and — if the entry has a `placeName` — the place name in `colors.accent`, single line, ellipsized. No summary text (the presentation view carries that now).
- **No inline delete button** — `JournalGalleryCard`'s `onDelete` parameter is removed entirely; deleting only happens from inside the presentation view's menu.
- `onTap` still exists but now means "open the presentation view for this entry," not "edit."
- `_GroupedGalleryCard` keeps its stacked-photo-edges + count-badge treatment, narrowed to match, with the same caption-strip restyle (date + first entry's place name, no summary line). `onTap` opens the presentation view in swipe mode.

`JournalGalleryTimeline`'s public interface changes from separate `onEdit`/`onDelete` callbacks to a single `onTapDay(List<JournalEntry> dayEntries, int tappedIndex)` — it only reports what was tapped; `TripJournalTab` owns deciding that this means "select + open the presentation view."

## Testing

- Globe: the zoom-independent sizing and the hit-test fix are GPU-rendering behavior, same accepted manual-verification-only limitation as the rest of this feature (no widget test can construct a real `FlutterEarthGlobeController`). The `renderGlobe: false` scaffold and the `selectedEntryId`/`onEntryTap` wiring at the `TripJournalTab` level are the parts that remain testable.
- Gallery: card redesign (no delete button, new caption layout), the accent-border selected state, and the `onTapDay` callback firing with the right day/index are all testable via widget tests, same pattern as the existing `journal_gallery_timeline_test.dart`. Scroll-to-selected can be asserted by checking the target card's rect falls within the scrollable's visible viewport after a selection change, rather than asserting an exact scroll offset.
- New `journal_entry_presentation_sheet_test.dart`: single-entry (no page indicator), multi-entry (swipe changes the visible entry and fires `onPageChanged`), empty-summary fallback text, Edit opens the form sheet for the current page's entry, Delete removes it and closes the sheet.
- Obsolete tests for the deleted day-list sheet are removed, not carried forward.
- No new network calls anywhere in this design — consistent with CLAUDE.md's offline-first rule.
