# Competitive analysis — Wanderlog vs. Tripper

**Date:** 2026-07-26
**Question asked:** what would make Tripper "the best seller it can be"?
**Constraint chosen:** Tripper stays a personal, local-first, offline Android app. No
accounts, no server, no collaboration. (See "The tension" below — this constraint
disqualifies most of what makes Wanderlog popular, and that's the point.)

**Sources, in order of reliability:**

1. **A hands-on session (2026-07-26)** driving Wanderlog's *mobile web* app — a real
   place added to a live trip, a fresh empty trip created for empty-state checks,
   computed CSS read for the design values. Findings in §2.5.
   *Gaps in that session, stated by the tester:* mobile web rather than the native
   Android app; UI in Hebrew; phone-sized viewport, so **the desktop split-pane view was
   never seen**; and three flows didn't complete (second expense save, checklist
   creation, the final flight form). Anything resting on those is marked unverified
   below and should not be treated as fact.
2. Wanderlog's free-vs-Pro split and pricing.
3. ~60 testimonials on their homepage — marketing-selected, so biased upward, but useful
   for one thing: which features users name unprompted.

---

## 1. The tension, stated up front

Wanderlog's pitch is "one app for all your travel planning needs," and its most-praised
features are, in rough order of how often users mention them:

1. **Itinerary and map in one view** — by a wide margin the most-named thing.
2. **Group collaboration** — a shared, live-editing trip. Named constantly.
3. **Email auto-import** — forward a confirmation, get a structured reservation.
4. **Place suggestions** — "once you add a place it suggests attractions nearby."
5. **Route optimization** — reorder a day to minimise driving.
6. **Budget/expenses**, **checklists/packing lists**, **AI planning**, **offline maps**.

Of those, **2 requires a backend, 3 requires mailbox access, 4, 5 and 8 require paid
APIs or a model.** Under a local-first, no-account constraint, roughly half of
Wanderlog's appeal is structurally out of reach. That is not a problem to solve — it is
the trade already made deliberately in SPEC §3.1.3 and CLAUDE.md hard rule 4.

So "best seller" is the wrong frame for the app as scoped. The right frame:

> **Tripper is the app you want at the airport, not the one you want on the sofa.**

Wanderlog is a *planning* tool that also works during a trip. Tripper is a *travelling*
tool. Wanderlog needs a network and a login to be useful; Tripper works with a dead SIM
in a foreign airport with 4% battery. That's a genuine niche, it's underserved, and it's
one Wanderlog charges $39.99/year to partially match (offline access is Pro-only).

**The strategic move is not to catch up on planning. It's to be unambiguously the best
thing to open when you land.**

---

## 2. What Tripper already wins on

Worth being explicit, because these are real and were nearly invisible to me until I
lined them up against a competitor:

| Capability | Tripper | Wanderlog |
|---|---|---|
| Works fully offline | Always, by construction | **Pro only** ($39.99/yr) |
| Document vault (passport, visa, insurance) | Core feature, biometric-locked | Attachments only; unlimited attachments is Pro |
| Document expiry warnings | Yes, with configurable notice window | No |
| Multi-currency expenses **without a network** | Yes — stored conversion, pending when offline | Conversion exists, but needs a live rate |
| File attached to a saved place | Free (the vault is the whole point) | **Pro only** |
| No account required | Yes | Sign-up required |
| Data stays on device | Yes | Server-side |

**Correction to an earlier draft of this document.** I previously claimed Wanderlog
couldn't convert mixed currencies to a single home-currency total, on the strength of one
testimonial asking for exactly that. The hands-on session disproves it: expenses have a
**per-line-item currency picker** and the budget header shows **one converted total** in
the trip's home currency. Either the review predates the feature or it was asking for
something narrower. Tripper's remaining edge here is real but much smaller than I wrote:
conversion that works from stored rates and degrades to "pending" offline, rather than
conversion that needs a live lookup. Worth knowing before anyone leans on "we do
currencies better" as a differentiator.

---

## 2.5 Hands-on findings (2026-07-26, mobile web)

**Interaction cost, measured.** Adding a place is **3 taps plus typing, with no confirm
step** — tap the add field, tap the input, type, tap the matching result and it's saved.
Everything else on the card arrives for free: formatted address, phone, website, price
tier, rating and review count, typical visit duration, weekly opening hours. This is the
bar. Any Tripper flow that asks for more than one deliberate decision per added thing is
losing to it, and the Plan tab's five-field form was losing badly.

**The split view I built a recommendation around doesn't exist on mobile.** List and map
are two full-screen modes behind a floating toggle; the toggle's CSS class is scoped to
small screens, implying the true split pane is desktop/tablet only. What *does* carry the
value is much cheaper than a split pane: **map pins are numbered to match list order**,
and tapping a pin opens that place as a bottom sheet. That's the version worth copying.

**The best idea in the product is a conflict warning.** Add a place to a day that falls
on a Tuesday, and it tells you the place is closed on Tuesdays and offers to reschedule.
It needs live hours data, so Tripper can't copy it directly — but the *pattern* is the
single most transplantable thing here, and it's the shape Tripper already wins with:
derived from data on hand, no typing, surfaced at the moment it matters. See item 1.5.

**Empty states always pair the message with one concrete action.** An empty trip's map
auto-centers on the destination and offers a specific named pin plus a link to browse
attractions; a dateless itinerary says "choose a start and end date" rather than just
"empty"; an empty budget shows `₪0.00` rather than a blank. Cheap, local, and directly
comparable to Tripper's existing `EmptyState` primitives.

**Suggestion quality degrades at the edges.** A multi-country wishlist (Japan, Indonesia,
Thailand, Philippines, Vietnam, S. Korea, Taiwan) was offered Angkor Wat and the Taj
Mahal — neither country on the list. Regional/loose matching, not strict. Relevant to
M5.10: a nearby-POI feature that returns confidently wrong suggestions is worse than one
that returns fewer.

**Design values, read from computed styles.** White `#FFFFFF` with cream card surfaces
`#FAF9F5`; coral-orange accent `#F75940`; near-black `#212529` text; gray borders
`#E9ECEF`. Single sans family (Source Sans Pro), headings are just bold — no display or
serif face. Cards: 16px radius, `0 4px 24px rgba(0,0,0,0.2)` shadow, **no border**. Pill
buttons at 20–24px radius. Generous density; reads consumer, not utility.

Two things to take from that, and one to ignore:

- **Take:** the accent is used with real restraint — primary actions and Pro badges only,
  nothing else. Same discipline as Tripper's rule that rust means warnings only. Worth
  auditing that teal is actually held to the same standard.
- **Take:** the place-detail card carries a lot of live data compactly without feeling
  cluttered. Tripper's cards are calmer but also carry less; information density is a
  fair critique, not just a stylistic difference.
- **Ignore:** shadows, pill buttons, single-sans. Tripper's paper/serif/hairline language
  is a deliberate opposite and the comparison gives no reason to move.

**Annoyances worth not repeating.** Two adjacent fields (day subtitle, add-place) sit
directly on top of each other and get mis-tapped. A required category field isn't marked
required until a validation bounce. The reservation import funnel presents three
*alternative* paths (forward email / Gmail sync / manual) in a way that reads as
sequential steps. A full-screen "get the native app" interstitial appears on every fresh
navigation to a trip.

**Unverified, flagged by the tester:** whether checklists seed any content or start blank
(the control wouldn't instantiate). The tester's inference is blank, on the grounds that
nothing else in the product does trip-length- or weather-aware generation. If that's
right it's mildly good news for item 1.3 — the seeded version would be a genuine
differentiator rather than parity.

---

## 3. Ranked feature list

Sized as **S** (a day or two), **M** (a few days), **L** (a week-plus). Ordered by
value-per-effort *under the local-first constraint*, not by how impressive they sound.

### Tier 1 — build these

**1.1 Offline map tiles for the trip area** — L
The single biggest gap between "works offline" as a claim and as an experience. Places
already has a map; today it needs a network. Pre-download a bounding box per trip so the
map is real when you land. Wanderlog gates exactly this behind Pro, which is a strong
signal it's the thing travellers actually pay for. Already listed as deferred in M3
("persistent tile cache") — promote it. Watch: tile licensing terms, storage budget, and
an honest "downloaded / not downloaded" indicator rather than a silently blank map.

**1.2 "At the airport" mode / arrival card** — S
Already scoped as M5.9. One screen: flight number, first-night address, return date,
passport number — the immigration-form answers, pulled from documents already stored.
Zero network, zero typing, no new table. This is the highest-value-per-hour item on the
list and it's the shape that survives: derived, not typed.

**1.3 Packing / pre-flight checklist** — M
Named repeatedly by Wanderlog users ("it has a packing list as well", "loved the AI
feature and checklists"). Fully local, no API. The version worth building is *not* a
blank list: seed it from what the app knows — trip length, destination, whether a flight
document exists, whether the passport expires within six months. A generated starting
list you edit beats an empty one you fill. **Caution:** this is a "type things in"
feature, the same shape as the withdrawn Plan tab. It only earns its place if the seeded
list is good enough that most users never add a row.

**1.4 Home-screen widget / quick-access lock screen card** — M
Boarding pass, hotel address, passport — one tap from locked. Nothing in Wanderlog
matches this, and it's the purest expression of "best thing to open when you land."
Needs care around the vault lock: a widget that leaks a passport number defeats M2's
biometric gate. Probably shows non-sensitive fields only, with sensitive ones behind the
existing unlock.

**1.5 Offline conflict warnings** — S/M — *added after the hands-on session*
The transplant of Wanderlog's "closed on Tuesday" idea. They compute conflicts from live
opening hours; Tripper can compute a different and arguably more valuable set from data
already on the device, with no network at all:

- passport (or any document) expires **before or during** the trip, not just "soon";
- passport expires within six months of the return date — the rule most countries
  actually enforce, and one nobody remembers;
- trip starts in N days and has **no flight document** linked;
- a stay document's dates don't cover the whole trip — a gap night;
- a flight's departure date falls outside the trip's own dates.

Surfaced on the trip screen as a quiet warning row (rust — this is exactly what hard rule
1 reserves it for), not a modal. Pure functions over existing tables, so it's cheap and
almost entirely unit-testable. This is the highest-conviction *new* idea from the whole
exercise: it's derived rather than typed, it's impossible for a server-dependent
competitor to do offline, and it produces the thing an airport app should produce — a
warning you get while you can still act on it.

### Tier 2 — worth doing, less urgent

**2.1 Trip-scoped map view with numbered pins** — S/M (**revised down** from M)
Wanderlog's most-praised feature is "itinerary and map in one view," but the hands-on
session shows mobile doesn't do a split pane at all — it toggles between list and map,
and the actual synchronisation is just **pin numbers matching list order** with a bottom
sheet on tap. That's far cheaper than a split view and captures most of the value: one
map, every place linked to this trip, numbered to match the list. Derived entirely from
existing data. The good half of what ADR-001 was reaching for.

**2.1b Empty-state audit** — S
Every empty state gets one concrete action, not just a message — the one pattern from
Wanderlog worth copying wholesale. Tripper already has the `EmptyState` primitive, so
this is a pass over existing call sites rather than new machinery. Pair with a quick
forms audit for the two annoyances above: mark required fields as required *before* the
validation bounce, and check no two adjacent tappable fields invite a mis-tap.

**2.2 Finish OCR properly (M5.4)** — M
Currently paused with passport MRZ working and flight/hotel unreliable. The fix isn't
more regex tuning — it's a fixture corpus of real documents plus a review-before-apply
sheet. Wanderlog solves the same problem by reading your Gmail, which Tripper won't do;
OCR is the local-first substitute and it's the only route to reservation auto-fill.

**2.3 Email-parsing spike (M5.11)** — S to run, M if it passes
Share a confirmation email in via the existing `ACTION_SEND` handler. Already gated at a
~50% catch rate. Cheap to decide, and a pass would make 2.2 much less important.

**2.4 Photo journal (M5.8)** — M
Wanderlog has one and users like it, but note *when* they like it: retrospectively
("great for reminding yourself what you did in previous trips"). Same typing-shaped risk
as 1.3 and the Plan tab. Photos may carry it where text wouldn't, since the input is a
camera roll rather than a keyboard.

**2.5 PDF trip export (M5.13)** — S
Scope shrank when the itinerary went; it's now documents + places + expenses. Still
useful for visa applications and for a travelling companion who doesn't have the app —
the local-first substitute for Wanderlog's sharing.

### Tier 3 — deliberately not doing, recorded so it stays a decision

- **Group collaboration / shared trips** — needs a backend. Breaks hard rule 4. This is
  Wanderlog's single strongest feature and Tripper is choosing not to compete on it.
- **AI trip planning** — needs a model and a network. Also: the Plan tab withdrawal
  suggests the demand for generated itineraries inside *this* app is unproven.
- **Automatic Gmail scanning** — mailbox access is the opposite of the privacy position.
- **Booking / hotel deals** — affiliate revenue is Wanderlog's business model, not this
  app's purpose.
- **Route optimization** — needs a directions API per recalculation. Revisit only if
  1.1's offline routing data makes a local approximation cheap.

---

## 3.5 Still unverified — worth a second Chrome pass

Not blockers, but the analysis would be firmer with them:

- **The desktop split-pane view.** The most-praised feature in the product and nobody has
  actually seen it. Needs a desktop-width viewport.
- **Whether checklists seed anything.** Decides whether item 1.3 is parity or a
  differentiator.
- **A mixed-currency budget total.** Confirm the conversion behaviour directly rather than
  inferring it from the presence of a per-line currency field.
- **The rendered flight card** after a completed manual entry.
- **The native Android app**, which is where offline mode and the split view actually
  live — mobile web is the wrong surface for judging the thing they charge for.

---

## 4. What I'd revisit as this grows

- **If offline maps (1.1) prove expensive or legally awkward,** the whole "best app at
  the airport" thesis weakens, because a map you can't load is the most visible offline
  failure. Test tile licensing and storage cost *before* committing to the framing.
- **If 1.3 or 2.4 get built and go unused the way the Plan tab did,** that's three
  data points on the same pattern and the conclusion is structural: this app is for
  *retrieving* things, not *authoring* them. Worth writing down as a design rule at that
  point rather than rediscovering it a fourth time.
- **If the ambition ever changes to a real Play Store release,** this document is the
  wrong analysis — release hygiene, an app icon, a privacy policy, crash reporting and a
  support channel all come before any feature here.

---

## Sources

- [Wanderlog homepage](https://wanderlog.com/) — feature claims and ~60 user testimonials
- [Wanderlog Pro cost 2026: pricing breakdown (free vs Pro)](https://tripstone.app/blog/wanderlog-pro-cost)
- [Wanderlog Pro cost 2026: $39.99/yr, worth it or go free?](https://monkeyeatingmango.com/blog/wanderlog-pricing-2026/)
- [Is there a free trip planner? — Wanderlog blog](https://wanderlog.com/blog/2024/10/14/is-there-a-free-trip-planner/)
- [Wanderlog review 2026: is it good? (what Reddit says)](https://tripstone.app/blog/wanderlog-review)
