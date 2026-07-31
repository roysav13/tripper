# Tripper — product spec & build plan

**Platform:** Android (Flutter, cross-platform-ready)
**Storage model:** Local-first, offline by default, no account required
**Design direction:** Classic, low-color, information-dense, "field journal / boarding pass" aesthetic

---

## 1. What this app is

Tripper is a personal trip companion. It replaces three things travelers currently juggle across separate apps and screenshots: a place to build and hold a trip, a safe place for the documents that trip needs, and a running record of where you want to go and where you've already been.

**Core loop:** create a trip → attach the documents it needs → plan/track places inside it → mark the trip done → those places roll into your permanent visited map.

### What it is *not* (v1)
Not a booking engine (no flight/hotel search), not a social network, not a group-collaboration tool. Those are explicitly deferred — see §3.2. Booking.com/Omio/Skyscanner are referenced for *how they structure trip and reservation data*, not because Tripper resells inventory.

## 2. Reference sweep — what to borrow

| App | What it does well | What Tripper borrows |
|---|---|---|
| [Wanderlog](https://wanderlog.com/) | Single trip = itinerary + map + docs + budget in one object; forwards confirmation emails into structured reservations; offline by default | The "trip as a container object" model; treating a trip as the top-level entity everything else hangs off |
| [Citymapper](https://citymapper.com/) | Extremely information-dense screens that never feel cluttered; strong use of typographic hierarchy over color to separate data | The visual language — hairline dividers, type weight instead of color-coding, dense but scannable lists |
| [Omio](https://www.omio.com/) | Reservation cards with a consistent anatomy (carrier, times, confirmation code, status) regardless of transport type | The document/reservation card pattern used in the vault |
| [Booking.com](https://www.booking.com/) | Saved-places and wishlist UX; strong "you've been here" affirmation patterns | The visited/wishlist toggle and map pin states |
| [Skyscanner](https://www.skyscanner.co.il/) | Clean empty states, calendar-first trip framing | Empty-state and date-range picker patterns |
| [Polarsteps](https://www.polarsteps.com/) | Automatic GPS trip tracking, chronological photo/text journal entries ("steps"), trip stats (distance, days, countries) | The battery-conscious background-tracking design and the journal-entry-as-timeline pattern — see §3.2.2 and §3.2.1 |

## 3. Feature set

### 3.1 MVP — Phase 1 (build first)

**A. Trips (foundation — required for the other two to exist)**
- Create a trip: name, destination(s), start/end date, cover color/icon (no photo upload needed for v1 — keeps it text/data-forward per the design direction)
- Trip list screen: upcoming, active (today falls in range), past — auto-bucketed, no manual status field
- Trip detail screen: tabs or sections for Documents and Places, plus a lightweight day-range display (full itinerary/day-planner is Phase 2, not Phase 1)
- Archive/delete a trip

**B. Document vault** *(your top priority)*
- Attach files to a specific trip: PDFs, images, or manually-entered records (flight number, confirmation code, dates)
- Categories: Passport/ID, Visa, Flight, Hotel/Stay, Insurance, Transport ticket, Other — each category has its own card layout (mirrors Omio's reservation-card pattern) so a flight looks different from a passport scan at a glance
- A **global vault** view independent of any trip, for documents that outlive a single trip (passport, driver's license, insurance card, vaccination record) — these can be linked into multiple trips without duplicating the file
- Quick-access / pinned documents for airport-gate situations — must open in under two taps from app launch. Pinned cards stay light (paper/surface base, no inverted dark blocks) — *"teal accents" revised M7*: each pinned card now carries its document category's identity color (`documentCategoryAccent`, §4.2) on a compact `TicketCard` stub, the same mechanism every other document card uses, rather than a single teal border. The "stays light, never inverts to a dark block" constraint itself is unchanged.
- Everything stored on-device; files live in app-private storage, DB only stores metadata + file path
- Expiry tracking: passport/visa expiry date surfaces a warning if it expires before or shortly after a trip's end date
- **Android share target**: share a PDF/image from Gmail or any app → Tripper opens a "save to vault" sheet (pick trip + category). The friction-killer for getting documents in.
- **"Show code" mode**: boarding passes and tickets with a QR/barcode get a full-screen, max-brightness code view — one tap from the pinned card, built for the gate line
- **Biometric lock on the vault**: fingerprint/face gate (via `local_auth`) when opening the Vault tab or any document; trips and places stay instantly accessible

**C. Wishlist & visited-places map** *(your other top priority)*
- Two states per place: **Want to go** (teal, active, sorted first) and **Been there** (gray, receded, pushed to the bottom of lists) — wishlist carries all the color; visited is a quiet archive
- A place can be free-standing (not tied to any trip) or linked to a trip — completing a trip offers to bulk-move its linked "want to go" places to "been there"
- Single map view with two pin styles (not two colors — see design system for why) for wishlist vs. visited
- List view alternative to the map, groupable by country/city
- Manual place entry (name + location) for v1; no places-search API integration yet (see Phase 2)
- **Share a Google Maps link into Tripper** → parsed into a wishlist place (same share-target mechanism as the vault)
- **Lightweight stats header** on the Places tab: countries count, places visited count, all-time map — the trophy-case payoff (queries over existing data, no new entities)

### 3.1.1 Cross-cutting MVP decisions
- **Launch behavior**: if a trip is active today, the app opens directly to that trip's detail (the list is a hallway during travel); otherwise opens to the trips list
- **Localization**: English-only strings, but all copy in ARB files and layouts RTL-safe from day one — Hebrew becomes a translation pass, not a rewrite
- **No notifications in MVP** — expiry warnings are in-app only; local notifications move to Phase 2
- **Backup/export in MVP (M4)**: manual "export everything" → single zip (DB snapshot + vault files + manifest version), saved via system file picker; matching import/restore flow. Local-first means uninstall = data loss — this is the insurance policy until Phase 3 cloud sync

### 3.1.2 Offline policy

The app must be fully usable with no connection — airplane mode is the primary use case, not an edge case. Rule: **no core flow may ever block on the network**, and anything that degrades must degrade visibly and gracefully, never with a spinner or error dialog.

| Capability | Offline behavior |
|---|---|
| Trips: create/view/edit, buckets, launch-to-active | Fully offline (pure local DB) |
| Vault: view/add docs, pinned quick access, show-code screen, biometric lock, expiry warnings | Fully offline — non-negotiable; this is the airport-with-no-wifi feature |
| Share target (PDF from Gmail, already-downloaded files) | Fully offline |
| Places: list, add manually, mark visited, stats | Fully offline |
| Map view | Pins always render; tiles come from cache when offline. Uncached areas show a flat paper-tone canvas with pins + a quiet "map unavailable offline" chip — pins and interactions still work. Tiles for a trip's bounding area are pre-cached when the trip is viewed online |
| Google Maps short-link resolve (share-in) | Needs network for `goo.gl` short links only. Offline: place saved with name from link text, link kept in notes, flagged "locate later" — full URLs with embedded coords parse offline |
| Place search in the map picker (Nominatim, accept-language=en) | Needs network. Offline: clear message + long-press drop-pin still works. Tiles: Esri World Street Map (English/Latin labels), keyless with attribution |

Testing consequence: every network-touching code path (search, parsing, nearby suggestions, tile/short-link resolution) ships a tested offline-fallback path in the same commit; integration tests default to network disabled unless a test is explicitly exercising the online path.

### 3.1.3 Network policy (revised ground rule)

Network access is now allowed wherever it makes the app materially better — this is no longer restricted to map tiles and Maps short-link resolve (the original carve-out above). What survives, non-negotiable, is narrower but still absolute:

- **Local data is always the source of truth.** Trips, documents, places, journal entries, expenses — everything already on the device stays fully viewable and editable with zero connectivity, no exceptions.
- **No core flow may be permanently blocked by a missing connection.** Network calls *enhance* input (search, parsing, suggestions) — they never gate access to data the app already has.
- **Every network-touching feature degrades visibly and gracefully**, never with a spinner that hangs or a hard error dialog — same rule as the old §3.1.2, just applied to a wider set of features now.
- **Every network path ships a tested offline-fallback path in the same commit** (extends CLAUDE.md hard rule 5).

See §3.2 for the features this unlocks.

### 3.2 Phase 2 — network-enhanced features (after MVP is solid and tested)

Split into two waves by risk and dependency. 2a items are low-risk, no new dangerous permissions, and mostly independent of each other. 2b is one deliberately isolated milestone (live GPS tracking) because it's the one feature on this list that can visibly hurt the user's experience — draining battery — if built carelessly.

#### 3.2.1 Phase 2a — quick wins & network-enhanced input

- **Budget/expense tracking per trip** — new `Expense(id, tripId, amount, currency, category, date, notes)`. v1 is single-currency per trip, no live conversion; running total + category breakdown on trip detail, mono numerals per the existing metadata convention. Fully local, no dependencies on anything else here.
- **Check-in-opens reminders** — local notification computed from a flight `Document`'s stored departure time minus a fixed 24h offset. Real airlines vary this window (24-48h); v1 uses one honest fixed offset rather than fake precision, and says so in the UI copy.
- **Local notifications** (existing Phase 2 item, now grouped with the above): document-expiry warnings, trip-countdown nudges ("starts in 3 days — 2 documents missing"), check-in-opens — one scheduling subsystem, three trigger types.
- **OCR on document photos** — `google_mlkit_text_recognition`, on-device, same package family as M2's existing `google_mlkit_barcode_scanning` (M2.4.2). Extracts text from passport/visa/ticket photos to prefill `DocumentFormSheet`. Passport MRZ (the fixed-format machine-readable zone) parsing specifically is high-accuracy and worth building first within this item. Writes into the existing `Document.details` JSON — no schema change. Zero network, zero cost.
- **Flight/hotel email parsing** — spike-gated, unpaid. Reuses the existing `ACTION_SEND` share-target handler (M2.4.1) for shared email text/HTML; regex/heuristic extraction (PNR codes, flight numbers, dates) writes into `Document.details`, always surfaced as "review before saving," never silent auto-fill. **Gate:** before scoping real build time, run a manual accuracy spike against 5-6 real confirmation emails. Below ~50% field-catch rate, shelve this rather than reach for a paid parsing service.
- ~~Places search & autocomplete~~ — **already shipped**, not Phase 2a work. `google_places_test.dart`/`google_places_client_test.dart`/`geocoding_test.dart` cover autocomplete, place details, and reverse geocoding; `add_place_screen_test.dart` covers the debounced search → prefilled card flow and the offline drop-pin fallback. Kept here only as the dependency note for the item below.
- **Nearby POI / restaurants / sights — configurable, cost-guarded.** Same API family as the already-shipped places search, deliberately gated against runaway cost: **off by default** via a settings toggle; pull-based only (a "Find nearby" button — never a background refresh, never refetching on map pan); results cached per-location for roughly an hour; an in-app call counter in settings so usage is visible before a surprise bill arrives. Saved results become a normal `Place` through the existing M3 wishlist flow — no new persisted entity needed for the suggestions themselves.
- ~~**Day-by-day itinerary builder**~~ — **built twice, withdrawn 2026-07-26, currently won't do.** A manual builder (M5.7) and then a derived timeline ([ADR-001](adr/ADR-001-itinerary-redesign.md)) both shipped and both failed to become something worth opening. The Plan tab was removed; the `ItineraryItems` table survives dormant at schema v9 so no device needs a destructive migration. Still worth reading the ADR before any third attempt — the open question is whether trip planning belongs in a documents-and-money app at all. The tense argument against merging it with Journal entries below (forward-planning vs. backward-recording) stands regardless.
- **Journal entries / timeline** — new `JournalEntry(id, tripId, placeId nullable, timestamp, text, createdAt)` plus a photo join table mirroring `FileVaultService`'s existing file-storage pattern. Fully local, fully offline, zero cost on its own. Meaningfully upgrades once Phase 2b's GPS tracking ships (auto-suggests a location from the nearest route point instead of requiring a manual link) but doesn't require it to ship — build it standalone.
- **Days-traveled stat** — trivial, derived from `Trip.startDate`/`endDate`, slots into the existing Places-tab stats header (M3.3.2) as a pure query, same pattern as countries-visited.
- **Arrival info card** — one screen with the immigration-form answers (first night's address, flight number, return date) pulled from the trip's linked documents.
- **Hebrew localization + full RTL pass.**
- **Transport/booking deep-links** (Omio/Skyscanner-style outbound links, not in-app booking).
- **Trip sharing/export** — PDF export via the OS share sheet. Kept deliberately static/one-shot, not live: Polarsteps' own usage pattern shows travelers use "share a link" as a low-friction alternative to messaging, not a request for real-time tracking, and a genuinely live share link would need *some* hosted backend anyway — that's a Phase 3 concern (see below), not this one.

#### 3.2.2 Phase 2b — live GPS route tracking (own milestone: new permission, new background service, battery-critical)

The biggest lift in Phase 2, isolated deliberately because it's the one feature here that visibly hurts the user if built carelessly. Design constraints are written down explicitly rather than left as "should be fine."

**Data model:** new table `RoutePoint(id, tripId, lat, lng, timestamp, accuracy)`. High write volume on a multi-day trip — buffer points in memory and batch-insert every N points or M minutes rather than one DB write per fix. Line-simplification (Douglas-Peucker) happens at render time, never at storage time, so raw data is never discarded.

**Permissions & UX:** requires `ACCESS_BACKGROUND_LOCATION` — one of Android's most sensitive permission prompts. Tracking is **off by default**, started and stopped explicitly per trip via a clear "Start tracking" / "Stop tracking" action on the trip screen — never silently always-on, and never auto-resumes for a new trip without the user re-enabling it. Runs as a foreground service with a persistent, low-priority notification while active (an Android requirement for background location anyway) — this also keeps the tracking state visible at all times, so the user can stop it on sight instead of discovering a drained battery hours later.

**Battery policy — the actual anti-battery-drain design, not just a hope:**
- *Motion-aware sampling*: use Android's ActivityRecognition API (free, part of Google Play Services) to detect still / walking / driving. Once "still" for more than ~5 minutes, drop continuous GPS polling entirely and fall back to significant-location-change wake-ups only — this is where most of the battery savings come from, since a stationary phone (hotel room, train seat, asleep) has no reason to keep polling.
- *Distance + time filters*: only take a new fix when the device has moved more than ~50-100m **or** ~5 minutes have elapsed, whichever comes first — never continuous high-frequency polling.
- *Balanced accuracy by default*: request medium/balanced-power location accuracy, not the highest GPS-only tier — this is travel-pace journaling, not turn-by-turn navigation, so the extra precision isn't worth the extra power draw.
- *Auto-pause on prolonged stillness*: after ~30-60 minutes with no movement, drop to the lowest-power significant-location-change mode until movement resumes.
- *Forgotten-trip safeguard*: if a trip's end date has passed and tracking is still active, detect this on next app foreground and prompt "trip ended — stop tracking?" instead of silently draining battery on a trip that's already over.
- *Explicit target, not a vibe*: background tracking should cost roughly **3-5% battery per day** of active use — matching the published bar competitors cite — written here as a real, checkable exit criterion for this milestone.

**Testing consequence:** battery drain can't be meaningfully unit-tested, so this milestone's exit criteria must include a manual on-device drain test (run tracking for a real 24h period, record the battery percentage drop) as a named, checked-off verification step before the milestone is considered done — consistent with the project's existing "Claude can't run Flutter locally, user verifies on device" workflow (see §Verification).

**Downstream unlocks once this ships:**
- Distance-traveled stat becomes real — sum of haversine distance between consecutive `RoutePoint` rows. Without this milestone, "distance traveled" has no genuine data source and shouldn't be built as a separate line item.
- Journal entries (2a) upgrade from manual place-linking to auto-suggested location.
- Route renders as a polyline on the existing Places map (M3.2), toggleable layer, additive to the existing pins — never replaces them.

### 3.3 Phase 3 (only if Phase 1–2 prove out and you want multi-device)
- Optional account + cloud sync/backup (the local-first model means this is additive, never required)
- Collaboration (shared trips, Wanderlog-style)
- Live/real-time trip sharing — deferred here specifically because it needs a hosted backend; static PDF export (§3.2.1) remains the answer until an account/sync layer exists

## 4. Design system

### 4.1 Direction

**"Wallet & Ticket"** (M7 restyle, 2026-07 — supersedes the original field-journal/boarding-pass read below). The core metaphor sharpened: instead of *evoking* a boarding pass through typography and hairlines alone, a trip, document, or reservation now renders as an actual physical travel object — a ticket, a boarding pass, a luggage tag — complete with a die-cut silhouette (perforated tear-seam, notched edges) and a colored stub. Color stopped being purely restrained: each trip carries an identity color from an 8-hue palette, applied consistently everywhere that trip appears (its cards, its header, its map pins), while warnings/errors/confirmations keep their own reserved colors so identity color is never mistaken for system meaning. Density still comes from layout and type hierarchy (Citymapper's approach, kept from the original direction) — the change is that hierarchy now has more room to be dramatic (a real hero moment per screen) instead of being flattened to a handful of sizes.

*Original direction, kept for history:* "Classic, not much color, full of information, great UX" — a field-journal/boarding-pass aesthetic of warm paper, near-black ink, one restrained teal accent, typography doing color's job. M0–M5 were built to this. M7 keeps the warm paper/ink base and the typographic discipline; it deliberately drops the single-accent and hairline-only rules.

### 4.2 Color tokens

Two tiers, defined in `lib/core/theme/app_colors.dart` (`AppColors`):

**Neutrals + semantic (unchanged from M0–M5):**

| Token | Value (light) | Use |
|---|---|---|
| `paper` | `#F7F4EE` | App background — warm off-white, not pure white |
| `surface` | `#FFFFFF` | Cards, sheets |
| `inkPrimary` | `#1C2422` | Primary text — near-black, slightly warm |
| `inkSecondary` | `#5B6462` | Secondary text, timestamps, metadata |
| `inkMuted` | `#666D68` | Placeholder text, disabled state (WCAG-AA-fixed post-M4 audit) |
| `hairline` | `#DEDACD` | Simple dividers only now (see §4.4) |
| `accent` | `#2B6E6B` | Deep teal — the default/neutral action color: primary buttons, the "want to go" wishlist state, anything not tied to one trip's identity |
| `warning` | `#B5562D` | Rust — warnings only (document expiry). Never a trip identity color. |
| `error` | `#A23B2E` | Real errors/validation only |
| `success` | `#3F7A52` | Confirmations only |

Dark mode is a considered inversion, not a naive one (paper → `#1B1F21`, ink → `#EDEAE2`, etc.) — see `AppColors.dark`.

**`tripPalette` — 8 "stamp ink" hues for identity (new in M7):**

| # | Name | Light | Dark | Notes |
|---|---|---|---|---|
| 0 | Harbor teal | `#2B6E6B` | `#5AA6A2` | The sea; default trip color, same hue as the old single accent |
| 1 | Marigold | `#E0B24A` | `#E8BE63` | Deliberately the one pale hue — its `onColor()` resolves to ink text, not white |
| 2 | Berry | `#A63D63` | `#C97A97` | Warm but pinker/cooler than `warning`/`error`'s rust, so a trip tag never reads as an alert |
| 3 | Indigo | `#3E5490` | `#8098D4` | Night flights |
| 4 | Moss | `#5B7A3A` | `#8FAE68` | Olive-green, kept distinct from `success`'s blue-green |
| 5 | Plum | `#6B4E8E` | `#A587C4` | Dusk |
| 6 | Cobalt | `#2E6E9E` | `#6BA3CC` | Deep water, more blue than harbor teal |
| 7 | Slate | `#52677A` | `#8CA0B2` | Overcast coastal town |

`Trip.colorTag` (already existed as a stored `int`, previously unused visually) indexes into this list mod its length, via `AppColors.tripAccent(colorTag)` — safe against any stored value. **Rule: append, never reorder or resize** — the index is persisted, so changing position 3's meaning silently re-colors every saved trip. `AppColors.onColor(background)` picks legible ink-or-surface text/icon color for whichever hue lands on a stub.

Document vault cards use the same mechanism per category (passport, visa, flight, hotel, insurance, transport, other) rather than per trip — see M7.3.

### 4.3 Typography

Three families (unchanged), now **7 sizes instead of 5** — the old scale read flat on a screen's one hero moment (`lib/core/theme/app_typography.dart`, `AppTypeScale`/`AppTextStyles`):

- **Headings:** Fraunces (serif) — `hero` (40, one per screen: a trip's name on its own detail header, a landing empty state) sits above the original `display`/`title`
- **Body/UI:** IBM Plex Sans — `body`/`label`/`sectionLabel`, unchanged
- **Data/codes:** IBM Plex Mono — `mono` (unchanged, dates/codes/coordinates) plus the new `statValue` (34, tabular figures) for the big number in a stats tile (countries visited, days traveled) — this is what makes M3.3.2's stats header feel like a payoff instead of another data row
- Weight (regular/medium/semibold) still carries hierarchy more than size alone, but size now has more range to work with on hero moments specifically — not license to add a size per screen

### 4.4 Component principles

- **Cards separate with soft elevation, not a flat hairline border** (`AppElevation` tokens — reversed from the original M0–M5 rule). Hairlines remain for simple row dividers and the tab bar rule only.
- **`TicketCard`** (`lib/core/widgets/ticket_card.dart`) is the primitive for anything that represents a real travel object: a colored stub (trip/category identity color) separated from the body by a perforated tear-seam, with semicircular notches bitten out of the long edges at that seam — cut via `TicketNotchClipper` and elevated with `PhysicalShape` so the shadow correctly follows the concave notch, not a box around them. The seam position reads `Directionality.of(context)` so it's on the correct physical edge in RTL.
- **`PaperCard`** remains for anything that *isn't* a travel object — plain list rows, forms, settings tiles — now drawn with shadow instead of a border, but no ticket geometry.
- Icons: outline style only, single weight; ink-colored except on a `TicketCard` stub (where they resolve via `onColor` against that stub's identity color) or the two pin/document states.
- No gradients. Corner radius is a design token (`AppShape.radius` for plain surfaces, `AppShape.ticketRadius`/`ticketNotchRadius` for tickets), not per-component guessing.
- Empty states are illustrated sparingly with line art, not stock photography — kept from the original direction; still true even with more color elsewhere.

## 5. Technical architecture

**Stack:** Flutter (Dart) — cross-platform-capable later, but Android-only target for now per your workspace setup.

| Layer | Choice | Why |
|---|---|---|
| State management | Riverpod | Testable, no BuildContext coupling, scales cleanly past MVP |
| Local database | Drift (SQLite) | Most actively maintained relational option for Flutter in 2026; Hive/Isar are effectively legacy/unmaintained now — Drift is the safe long-term bet for structured trip/document/place data |
| File storage | `path_provider` + app-private directory; `flutter_secure_storage` for any sensitive tokens (not the files themselves — SQLite metadata + sandboxed file storage is sufficient, OS-level app sandboxing already protects them) |
| Navigation | `go_router` | Declarative, deep-link-ready for Phase 2 sharing |
| Maps | `flutter_map` (OSM-based, no API key/billing needed for MVP) rather than Google Maps SDK — keeps v1 fully offline-capable and free; revisit if Phase 2 wants places search |
| Forms/validation | `flutter_form_builder` or hand-rolled with Riverpod — decide once first form (trip creation) is built |

### 5.1 Project structure (feature-first)

```
lib/
  core/
    theme/            # color tokens, text theme, spacing — the design system as code
    database/         # Drift schema, DAOs, migrations
    routing/          # go_router config
    widgets/          # shared primitives (cards, buttons, empty states)
  features/
    trips/
      data/           # repositories, Drift table access
      domain/         # models, use-cases
      presentation/   # screens, widgets, providers
    vault/
      data/ domain/ presentation/
    places/
      data/ domain/ presentation/
  main.dart
test/
  unit/               # mirrors lib/ structure
  widget/
  golden/
integration_test/
widgetbook/            # standalone Widgetbook app — see §6
```

Rationale: each feature owns its full stack (data → domain → presentation), `core/` holds only what's genuinely shared. This keeps trips/vault/places independently testable and lets Phase 2 features slot in without touching MVP code.

### 5.2 Data model (v1 sketch)

- `Trip(id, name, startDate, endDate, colorTag, archived)`
- `TripDestination(id, tripId, name, orderIndex)` — ordered list; a trip is Krabi → Ko Pha-ngan → Bangkok, not one string. Enables per-destination 