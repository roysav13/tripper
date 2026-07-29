# ADR-001: Itinerary ("Plan") — from blank-form builder to derived timeline

**Status:** **Withdrawn — currently won't do (2026-07-26).** Implemented as Option C on
2026-07-23, reverted three days later. The analysis below is kept intact because it is
still the best description of the problem; only the verdict changed.
**Date:** 2026-07-23 (decided) · 2026-07-26 (withdrawn)
**Deciders:** Roy (sole maintainer)
**Supersedes:** the M5.7 design in `docs/plans/M5-phase2a.md` §5.7

---

## Withdrawal note (2026-07-26)

Both designs were built and both were used, and neither earned its place: the manual
builder was tedious, and the derived timeline — which fixed the tedium — still didn't
turn out to be something worth opening. That's a signal about the feature, not about
either implementation, so the whole Plan tab came out rather than a third variant going
in. Marked **currently won't do**; may return.

**What was removed:** the Plan tab from the trip detail screen (now three tabs:
Documents, Places, Spend), everything under `lib/features/itinerary/` except the table
definition, all itinerary tests except the migration test, every `itinerary*` ARB
string, and `HiddenAnchorsController` from `settings_service.dart`.

**What deliberately stayed:**

- **The `ItineraryItems` table and schema v9.** Dropping it would be a destructive
  migration on a device that already runs v9, to buy nothing. It is registered in
  `AppDatabase` with no DAO and no reader. `itinerary_migration_test.dart` and the
  schema assertion in `trips_dao_test.dart` still cover it, which is what stops a
  dormant table from quietly rotting. Removing it later needs a v10 migration and its
  own migration test.
- **The `itinerary_hidden_anchors` prefs key** on devices that have one — orphaned,
  harmless, and useful again if the feature returns.

**If it comes back,** start from this document rather than from the deleted code. The
diagnosis in "Where the manual actions actually come from" is the durable part; the
open question the second attempt never answered is whether a trip plan is something a
traveller wants *inside* a documents-and-money app at all, or whether the flight times
and wishlist places the app already shows are the whole job.

## Context

M5.7 shipped a working day-by-day itinerary: a table (`ItineraryItems`, schema v9), a
Plan tab with per-day sections, drag-to-reorder within a day, and a bottom-sheet form.
Everything in it works and is tested. It is also, on first real use, tedious — the
reported complaint is "requires a lot of manual actions", which the code agrees with:

**Where the manual actions actually come from**

1. **Blank page.** The Plan tab starts empty and asks the user to type. This is the big
   one, and it's self-inflicted: Tripper *already holds* most of a first draft.
   - Flight documents carry `details['departureTime']` (added in M5.3).
   - `Trip.startDate`/`endDate` bound the days; `Trip.destinations` is an ordered list.
   - Places are already linked to a trip (`Place.tripId`, M3) — the wishlist for this
     trip is literally a list of things the user intends to do.
   - Expenses carry dates and categories, so a past day already has a factual record.
   None of that is used. The user re-types information the app has.

2. **Five fields per item.** Title, day, time, place, notes — for a 10-day trip at 3-4
   items a day that's ~35 sheet-opens, each a modal round trip.

3. **A redundant field on every add.** You tap "Add a plan" *under Day 3*, and the form
   then makes you pick the day again from a dropdown. The intent was already expressed
   by which button you tapped.

4. **Free-text time.** `parseTimeToMinutes` accepts `9`, `9:05`, `09:05` and rejects
   `9:5` — reasonable rules, but it's a typing task with a failure mode, and the app
   already uses a native `showTimePicker` for a document's departure time. Two different
   time-entry idioms in one app.

5. **A global place dropdown.** Every saved place, unsorted, including places belonging
   to other trips and places on the other side of the world.

6. **Manual ordering that the data already implies.** If three items on a day have times,
   their order is not a user decision — but the user still has to drag them into it.

7. **A hard gate.** No trip dates → no planner at all. (The dead-end CTA was fixed today;
   the gate itself remains.)

**Constraints that shape the answer**

- Local-first is absolute (CLAUDE.md hard rule 4). Nothing here may require a network.
- Solo maintainer, no deadline pressure, but appetite for churn is limited — v9 shipped
  hours ago and the OCR work (M5.4) is already parked half-finished.
- Anchors are only as good as the data behind them, and that data is currently **sparse**:
  `departureTime` is populated by hand or by the paused OCR/email parsing. This is the
  main risk to the whole idea and is called out again under Consequences.
- Design system: no new accent colours, hairlines not shadows, mono for data.

## Decision

Rebuild the Plan tab as a **derived timeline with inline quick-add**:

- **Anchors are computed, never stored.** Flights, stays, and trip-linked places are
  rendered into the day view directly from documents/places at read time. They are not
  copied into `ItineraryItems`.
- **User items stay stored** in `ItineraryItems` as today — the schema is fine, it is the
  *entry path* that is wrong.
- **Quick-add replaces the form for the common case**: one inline field per day, type
  and submit. The full sheet remains for editing details.

Concretely: `ItineraryEntry` becomes a view-model union of `DerivedEntry` (from a
document/place) and `UserEntry` (from the table). The day list renders a merged, sorted
list of both.

## Options Considered

### Option A: Polish the existing form

Keep the architecture; fix the six smaller frictions. Native time picker, drop the
redundant day field, filter places to this trip, auto-sort timed items, allow planning
without trip dates.

| Dimension | Assessment |
|---|---|
| Complexity | Low — all changes inside `itinerary_form_sheet.dart` + tab |
| Cost | ~half a day |
| Scalability | Fine; nothing structural changes |
| Team familiarity | Total — this is the code as written |

**Pros:** cheapest; zero schema change; no new concepts; every existing test survives.
**Cons:** leaves the blank page untouched, which is the actual complaint. Reduces
per-item cost maybe 30% while the *number* of items the user must hand-enter stays the
same. Treats symptoms.

### Option B: Seed-and-accept (materialise suggestions into rows)

On opening the Plan tab, generate suggested items from documents/places and offer them
("Add your LY315 flight to Day 1?"). Accepting writes a real `ItineraryItems` row.

| Dimension | Assessment |
|---|---|
| Complexity | Medium — suggestion engine + dedupe + accept/dismiss state |
| Cost | ~2 days |
| Scalability | Fine |
| Team familiarity | High |

**Pros:** kills the blank page; accepted items are fully editable and reorderable like
any other; suggestions are explicit, so nothing appears without consent.
**Cons:** **duplication and drift** — once copied, an accepted flight row no longer
tracks the document. Change the departure time in the vault and the itinerary silently
disagrees. That is the same class of bug as the mixed-currency total: two numbers, one
truth, no indication which is stale. Also needs persistent "dismissed" state so
suggestions don't resurrect, which is a third source of state to keep consistent.

### Option C: Derived timeline + inline quick-add — **recommended**

Anchors are computed at read time and rendered inline; they are never rows. User items
are stored as today, added via a single inline field.

| Dimension | Assessment |
|---|---|
| Complexity | Medium — new view-model layer, mostly pure functions |
| Cost | ~2 days, most of it testable domain code |
| Scalability | Fine — merge is O(n) over a day's entries |
| Team familiarity | High; same shape as `itineraryDays`/`groupByDay` already written |

**Pros:**
- No duplication and **no drift by construction** — edit the flight in the vault and the
  Plan tab is already correct, because it never held a copy.
- The blank page disappears on day one for anyone with documents or wishlist places.
- Quick-add reduces the common case to *one gesture and a few words*.
- Deleting a document removes its anchor automatically; no orphan cleanup, no dedupe.

**Cons:**
- Anchors **can't be reordered or edited in place** — they sit at their own time, and
  editing means going to the document. Defensible (the document is the source of truth)
  but it is a real loss of control, and "why can't I drag this?" is a fair question.
- An anchor the user doesn't want on the timeline needs a **hide** mechanism, which is
  one small piece of persisted state (a set of dismissed anchor keys).
- Value is **gated on data that is currently sparse** — see Consequences.

## Trade-off Analysis

The decision between B and C is *where truth lives for an anchor*.

B says the itinerary owns its own copy: maximum flexibility (drag it, retime it, rename
it), at the cost of the copy going stale. C says the document owns it: the timeline is
always right, at the cost of not being directly manipulable.

For this app C is the better trade, for a specific reason: **Tripper's whole premise is
that the vault is the source of truth for travel facts.** A flight's departure time
living in two places, with the itinerary copy silently winning the display, contradicts
that — and this session has already produced two bugs of exactly that shape (the
mixed-currency total; the OCR arrival/departure mix-up). Choosing the design where the
inconsistency *cannot be represented* is worth more than drag-and-drop on a flight row.

A is not really a competitor — it's a subset. Notably, **most of A's fixes are wanted
regardless** (time picker, drop the redundant day field, scope the place list), so A's
work is not wasted under C; it's the second half of C's form work.

The honest case *against* C: if `departureTime` and trip-linked places stay as sparse as
they are today, C's headline benefit doesn't materialise and the user is left with
quick-add — i.e. Option A with extra machinery. That risk is real and is why the
action items start with measuring it rather than building.

## Consequences

**Easier**
- First-run Plan tab is populated, not blank, for any trip with a flight or wishlist places.
- Adding a plain item: one field, no modal.
- Vault edits propagate to the itinerary for free.
- Fewer stored rows; nothing to migrate or reconcile.

**Harder**
- Anchors are not draggable or inline-editable — a deliberate limitation that needs clear
  affordance (tap an anchor → "open the document" rather than an edit form).
- The day view gains a merge/sort step over two sources; ordering rules must be explicit
  (timed entries by time; untimed user items keep `orderIndex` beneath them).
- Reorder semantics get subtler: `orderIndex` now orders user items *relative to each
  other*, not to anchors.

**To revisit**
- If `departureTime` coverage stays low, C's benefit is mostly theoretical — revisit
  after M5.4 (OCR) is unparked, since that's what populates it automatically.
- `ItineraryItems.orderIndex` may want to become a float/fractional rank if inserting
  between anchors ever becomes a requirement.
- Whether anchors should ever be "promoted" into real rows (a B/C hybrid) if users ask
  to customise them.

## Action Items

1. [ ] **Measure before building.** Check a real trip: how many documents have a usable
       `departureTime`, how many places are trip-linked? If the answer is ~zero, do
       Option A now and revisit C after OCR lands. *This gate exists because the
       recommendation's main benefit depends entirely on the answer.*
2. [ ] Ship the Option-A subset first — it's wanted either way and is low-risk:
       native time picker; remove the redundant day dropdown when adding from a day;
       scope the place picker to this trip's places (others behind "all places");
       auto-sort timed items and only allow dragging untimed ones.
3. [ ] Allow planning a trip with no dates (derive days from the items themselves, or
       offer a "Day 1/2/3" relative mode) — removes the hard gate.
4. [ ] Define `ItineraryEntry` (`DerivedEntry` | `UserEntry`) plus a pure
       `mergeDayEntries(...)`; unit-test the ordering rules before any UI work.
5. [ ] Derive anchors: flight documents (departure time), stay documents (check-in date),
       trip-linked places (untimed suggestions at the end of a day).
6. [ ] Inline quick-add per day, with an optional leading time (`"19:00 Dinner"`) parsed
       by the existing `parseTimeToMinutes`.
7. [ ] Hidden-anchor state (a persisted set of keys) so an unwanted anchor can be dismissed.
8. [ ] Update `docs/plans/M5-phase2a.md` §5.7 to point at this ADR, and record which
       option was actually taken.

## Implementation record (2026-07-23)

Option C shipped. What was built, and where it deviated from the plan:

- `domain/itinerary_entry.dart` — sealed `ItineraryEntry` (`UserEntry` | `DerivedEntry`),
  `compareEntries`, `mergeDayEntries`, `deriveAnchors`, `derivePlaceSuggestions`,
  `parseQuickAdd`. All pure; 30+ unit tests in `itinerary_entry_test.dart`.
- Anchors: flights (departure time → timed), stays (expiry date → untimed), trip-linked
  unvisited wishlist places (untimed suggestions on day 1). Documents/places belonging to
  another trip are filtered out, tested.
- `itineraryEntryDaysProvider` composes items + documents + places + hidden keys.
- Quick-add field per day; submitting keeps focus so several plans are several lines of
  typing rather than several modals.
- Hidden anchors in SharedPreferences (`hiddenAnchorsProvider`), with per-item undo and a
  bulk "Show hidden suggestions".
- Option-A quick wins folded in: native time picker (matching the document form),
  day dropdown only shown when *editing*, place list scoped to this trip.

**Deviations / open points**

1. **Drag-to-reorder is currently unwired.** The merged list mixes anchors and user items,
   and `ReorderableListView` over a heterogeneous list whose order is partly derived is
   not obviously correct — so ordering is now: timed entries by time, then untimed user
   items by `orderIndex` (assignment order), then suggestions. `reorderWithinDay` and
   `ItineraryRepository.applyReorder` are **retained but unused**, with their tests, for
   when drag returns. This is a real capability regression versus M5.7 and should be an
   explicit decision, not an accident — if manual ordering of untimed items matters,
   re-add a drag handle scoped to the untimed-user-item run only.
2. Stay anchors reuse `Document.expiryDate` as a stand-in check-in date, because the model
   has no stay-date field. It's honest (only used when present) but thin — a real
   `checkInDate` in `Document.details` would be better.
3. Anchors open the Vault/Places *tab*, not the specific record — the router has no
   deep-link to a single document or place yet.

## Notes

> Everything below described the state of the code on 2026-07-23. It was all deleted on
> 2026-07-26 — see the withdrawal note at the top. Kept as a record of what was tried.

- No schema change is required for Option C. `ItineraryItems` (v9) stays as-is; if
  hidden-anchor state is added it can live in SharedPreferences as a cache-like set,
  the same call made for exchange rates in M5.5b.
- Existing M5.7 tests remain valid — the domain functions (`groupByDay`, `tripDates`,
  `reorderWithinDay`, `parseTimeToMinutes`) are all still used under C.

## Postscript

Deviation 1 above never got its explicit decision: the reply to "drag-to-reorder is a
real regression, do you want it back?" was to withdraw the feature. Worth remembering
that the honest flag prompted a useful answer, just not the one it asked for.
