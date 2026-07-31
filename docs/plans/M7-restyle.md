# M7 — "Wallet & Ticket" restyle

**Goal:** replace the field-journal/boarding-pass-by-typography-alone look with an actual
physical-travel-object metaphor — tickets, boarding passes, luggage tags — plus per-trip
color identity. Supersedes the original SPEC §4 direction; see §4.1 for what's kept vs.
dropped. User signed off on overriding CLAUDE.md hard rules #1 and #6 for this milestone
(2026-07-30). Distinct from the reserved, not-yet-started M6 (live GPS route tracking,
SPEC §3.2.2) — pure coincidence of numbering, no dependency either way.

**Exit criteria:** design tokens + primitives defined and documented (this file's §7.1);
every MVP screen (trips, vault, places/map, expenses, settings) rebuilt on them; dark mode
re-audited; widget/golden tests updated; user has run `flutter analyze && flutter test` on
device/CI and reported green (see CLAUDE.md — Claude cannot run Flutter in this sandbox).

## 7.1 Design system as code — done, this pass

- [x] `AppColors.tripPalette` — 8 identity hues (light + dark), kept structurally separate
      from `warning`/`error`/`success`; `tripAccent(colorTag)` resolves safely (mod length);
      `onColor(background)` picks legible ink-vs-surface text. Tests:
      `test/unit/core/app_colors_test.dart`.
- [x] `AppTypeScale`/`AppTextStyles` widened from 5 to 7 sizes — added `hero` (one per
      screen) and `statValue` (tabular-figure mono for stat tiles). Mapped into
      `AppTheme`'s `TextTheme` (`displayLarge`, `headlineLarge`).
- [x] `AppShape`/`AppElevation` (`app_spacing.dart`) — `ticketRadius`, `ticketNotchRadius`,
      `ticketStubWidth`, perforation dash/gap tokens; elevation-by-brightness helpers
      replacing the flat hairline-border card rule.
- [x] `TicketCard` (`lib/core/widgets/ticket_card.dart`) — the new travel-object primitive:
      `TicketNotchClipper` (die-cut silhouette, RTL-aware) + `TicketPerforationPainter`
      (tear-seam), elevated via `PhysicalShape` so the shadow follows the concave notches.
      Tests: `test/unit/core/ticket_notch_clipper_test.dart`,
      `test/widget/core/ticket_card_test.dart`.
- [x] `PaperCard` updated to shadow-based elevation (was hairline border); kept as the
      primitive for non-ticket surfaces (forms, settings, plain rows).
- [x] CLAUDE.md hard rules #1/#3/#6 and SPEC.md §4 rewritten to document the new system as
      the current hard rules; original direction kept inline as history, not deleted.

**Known consequence, unverified:** bumping `AppShape.radius` (10→14) and `AppElevation`
into the default `CardTheme`/`PaperCard` changes the rendered look of every existing
screen even before they're individually rebuilt in §7.2–7.5, since they inherit theme
values. Any existing golden baselines will need regenerating — flagged here rather than
silently discovered later.

**Two real bugs found via `flutter analyze`/`flutter test` after this was first written
(fixed in `ticket_card.dart`, not just cosmetic):**
1. The press-scale motion (§7.2) never actually appeared while pressed. It used a
   second, outer `GestureDetector` layered on top of the `InkWell` for
   onTapDown/onTapUp/onTapCancel; two independent tap recognizers along the same
   hit-test path share one gesture arena, and neither's `onTapDown` fires until the
   arena's sweep at pointer-*up* — so by the time the "pressed" state was set, the
   gesture was already over. Fixed by using `InkWell`'s own `onHighlightChanged`
   instead of a second recognizer.
2. `labeledTapTargetGuideline` failed against the trips list in
   `accessibility_test.dart`: the tap target had no semantic label.
   `PhysicalShape`/`Stack`/`CustomPaint`/`AnimatedScale` sitting between the
   `InkWell` and the actual text apparently broke Flutter's default semantics-merge.
   Fixed by making `TicketCard.semanticLabel` a *required* parameter — every card
   now carries an explicit, composed label — rather than depending on merging.
   Doing this also surfaced a related risk worth flagging: the fix routes through
   `Semantics(excludeSemantics: true, ...)`, which hides the `InkWell`'s own action
   node, so the wrapping `Semantics` widget also needs its own `onTap:` set or a
   screen reader could announce "button" without being able to activate it — that's
   in place, but it's the kind of thing worth double-checking on a real device with
   TalkBack, not just the automated guideline.
3. `tester.tap(find.text(...))` inside a `TicketCard` logged a hit-test-miss
   warning: the perforation `CustomPaint` (`Positioned.fill`, painted last =
   on top in the `Stack`) was swallowing hits before they reached the
   Row/Text underneath. Harmless today only by accident — `CustomPaint` sits
   inside the same `InkWell`, so the tap still bubbled up to the right
   `onTap` — but would break the moment anything nested a separate gesture
   target under body content. Fixed by wrapping it in `IgnorePointer`.

**Also fixed:** `test/widget/trips/trip_form_screen_test.dart`'s
`matchesSemantics(...)` call only listed the flags/actions it cared about
(`isButton`, `isSelected`); `matchesSemantics` treats that as an exhaustive
list and fails on any other action/flag present. The real `_ColorSwatch`
node also carries `isFocusable`/`hasSelectedState` flags and `tap`/`focus`
actions from its `InkWell` — added those explicitly rather than trimming
the node's real semantics down to match the test.

## 7.2 Trips (list + detail) — done, pending on-device verify

- [x] `TripCard` → `TicketCard`: colored stub = `colors.tripAccent(trip.colorTag)`
      (faded via `tripCardAccent` once a trip is past); active trips get a big
      day-count + "of N" in the stub, other statuses get a status icon
      (`Icons.event_outlined`/`explore_outlined`/`check_circle_outline`).
      Tests: `test/widget/trips/trip_card_test.dart`,
      `test/unit/trips/trip_card_accent_test.dart`.
- [x] Trip detail hero header: `AppTextStyles.hero` trip name on a full-bleed
      band of the trip's own identity color (`tripCardAccent`), replacing the
      small AppBar title. Same `Hero` tag as before, so the list→detail flight
      still works, now flying into a much bigger destination.
- [x] Trip color picker in `TripFormScreen` — 8 swatches over `tripPalette`,
      48dp tap targets + `tripColorSemanticLabel` semantics, wired into
      create/update. Tests: `test/widget/trips/trip_form_screen_test.dart`.
- [x] `TicketCard` press-scale (`AnimatedScale`, built into the primitive
      itself) as the shipped stand-in for motion here.
- **Explicitly descoped:** a real drag-to-fan/stack interaction on the trip
  list. Full gesture code (pan recognizers, physics, reordering) was judged
  too much to ship unverified in one pass — flagged rather than silently
  dropped. Candidate for a future, dedicated pass if wanted.
- **Not yet done:** `androidTapTargetGuideline`/`labeledTapTargetGuideline`
  aren't run against `TripFormScreen` specifically in
  `test/widget/accessibility_test.dart` yet (that suite doesn't currently
  navigate to the form) — the new color swatches were built to the same
  48dp/semantics bar by hand, but a real guideline run would confirm it.

## 7.3 Vault + documents — done, pending on-device verify

- [x] `documentCategoryAccent`: each of the 7 `DocumentCategory` values maps to
      a curated `tripPalette` hue by real-world association (passport=Indigo,
      visa=Plum, flight=Cobalt, stay=Marigold, insurance=Moss,
      transport=Slate, other=Harbor teal) rather than raw enum index. A real
      problem (expired) overrides the category color with `colors.warning`
      via `documentCardAccent` — semantic meaning beats decoration (hard rule
      #1), so an expired passport doesn't quietly stay navy.
      Tests: `test/unit/vault/document_category_accent_test.dart`.
- [x] `DocumentRowTile`/`PinnedDocumentCard` rebuilt on `TicketCard` — category
      icon in the stub, title + `documentMetaLine` in the body, pin indicator
      inline. `PinnedDocumentCard` uses a narrower `stubWidth` (56 vs. the
      84 default) to fit the quick-access grid's 1.9 aspect ratio; this
      changed its layout from vertical (icon over title) to the same
      horizontal ticket anatomy as everything else — a deliberate
      unification, not an oversight.
      Tests: `test/widget/vault/document_widgets_test.dart`.
- [x] Show-code screen: a custom `PageRouteBuilder` half-Y-axis flip
      (`_TicketFlipTransition` in `show_code_screen.dart`) replaces the
      default fullscreenDialog slide-up for `ShowCodeScreen.open()` — turning
      the ticket over to its barcode side. The screen's own content (plain
      white, max brightness, no dark mode) is untouched — gate-scanning
      contrast still wins over theming there, on purpose.
- **Fixed while here:** `test/widget/vault/vault_screen_test.dart`'s
  `_hasWarningBorder` helper depended on the old PaperCard
  hairline-border implementation detail (`Material.shape` /
  `RoundedRectangleBorder.side.color`) and would have false-failed against
  the new `TicketCard`s regardless of correctness. Renamed to
  `_hasWarningAccent` and rewritten to check `TicketCard.accentColor`.

## 7.4 Places/map — not started

- [ ] Two pin *shapes* (not just colors) for want-to-go vs. been-there
- [ ] Stats header using `AppTextStyles.statValue`

## 7.5 Expenses, settings, states, dark mode — not started

- [ ] Empty/error/loading states re-walked against the new primitives
- [ ] Full dark-mode pass on the new palette/elevation
