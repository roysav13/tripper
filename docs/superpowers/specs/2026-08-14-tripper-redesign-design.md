# Tripper visual + structural redesign — "Immersive Golden Hour"

**Status:** approved via visual brainstorming session, 2026-08-14. Ready for implementation planning.

## 1. What this is

A full redesign of Tripper's visual language and, where the old layout genuinely fights the new one, its screen structure. This explicitly supersedes CLAUDE.md's current hard rules 1 and 6 (color/component constraints) and SPEC.md §4 (Design system) — see §7 below for what replaces them. Rules 2–5 (no `DateTime.now()` in domain code, ARB/RTL-safe strings, local-first/offline policy, test discipline) are unaffected and remain absolute.

Decided through a visual brainstorming session (mockups in `.superpowers/brainstorm/579-1786716274/content/`, gitignored): three initial directions were shown (Elevated Field Journal, Immersive Golden Hour, Modern Minimal Travel); **Immersive Golden Hour** was chosen. Iterated through Trip Detail, Vault, Places/map, and a real-world check against actual map/globe screenshots, then tightened for hue discipline.

## 2. Direction

Cinematic, photo-forward, dark-first. Trip covers (real photos or generated gradient art) become the emotional anchor of the app instead of staying text/data-forward. Glass (blurred) chrome floats over photography for navigation; content below the fold stays on solid, calm dark surfaces. The existing "boarding pass" data discipline — mono metadata, hairline dividers, serif titles — survives underneath the new skin; this is a reskin with one added feature (cover photos), not a rebuilt information architecture.

## 3. Design tokens

### 3.1 Color — dark (primary)

| Token | Value | Use |
|---|---|---|
| `bg.night` | `#12141C` | App background |
| `surface` | `#1C1F2B` | Solid content cards (below-the-fold, non-glass) |
| `ink.primary` | `#F5F1EA` | Primary text |
| `ink.secondary` | `#A9AEBD` | Secondary text, timestamps |
| `ink.muted` | `#6E7386` | Placeholder, disabled |
| `hairline` | `rgba(255,255,255,.08)` | Borders on solid cards |
| `accent.coral` | `#FF6B5E` | The one accent — CTAs, active states, "want to go" pins/dots |
| `warning.amber` | `#F2A93C` | Expiry/danger-adjacent warnings only. Also reused for map labels — no separate "map gold" token |
| `success` | `#34D399` | Confirmations only |
| `error` | `#E5484D` | Real errors/validation only |
| `hero.gradient` | `#171A2E → #FF6B5E` (2-stop) | Cover scrims and generated trip-cover art only |
| `map.water` / `map.land` | `#17263c` / `#242f3e` | Map style base (see §5.3) |

### 3.2 Color — light (true alternate, not a mechanical inversion)

| Token | Value |
|---|---|
| `bg.paper` | `#FAF3EC` |
| `surface` | `#FFFFFF` |
| `ink.primary` | `#1B1A22` |
| `ink.secondary` | `#403F47` (adjusted from `#5B5A66` for WCAG AA — Task 1 fix, 2026-08-14) |
| `ink.muted` | `#56525D` (adjusted from `#8A8894` for WCAG AA — Task 1 fix, 2026-08-14) |
| `hairline` | `#E7E1D8` |
| `accent.coral` | `#A23F37` (adjusted from `#E85A4E` for WCAG AA — Task 1 fix, 2026-08-14) |
| `warning.amber` | `#8D5513` (adjusted from `#C97A1B` for WCAG AA — Task 1 fix, 2026-08-14) |
| `success` | `#1F9A6E` |
| `error` | `#C23B34` |
| `hero.gradient` | `#FAF3EC → #A23F37` (warm parchment→darkened coral, adjusted for WCAG AA — Task 1 fix, 2026-08-14) |
| `map.water` / `map.land` | `#DCEAE6` / `#EFE7D8` |

Net **named brand hues: three** (night, coral, amber) plus the two utility colors (success/error) every app needs — tightened down from an earlier draft that had 7-8 (a 3-stop indigo/violet/rust gradient and a separate map-gold were cut; the gradient's middle tones are now pure interpolation, not tracked tokens).

### 3.3 Typography

No new font assets — reuses the three already bundled (`Fraunces`, `IBM Plex Sans`, `IBM Plex Mono`), same 5-size/weight scale as today, roles unchanged:
- **Fraunces** — titles, trip names, hero headings
- **IBM Plex Sans** — body, buttons, UI labels
- **IBM Plex Mono**, uppercase-tracked — dates, codes, stats, kickers

### 3.4 Shape, elevation, motion

- Corner radius grows from the old "modest, no pills" rule to **14px on cards/sheets, full-pill on chips/tab indicators, circular on FABs/glass buttons** — a deliberate, explicit departure.
- Shadows are reintroduced, but **only on floating glass chrome** (tab bars, FABs, glass buttons sitting over photo/gradient). Solid content cards keep the old hairline-only discipline — no shadow.
- Hero cover photo uses a shared-element (Hero) transition from list card → detail screen — the app's one signature "peak moment," building on the Hero/haptics work already shipped in M4.

## 4. Component rules (replacing CLAUDE.md hard rule 1)

1. **One accent, not two.** Coral does all interactive/active/CTA work. Amber is reserved exclusively for expiry/danger-adjacent warnings — never reused as a second accent.
2. **Gradients are scoped, not banned.** Only on hero/cover-photo scrims and generated trip-cover art. Never on buttons, text backgrounds, or flat surfaces.
3. **Glass/blur is for chrome over imagery only** — nav bars, tab bars, top bars sitting on a photo or gradient hero. Regular content cards stay solid for reliable contrast and cheap repaint.
4. **Hairline borders survive** on solid cards, recolored (`rgba(255,255,255,.08)` dark / `#E7E1D8` light) — keeps the "printed, not app-y" feel under the new skin.
5. **Two pin/marker states, one accent** — coral+glow = want-to-go, muted parchment/grey = been-there. Applies identically to map pins and the journal globe's dots.
6. **Contrast is non-negotiable.** Every text-on-photo/gradient moment gets a scrim strong enough to hit WCAG AA — this replaces, rather than loosens, the old contrast discipline (recall the M4 audit that already tightened `inkMuted` twice for this reason).
7. **Icons** stay outline, single-weight, ink-colored by default; coral only for active nav/pin states — same rule as before, new tokens.

## 5. Screen-by-screen

- **Trips list**: cover-photo (or generated gradient) cards, serif trip name over a scrim, mono kicker (dates/day-count), coral circular FAB.
- **Trip detail**: full-bleed cover hero with scrim, glass topbar (back/overflow), floating glass tab bar (Documents/Places/Journal/Spend) bridging hero → content, solid dark cards below. "Show code" CTA in coral; expiry warnings in amber, visually distinct from the CTA.
- **Vault**: pinned quick-access row keeps its own gradient card treatment (gate-line recognition); everything else solid dark cards so the pinned row still stands out. Biometric lock icon unchanged position.
- **Places**: mono/serif stats header (countries/been/want counts in coral), map + list with the two pin states, glass filter chips on a bottom sheet.
- **Journal globe**: already close to this direction (dark satellite globe, glowing dot markers, floating photo cards) — keep the `flutter_earth_globe` engine as-is, recolor the dot/halo from teal to coral (see §5.4's note on `journal_globe.dart`), reskin only the surrounding chrome (top bar, bottom nav) so it stops feeling like a different app.
- **Expenses, Settings**: solid dark surfaces, same token set, no structural change — lowest-risk screens in the rollout.
- **Empty states**: keep sparse line-art per the original philosophy, on `surface`, optionally with a soft coral-tinted glow behind the icon; CTA button in coral. **Error/loading states**: same solid-surface treatment as regular cards, no glass.

## 6. Technical implications

- **New column**: `Trip.coverPhotoPath` (nullable TEXT) — Drift schema bump **with a migration test**, per CLAUDE.md hard rule 5. File stored via the existing app-private-storage pattern (`FileVaultService`'s approach), not a DB blob.
- **Photo picker**: `image_picker` (camera/gallery) for selecting a cover photo. No new dangerous permission beyond what the vault's file-attach flow already uses.
- **Generated-gradient fallback**: when `coverPhotoPath` is null, render `hero.gradient` with angle/tone varied by a deterministic hash of the trip's id — fully local, zero network, zero new asset weight, always available offline (consistent with SPEC §3.1.2/§3.1.3's offline policy).
- **Map styling** (`lib/features/places/presentation/map_style.dart`): replace `kMapStyleLight = null` with an authored light JSON (`map.water`/`map.land` light tokens) and retune `kMapStyleDark` from Google's generic "Night" style to the tightened dark tokens (reusing `warning.amber` for labels instead of Google's default gold). This explicitly **supersedes the 2026-07-23 "stock Google Maps look" decision** documented in that file's header comment — the comment needs rewriting alongside the style constants.
- **Custom markers**: replace default red teardrop `Marker`s with custom `BitmapDescriptor`s for the want/been states (coral+glow / muted parchment), matching the globe's dot language.
- **`journal_globe.dart`**: change the dot/halo color from the teal accent to coral. That file's existing comment ("Monochrome teal — CLAUDE.md's two-accents rule...") explicitly references the rule being replaced and needs updating, not just the color constant.
- **`AppColors`** (`lib/core/theme/app_colors.dart`): full token rewrite. Remains the one file allowed raw `Color(0xFF...)` values — new tokens include `heroGradientStart/End`, `mapWater`, `mapLand`, plus existing token names with new values.
- **RTL**: every changed/new widget must keep using `EdgeInsetsDirectional`/`start`/`end` and mirrored directional icons. This redesign must not regress the RTL work that just shipped (Hebrew RTL support, merged this session) — re-run existing RTL widget tests against every restyled screen, add new ones where layouts genuinely changed (e.g., the new glass tab bar).
- **Golden tests**: every existing golden test under `test/golden/` will need re-baselining once tokens/components change. Expected fallout from this work, not a regression — call it out explicitly in the implementation plan so it isn't mistaken for breakage.

## 7. Governance doc updates

Per the decision made during brainstorming: CLAUDE.md hard rules 1 and 6, and SPEC.md §4 (Design system), get rewritten to codify this system, replacing the teal/rust/paper rules with §3–§4 of this spec. This happens as the **first step of implementation** (design-system-foundation phase below), not immediately alongside this spec file, so the governance docs change together with the `AppColors` rewrite rather than describing a system that doesn't exist in code yet.

## 8. Rollout (for the implementation plan)

Given the surface area (every screen), implementation should be sequenced as its own set of milestones rather than one plan, following the project's existing M-numbered convention:

1. **Design-system foundation** — `AppColors` rewrite, shared primitives (glass-chrome widget, updated `PaperCard`/`SectionLabel`/`MonoText`), generated-cover-gradient helper, `Trip.coverPhotoPath` migration + test, CLAUDE.md/SPEC.md §4 rewrite.
2. **Trips + Vault** reskin, including the cover-photo picker UI and the hero shared-element transition.
3. **Places** — custom map styles + custom markers + stats header/list reskin.
4. **Journal (globe reskin) + Expenses + Settings** — lowest-risk batch, mostly token swaps.
5. **Cross-cutting polish** — empty/error/loading states, motion pass, RTL re-verification, golden-test re-baseline, accessibility contrast audit.

Exact milestone numbering is left to the implementation-planning step.

## 9. Explicitly out of scope

- Bottom navigation stays at 3 tabs (Trips/Vault/Places); Journal and Expenses remain nested under Trip detail — no IA change there.
- No change to Phase 2/3 feature scope (SPEC §3.2–§3.3) — this is visual/structural only.
- Dark-only mode was considered and rejected — light mode remains a fully-designed alternate, not dropped.
