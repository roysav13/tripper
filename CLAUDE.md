# Tripper — project context

Local-first Flutter Android app: trips + document vault + wishlist/visited places.
Read `docs/SPEC.md` first; current milestone status in `docs/plans/README.md`.

## Hard rules

1. No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`. As of M7 ("Wallet & Ticket" restyle) this is no longer a two-accent rule: `AppColors.tripPalette` holds 8 saturated hues for trip/document identity (`Trip.colorTag` indexes into it), kept strictly separate from the semantic colors (`warning` = rust, `error`, `success`), which retain their old one-meaning-only jobs — a trip's color must never collide with or be mistaken for a warning/error.
2. No `DateTime.now()` in domain code — inject via `clockProvider`.
3. Every user-facing string goes through ARB (`lib/l10n/app_en.arb`). English only, but RTL-safe layouts (`EdgeInsetsDirectional`, start/end) — Hebrew is a future translation pass. `TicketCard`'s notch/seam geometry reads `Directionality.of(context)` directly rather than assuming LTR — any new geometry-drawing primitive must do the same.
4. Local data is always the source of truth (SPEC §3.1.3). Network calls may enhance a core flow (search, parsing, suggestions, background tracking) but may never gate access to data already on the device, and must degrade visibly and gracefully — never a hanging spinner or hard error — with a tested offline fallback. This replaces the old "network touches only map tiles and short-links" carve-out; the surviving rule is narrower but still absolute.
5. Tests land in the same commit as the feature. Every Drift schema bump ships a migration test. Widget tests mock at the repository boundary. Integration tests run with network disabled by default; a test that exercises an online path does so explicitly and mocks the network boundary rather than hitting a real endpoint.
6. Visual language ("Wallet & Ticket," M7): every trip/document/reservation is a physical travel object, not a generic Material card. Serif (Fraunces) for names/titles — now spanning 7 sizes including `AppTextStyles.hero` for a screen's one hero moment, not flattened to 5 — and mono (IBM Plex Mono, uppercase) for dates/codes/metadata, including the large tabular-figure `AppTextStyles.statValue` for stat tiles. Cards separate from the page with soft elevation (`AppElevation`), not a flat hairline border — hairlines remain for simple dividers only. `TicketCard` (perforated tear-seam + notch die-cut, per-trip/category color on the stub) is the primitive for anything that represents a real travel object; `PaperCard`/`SectionLabel`/`MonoText`/`EmptyState`/`ErrorState` from `lib/core/widgets/` remain for plain rows, forms, and settings tiles that shouldn't carry the ticket shape. Full rationale and token definitions: SPEC §4.

## Structure

Feature-first: `lib/features/<feature>/{data,domain,presentation}`; shared code in `lib/core/{theme,database,routing,widgets}`. Tests mirror in `test/{unit,widget,golden}/<feature>/`.

## Verification

I (Claude) cannot run Flutter in the Cowork sandbox — the SDK download is network-blocked. The verify loop is: user runs `flutter analyze && flutter test` locally (or pushes to GitHub, CI runs it) and reports results back. Never claim code is verified without one of those.
