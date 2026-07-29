# M1 — Trips foundation

**Goal:** full trip lifecycle — create, view, edit, archive, delete — with auto-bucketing into upcoming/active/past. Everything else in the app hangs off this entity.

**Exit criteria:** create → see in list under correct bucket → open detail → edit → archive → delete, all covered by unit + widget tests; trip card golden approved; CI green.

## 1.1 Data layer (`lib/features/trips/data/`)

- [ ] Drift table `Trips`: `id` (text, uuid PK), `name`, `startDate`, `endDate` (date), `colorTag` (int enum index), `iconTag` (int), `archived` (bool, default false), `createdAt`
- [ ] Drift table `TripDestinations`: `id`, `tripId` (FK, cascade delete), `name`, `orderIndex` — ordered multi-destination support from day one; UI renders joined with "→"; form has a reorderable chip list (min 1 destination)
- [ ] Schema bump to v2 + migration test (Drift's `schema_test` tooling — start the migration-testing habit on the first real table)
- [ ] `TripsDao`: CRUD + `watchAll({bool includeArchived})` stream ordered by `startDate`
- [ ] `TripRepository`: wraps DAO, exposes domain models (no Drift types leak upward)

## 1.2 Domain (`lib/features/trips/domain/`)

- [ ] `Trip` model (freezed or plain immutable) + `TripStatus { upcoming, active, past }`
- [ ] `TripBucketer` — pure function `bucket(Trip, DateTime today)`: active if `today` in `[startDate, endDate]` inclusive, upcoming if before, past if after. **Clock injected**, never `DateTime.now()` inline (testability + midnight-rollover correctness)
- [ ] Validation rules: name non-empty, `endDate >= startDate`, max trip length sanity check (e.g. 365 days)

## 1.3 Presentation (`lib/features/trips/presentation/`)

Screens:

- [ ] `TripListScreen` — sections ACTIVE NOW / UPCOMING / PAST via `SectionLabel`; past trips on recessed paper cards (per mockup); serif trip names, mono date ranges (`16 JUL – 27 JUL` format via `intl`); "+ " action in header
- [ ] `TripFormScreen` — create/edit: name, destination, date-range picker (calendar-first, Skyscanner-style), color/icon tag picker (8 muted options from token palette)
- [ ] `TripDetailScreen` — header (serif name, mono dates, day-count), Documents/Places tabs as **shell only** (content lands in M2/M3), archive/delete in overflow menu with confirm dialog
- [ ] Active trip card shows "Day N of M" teal chip; doc/place counts wired later (stub 0)

Providers:

- [ ] `tripListProvider` — watches repository stream, maps to bucketed view-model
- [ ] `tripFormControllerProvider` — form state + save
- [ ] `clockProvider` — injectable `DateTime Function()`

Launch behavior:

- [ ] If exactly one trip is active today → app opens on that trip's detail (go_router redirect on cold start); back returns to the list. Otherwise → trips list. Unit-test the redirect decision (0 / 1 / 2 active trips — two active trips fall back to the list)

## 1.4 Tests

Unit (`test/unit/trips/`):

- [ ] `TripBucketer`: before/first-day/mid/last-day/after boundaries; timezone-naive date comparison (compare dates, not instants)
- [ ] Validation: empty name, inverted dates, same-day trip (valid)
- [ ] DAO against `NativeDatabase.memory()`: CRUD roundtrip, archived filtering, ordering
- [ ] Migration test v1→v2

Widget (`test/widget/trips/`):

- [ ] List: empty state renders CTA; 1 trip per bucket lands in right section; archived hidden
- [ ] Form: validation errors shown; save produces correct entity (mock repository)
- [ ] Detail: renders name/dates; archive flow fires confirm dialog

Golden (`test/golden/trips/`):

- [ ] `TripCard` — active (with chip) / upcoming / past variants, light + dark

## 1.5 Widgetbook additions

- [ ] `TripCard` all variants, `TripListScreen` with fixture data (0 / 1 / many trips), `TripFormScreen`

## Watch out for

- Date-only comparison: store as `DateTime` at midnight UTC or use Drift's date type consistently — mixing local/UTC here is the classic active-bucket-off-by-one bug
- The Hebrew locale question (you may want he-IL date formats later) — keep all date formatting behind one `TripDateFormatter` so locale is a one-file change
- Deleting a trip must define behavior for linked docs/places *now* (even though they don't exist yet): decision = unlink, never cascade-delete files
