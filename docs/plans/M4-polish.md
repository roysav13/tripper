# M4 — Polish pass

**Goal:** the app feels finished: dark mode everywhere, every empty/error state designed, accessibility clean, visual consistency audited.

**Exit criteria:** design-system audit checklist clean; a11y checks pass; dark mode has zero hardcoded-color leaks; all goldens re-approved in both modes.

## 4.1 Dark mode sweep

- [x] Grep for `Color(0xFF` outside `app_colors.dart` — must be zero hits (verified 2026-07-24: zero hits)
- [ ] Walk every screen in Widgetbook dark mode; fix contrast leaks (map now ships its own stock Google Maps night style — `kMapStyleDark` in `map_style.dart` — as of 2026-07-23, so this is just a contrast check, not a new style decision) — needs a real device/emulator, unverified
- [x] System-follow by default + manual override in a minimal settings entry (`SettingsScreen` — light/dark/system `SegmentedButton`, `themeModeProvider`)

## 4.2 States audit

Per screen, verify all of: loading (skeleton, not spinner, for lists), empty (designed invitation + CTA), error (what happened + what to do, no raw exceptions), populated, overflowing (30+ trips, 100+ docs, 500+ places — scroll perf sanity)

- [x] Error states — `core/widgets/error_state.dart` added 2026-07-24; wired into Trips list, Vault, and Places (all three now show a designed error + retry instead of silently rendering an empty screen on a stream failure). Trip detail, Doc form, Place form, Places map not yet audited for error handling
- [x] Overflow/perf — stress tests added: 30+ trips, 100+ documents, 500+ places, each pumped + flung and checked for zero exceptions (`test/widget/{trips,vault,places}/*_screen_test.dart`)
- [ ] Loading states — still using default spinners in places, not the "skeleton, not spinner" treatment called for above. **Deprioritized 2026-07-23** — decided not worth blocking on, revisit only if it becomes a real complaint
- [ ] Trip detail · Doc form · Places map — not yet walked individually for empty/error/loading coverage. **Deprioritized 2026-07-23** — same call

## 4.3 Accessibility

- [x] Tap targets ≥48dp (check the small check-targets on wishlist rows and pinned grid) — covered by `androidTapTargetGuideline` in `test/widget/accessibility_test.dart`
- [x] Contrast: gray-on-paper combos (`#8C948F` on `#F7F4EE`) are decorative-only; anything informational ≥4.5:1 — bump to `ink.secondary` where needed — covered by `textContrastGuideline`
- [ ] Semantics labels on icon-only buttons; pin state announced ("want to go" / "visited") not just shape — `labeledTapTargetGuideline` only asserts labeled *tappable* controls, not that pin state specifically is announced; worth a targeted check
- [x] Text scaling to 1.3× without overflow on all cards (mono metadata rows are the risk) — `layout survives 1.3x text scaling without overflow` test
- [x] Run `flutter_accessibility` checks in widget tests (`meetsGuideline(androidTapTargetGuideline)` etc.) and keep them as permanent CI tests — `test/widget/accessibility_test.dart`, runs on every `flutter test`

## 4.4 Motion & feel

- [x] Row move animation (wishlist → visited) — 250ms ease-out fade+rise on the row landing in its new section (`RowSettleAnimation`, `place_widgets.dart`) + a 250ms cross-fade on the check icon itself. Not a true cross-list "flight" (want/been are separate subtrees; that would need `AnimatedList` or a package) — see 2026-07-24 note in the code
- [x] Hero the trip name list→detail; page transitions default Material fade-through — `Hero(tag: 'trip-name-${trip.id}')` in `TripCard` and `TripDetailScreen`'s AppBar title, both routes share the same shell-branch Navigator so no extra wiring needed
- [x] Haptic tick on mark-visited — `HapticFeedback.selectionClick()` in `places_screen.dart`, verified via a mocked platform-channel test

## 4.5 Backup — export & restore

- [x] `BackupService`: zip = `manifest.json` (format version, schema version, createdAt, file count) + SQLite snapshot (`VACUUM INTO` a temp copy) + `vault/` files. Shares via the system share sheet (`share_plus`) rather than SAF directly — user still picks the destination
- [x] `BackupService.import`: validates format/schema version → restores vault dir + swaps the DB file; refuses newer-format/newer-schema archives with a clear message (`BackupFailure` enum)
- [x] Entry points in settings: "Export backup" / "Restore from backup" (`SettingsScreen._export`/`_import`, restore confirms first — warns it replaces current data)
- [x] Tests: roundtrip export→import restores rows and files (`test/unit/backup/backup_service_test.dart`); corrupt-archive and newer-schema rejection paths covered
- [x] Reminder nudge: quiet in-app banner if data exists and no export was ever made (not a notification) — `_BackupReminderBanner` in `trip_list_screen.dart`, gated on `hasExportedProvider`; doc was stale, this was already built and tested

## 4.6 Release hygiene (deprioritized 2026-07-23 — not deciding Play vs sideload yet, revisit before an actual release)

- [ ] App icon + splash — running Flutter's stock default launcher icon (2026-07-23) after five custom-mark rounds were tried and rejected in turn: a suitcase glyph, a luggage-tag+T mark, a pin-drawn-as-T mark, a teal-field version of that pin-T mark, and an ink passport-stamp mark (benchmarked against 5 reference app icons the user supplied — Skyscanner, WhatsApp, Pinterest, Airalo, Discord — plus compass-star/route-ribbon/ticket-notch/bled-"t"/bled-trail alternates). Stock icon files were pulled from a fresh scaffold project and dropped into all 5 `mipmap-*/ic_launcher.png`; splash (`drawable{,-v21,-night}/launch_background.xml`) is plain `bg.paper`/`bg.paper_dark`, no glyph. Real logo design deferred — revisit later, not blocking
- [ ] If sideload: signed release APK script + `flutter build apk --release` doc — deprioritized, see above
- [ ] If Play: signing config, privacy policy (trivial — no data leaves device), listing assets — deprioritized, see above

---

# Testing & CI conventions (applies to every milestone)

## Layout

```
test/
  unit/<feature>/        pure Dart — bucketing, expiry, DAOs (in-memory sqlite)
  widget/<feature>/      screens/components with mocked repositories
  golden/<feature>/      alchemist, bundled fonts, DPR 1.0
integration_test/        device flows, one file per critical path
```

## Rules

0. **Offline is the default test condition** — integration tests run with network disabled; every network-touching path (map tiles, short-link resolve, places search, nearby POI, email/OCR parsing where applicable) gets an explicit offline-fallback test. A feature that spins or errors offline is a failed test.
1. **Tests land in the same PR/commit as the feature** — never "tests later"
2. Unit tests take an injected clock; no `DateTime.now()` in domain code, ever
3. DAO tests run on `NativeDatabase.memory()` — fast, no mocks of the DB itself
4. Widget tests mock at the **repository** boundary, not the DAO
5. Goldens only for design-system components and card variants — not whole screens (screens churn, cards are the contract)
6. Every schema bump ships a migration test in the same commit
7. No real network calls in any test — fake tile providers, mocked API clients for search/parsing/tracking; real network is never hit from the test suite
8. Flake policy: a test that flakes twice gets fixed or deleted the same week

## CI pipeline (GitHub Actions)

| Stage | Command | Blocks merge |
|---|---|---|
| Format | `dart format --set-exit-if-changed .` | yes |
| Codegen check | `build_runner build` + `git diff --exit-code` | yes |
| Analyze | `flutter analyze` | yes |
| Unit + widget + golden | `flutter test` | yes |
| Integration | `flutter test integration_test` on emulator (`reactivecircus/android-emulator-runner`) | yes, nightly + pre-release (too slow per-push) |

Local loop: `flutter run` on device/emulator for the app; `flutter run` in `widgetbook/` for component states; both stay open during dev.
