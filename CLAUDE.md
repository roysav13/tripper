# Tripper — project context

Local-first Flutter Android app: trips + document vault + wishlist/visited places.
Read `docs/SPEC.md` first; current milestone status in `docs/plans/README.md`.

## Hard rules

1. No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`. Two accents total: teal (actions/wishlist), rust (warnings ONLY — never place states).
2. No `DateTime.now()` in domain code — inject via `clockProvider`.
3. Every user-facing string goes through ARB (`lib/l10n/app_en.arb`). English only, but RTL-safe layouts (`EdgeInsetsDirectional`, start/end) — Hebrew is a future translation pass.
4. Local data is always the source of truth (SPEC §3.1.3). Network calls may enhance a core flow (search, parsing, suggestions, background tracking) but may never gate access to data already on the device, and must degrade visibly and gracefully — never a hanging spinner or hard error — with a tested offline fallback. This replaces the old "network touches only map tiles and short-links" carve-out; the surviving rule is narrower but still absolute.
5. Tests land in the same commit as the feature. Every Drift schema bump ships a migration test. Widget tests mock at the repository boundary. Integration tests run with network disabled by default; a test that exercises an online path does so explicitly and mocks the network boundary rather than hitting a real endpoint.
6. Visual language: serif (Fraunces) for names/titles, mono (IBM Plex Mono, uppercase) for dates/codes/metadata, hairline borders instead of shadows, `PaperCard`/`SectionLabel`/`MonoText`/`EmptyState` primitives from `lib/core/widgets/`.

## Structure

Feature-first: `lib/features/<feature>/{data,domain,presentation}`; shared code in `lib/core/{theme,database,routing,widgets}`. Tests mirror in `test/{unit,widget,golden}/<feature>/`.

## Verification

I (Claude) cannot run Flutter in the Cowork sandbox — the SDK download is network-blocked. The verify loop is: user runs `flutter analyze && flutter test` locally (or pushes to GitHub, CI runs it) and reports results back. Never claim code is verified without one of those.
