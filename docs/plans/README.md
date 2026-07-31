# Tripper — implementation plans

Spec: [`../SPEC.md`](../SPEC.md)

| Milestone | Plan | Depends on | Status |
|---|---|---|---|
| M0 — Scaffold | [M0-scaffold.md](M0-scaffold.md) | — | verified green (fonts + Widgetbook still pending) |
| M1 — Trips foundation | [M1-trips.md](M1-trips.md) | M0 | verified on device (incl. optional dates, theme toggle) |
| M2 — Vault | [M2-vault.md](M2-vault.md) | M1 | core + lock + share target verified; show-code awaiting verify. Deferred: ML-Kit barcode extraction (optional) |
| M3 — Places | [M3-places.md](M3-places.md) | M1 | complete pending verify: lists/stats, map (`google_maps_flutter`, stock Google Maps look as of 2026-07-23, search-first add flow), edit/delete, Maps-link share-in, completion prompt. Deferred: persistent tile cache |
| M4 — Polish | [M4-polish.md](M4-polish.md) | M1–M3 | closed out 2026-07-23. Done: dark-mode audit, a11y guideline tests (permanent CI), backup export/import + reminder banner, states audit (error states + overflow tests), motion & feel (Hero, haptics, row animation). Deliberately deprioritized rather than done: loading-state "skeleton" treatment, per-screen empty/error/loading walkthrough for Trip detail/Doc form/Places map, release hygiene (Play vs sideload, custom app icon — currently the stock Flutter icon) |
| M5 — Phase 2a quick wins | [M5-phase2a.md](M5-phase2a.md) | M1–M4 | in progress (2026-07-23). Done: 5.1 notifications subsystem, 5.2 expiry + trip-countdown reminders, 5.3 check-in reminders. **5.4 OCR paused mid-flight** — passport MRZ prefill works on-device, non-passport (flight/hotel) extraction is unreliable; see the status note in the plan before resuming. Also done: 5.5 expenses (multi-currency, stored conversion), 5.6 days-traveled stat. **5.7 itinerary builder withdrawn 2026-07-26 — "currently won't do"**: built, redesigned per [ADR-001](../adr/ADR-001-itinerary-redesign.md), then removed; only the dormant v9 `ItineraryItems` table and its migration test remain. Remaining: journal entries, arrival card, cost-guarded nearby POI, spike-gated email parsing, deep-links, PDF export, Hebrew/RTL |
| M7 — "Wallet & Ticket" restyle | [M7-restyle.md](M7-restyle.md) | M1–M4 | in progress (2026-07-30). Supersedes the original SPEC §4 design direction (kept inline as history). Done: §7.1 design tokens/primitives, §7.2 trips list+detail, §7.3 vault/documents (per-category `TicketCard` anatomy, show-code flip transition). Trip-stack fan/drag interaction explicitly descoped, see §7.2. Not started: places/map, expenses/settings/dark-mode passes. Unverified — see CLAUDE.md verification note. |

M2 and M3 were independent of each other and could be built in either order after M1. Testing/CI conventions shared by all milestones live at the bottom of M4-polish.md. Live GPS tracking (SPEC §3.2.2) is its own later milestone (M6) — battery-critical, deliberately isolated, not started. M7's number is unrelated/non-sequential — it was assigned after M6 was already reserved for GPS tracking.

Update the Status column as milestones progress; tick checkboxes inside each plan as tasks complete.
