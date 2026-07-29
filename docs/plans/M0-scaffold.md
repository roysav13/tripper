# M0 — Scaffold

**Goal:** an empty-but-structured app where `flutter analyze` and `flutter test` pass, the 3-tab shell runs on a device, Widgetbook renders the design tokens, and CI blocks broken changes.

**Exit criteria:** all checkboxes below done; app boots to a Trips empty state; Widgetbook shows tokens + one sample card; CI green on a fresh clone.

## 0.1 Project init

- [ ] `flutter create tripper --org dev.roysav --platforms android` (project lives at repo root)
- [ ] `android/app/build.gradle`: `minSdk 26` (Android 8+, covers ~97% of devices, allows modern APIs), `targetSdk` latest stable
- [ ] App name "Tripper", package `dev.roysav.tripper`
- [ ] `.gitignore` sanity check; `git init` + first commit

## 0.2 Dependencies (pubspec.yaml)

Runtime:

| Package | Purpose |
|---|---|
| `flutter_riverpod` + `riverpod_annotation` | state management |
| `drift` + `sqlite3_flutter_libs` | local DB |
| `path_provider` | app-private file paths |
| `go_router` | navigation |
| `intl` | date formatting |
| `uuid` | IDs for files/entities |

Dev:

| Package | Purpose |
|---|---|
| `drift_dev`, `build_runner`, `riverpod_generator` | codegen |
| `flutter_lints` (strict) or `very_good_analysis` | lint baseline |
| `alchemist` | golden tests with pinned fonts/DPR (less flaky than raw goldens) |

Deferred to their milestones: `file_picker`, `open_filex` (M2); `flutter_map`, `latlong2` (M3). Don't add them now — keeps M0/M1 builds fast and dependency review honest.

- [ ] Pin all versions (no `^` drift surprises mid-project); commit `pubspec.lock`

## 0.3 Theme — design tokens as code

Files under `lib/core/theme/`:

- [ ] `app_colors.dart` — the SPEC §4.2 palette as a `ThemeExtension<AppColors>` with `light` and `dark` instances (paper `#F7F4EE`/`#15181A`, ink `#1C2422`/`#EDEAE2`, hairline, teal `#2B6E6B`, rust `#B5562D` warnings-only, etc.)
- [ ] `app_typography.dart` — three families bundled as assets (no runtime font fetching, app must work offline): serif `Fraunces` (headings), sans `IBM Plex Sans` (body/UI), mono `IBM Plex Mono` (dates/codes). 5-size scale: display 28, title 22, body 15, label 13, caption 11
- [ ] `app_spacing.dart` — spacing scale (4/8/12/16/24/32), single corner radius token (10), hairline width (0.5)
- [ ] `app_theme.dart` — assembles `ThemeData` light + dark from the above; cards = hairline border, no elevation
- [ ] Download the three font families into `assets/fonts/`, declare in pubspec

Rule enforced from day one: **no raw `Color(0xFF...)` outside `app_colors.dart`** — add a lint note in `analysis_options.yaml` comments and check in code review.

## 0.3.1 Localization scaffold

- [ ] `flutter_localizations` + `intl` ARB setup (`lib/l10n/app_en.arb`); **no hardcoded user-facing strings anywhere** — every string through `AppLocalizations` from the first screen
- [ ] RTL-safety rule: only `EdgeInsetsDirectional`, `Alignment.centerStart`-style APIs; lint habit checked in review (Hebrew is a Phase 2 translation pass, not a rewrite)

## 0.4 Database scaffold

- [ ] `lib/core/database/app_database.dart` — Drift `@DriftDatabase` with schema version 1, no tables yet (tables land per-feature in M1–M3)
- [ ] Constructor takes a `QueryExecutor` so tests inject `NativeDatabase.memory()`
- [ ] `database_provider.dart` — Riverpod provider, opens DB in app documents dir

## 0.5 Routing + app shell

- [ ] `lib/core/routing/app_router.dart` — `go_router` with `StatefulShellRoute.indexedStack`, three branches: `/trips`, `/vault`, `/places`
- [ ] `lib/core/widgets/app_shell.dart` — bottom `NavigationBar`, 3 items (luggage / folder / map-pin icons), teal active state
- [ ] Placeholder screens per tab, each with a proper empty state (SPEC copy style: invitation, not apology — "Plan your first trip" + CTA)
- [ ] `main.dart` wires `ProviderScope` → theme → router

## 0.6 Shared primitives (minimum set)

`lib/core/widgets/`:

- [ ] `paper_card.dart` — white surface, hairline border, radius token (the universal card)
- [ ] `section_label.dart` — 11px letter-spaced uppercase gray label ("ACTIVE NOW", "PINNED")
- [ ] `empty_state.dart` — icon + serif headline + one-line body + CTA button
- [ ] `mono_text.dart` — convenience widget for mono-styled metadata rows

## 0.7 Widgetbook

- [ ] `widgetbook/` — separate Flutter package in the repo (own pubspec, path-depends on the app) so it never ships in the release APK
- [ ] Use cases: color tokens grid, typography scale, spacing, `PaperCard` states, `EmptyState`, `SectionLabel`
- [ ] Light/dark toggle + device frames addons
- [ ] `melos` or a simple `Makefile`/script for `run app` vs `run widgetbook`

## 0.8 Tests + CI

- [ ] `test/smoke_test.dart` — app builds and shows the shell with 3 destinations
- [ ] `test/golden/` — alchemist config: bundled fonts loaded, DPR pinned to 1.0, CI-vs-local golden variants
- [ ] Golden: `PaperCard` + `EmptyState` in light and dark
- [ ] `.github/workflows/ci.yaml`: on push/PR → `flutter pub get`, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` (goldens included), cache pub + gradle
- [ ] Optional local guard: `lefthook`/`husky`-style pre-commit running analyze + affected tests

## Watch out for

- Font licensing: Fraunces + IBM Plex are OFL — fine to bundle; keep license files in `assets/fonts/`
- Drift codegen must run before first analyze in CI (`dart run build_runner build --delete-conflicting-outputs` as a CI step)
- Widgetbook package must be excluded from app's `flutter analyze` scope or given its own CI job
