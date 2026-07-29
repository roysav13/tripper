# M5 — Phase 2a: quick wins & network-enhanced input

**Goal:** ship the non-GPS Phase 2 features from [SPEC §3.2.1](../SPEC.md#321-phase-2a--quick-wins--network-enhanced-input). Every item stays inside CLAUDE.md hard rule 4 (local data is always the source of truth; network enhances, never gates) and hard rule 5 (tests land in the same commit).

**Depends on:** M1–M4 (trips/vault/places foundations, design system, testing conventions). Live GPS tracking (SPEC §3.2.2) is a separate, later milestone (M6) — nothing here blocks on it, though journal entries get better once it ships.

**Exit criteria:** every sub-milestone below checked off; `flutter analyze && flutter test` green; every network-touching item (OCR is the one exception — fully on-device) has a tested offline-fallback path per CLAUDE.md hard rule 4.

**Build order rationale:** grouped by shared infrastructure and risk, not SPEC's listed order.

1. Notifications subsystem first — three later items depend on it, better to build the scheduling primitive once.
2. Fully local, zero-dependency items next (expenses, days-traveled stat, OCR) — lowest risk, no blockers, builds momentum.
3. Items that depend on already-shipped places search (itinerary, arrival card, nearby POI).
4. Journal entries — standalone but bigger (photo storage).
5. The two spike/cost-gated items (email parsing, nearby POI) get their gate-check called out explicitly so they don't quietly turn into unbounded scope.
6. Deep-links and PDF export near the end — smallest and most isolated.
7. Hebrew/RTL last, deliberately — it's a sweep over whatever ARB strings and layouts this milestone adds, so doing it earlier means redoing it.

**Correction to SPEC's OCR note:** SPEC §3.2.1 describes OCR as "same package family as M2's existing `google_mlkit_barcode_scanning`" — that's stale. Per `docs/plans/README.md`, ML-Kit barcode extraction was **deferred** out of M2, not shipped, and `google_mlkit_barcode_scanning` isn't in `pubspec.yaml`. 5.4 below adds `google_mlkit_text_recognition` fresh, with no existing ML-Kit dependency to build on.

---

## 5.1 Local notifications subsystem (foundation for 5.2, 5.3) — built 2026-07-23

One scheduling subsystem, three trigger types (SPEC §3.2.1 groups these explicitly).

- [x] Add `flutter_local_notifications` + `timezone` — `pubspec.yaml` (versions unverified against pub.dev — this sandbox has no network access; confirm on `flutter pub get`)
- [x] `NotificationService` in `lib/core/notifications/notification_service.dart`: `initializeNotificationPlugin()`, `requestPermission()`, `resyncAll()`, `cancel()`, plus a `NotificationScheduler` interface (`PluginNotificationScheduler` prod impl) so nothing outside this file touches the real plugin
- [x] Deterministic notification IDs — `notificationId()`, FNV-1a hash of `(entityType, entityId, triggerType)`, collision/determinism/replace-not-stack all unit tested
- [x] Settings entry: master + 3 per-type toggle providers in `settings_service.dart` (`notificationsMasterEnabledProvider`, `docExpiryNotificationsEnabledProvider`, `tripCountdownNotificationsEnabledProvider`, `checkInNotificationsEnabledProvider`), all default on. **Not yet wired into the Settings screen UI** — deliberately: there's nothing real for these to control until 5.2/5.3 register a source, and shipping toggles for features that don't exist yet is confusing UI. Add the visible settings section alongside 5.2.
- [x] Reschedule-on-launch mechanism — `NotificationService.registerSource()` + `resyncAll()`: cancels everything, replays every registered source, skips past-due times. This is the boot-receiver substitute the plan called for (app-open resync instead of a native `BOOT_COMPLETED` receiver — smaller permission footprint, see `AndroidManifest.xml` comment). **Not yet called from `main.dart`/app startup** — harmless to wire early since zero sources are registered (a no-op resync), but there's no real behavior to verify yet either, so wiring the actual startup call happens with 5.2 once a source exists to prove it against.
- [x] Tests — `test/unit/notifications/notification_service_test.dart` (ID derivation, resync/master-toggle/past-filtering/replace-not-stack, permission delegation, single cancel) and `test/unit/notifications/notification_settings_test.dart` (defaults, persistence, independence across the 4 toggles). Fake `NotificationScheduler`, never touches a real OS tray.

Also added: `android/app/src/main/AndroidManifest.xml` now requests `POST_NOTIFICATIONS` only — deliberately not `SCHEDULE_EXACT_ALARM` (day-scale reminders don't need exact alarms, `AndroidScheduleMode.inexactAllowWhileIdle` avoids the sensitive permission) and not `RECEIVE_BOOT_COMPLETED` (resync-on-launch instead, see above).

Two build-time fixes found via real `flutter analyze`/Gradle runs (this sandbox can't run either, so these only surface once the user builds locally):
- `zonedSchedule` needed an explicit `uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime` argument — required by the resolved plugin version's signature, Android ignores it (iOS-only concept).
- Gradle failed with "`flutter_local_notifications` requires core library desugaring" — fixed via `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` in `android/app/build.gradle.kts`.

Non-blocking, noted but not acted on: a Gradle warning that `package_info_plus`/`pdfx`/`share_plus`/`wakelock_plus` apply the Kotlin Gradle Plugin directly, which a future Flutter version will stop supporting — that's on those plugins' maintainers, nothing to fix in this repo today, just something to watch for when bumping Flutter/plugin versions later.

## 5.2 Document-expiry + trip-countdown notifications

Reuses the existing bucketing logic in `lib/features/vault/domain/expiry_checker.dart` (M2) as the trigger source — this is wiring existing in-app awareness to real OS notifications, not new expiry logic.

**Partial head start, out of sequence (2026-07-23, user-driven):** the vault list's red border was originally `ExpiryChecker.needsAttention()` (expired OR expiring within the fixed 90-day `kExpiryBufferDays`), which made every near-term document look like an error — fixed to border-on-`isExpired()`-only. While in there, `isExpiringSoon`/`needsAttention` gained an optional `noticeDays` parameter (default still 90, so old behavior is unchanged unless the setting is touched) and a new user-configurable setting, `documentExpiryNoticeDaysProvider` (presets: off/7/30/60/90 days, in Settings), was added. **This is exactly the "notice window" 5.2 needs — reuse `documentExpiryNoticeDaysProvider` for the expiry-warning fire-time computation below instead of the fixed buffer.**
Built 2026-07-23:

- [x] On document save/edit: expiry-warning fire time derived from `documentExpiryNoticeDaysProvider` (not the fixed `kExpiryBufferDays`) — pure function `documentExpiryNotifications()` in `lib/features/vault/domain/document_notifications.dart`. Off entirely when the setting is 0. If the ideal fire date (expiry − noticeDays) has already passed, fires almost immediately instead of being silently dropped by `resyncAll`'s past-filter
- [x] Trip-countdown nudge: "starts in 3 days — 2 documents need attention" (or "everything's in order" when nothing's risky) — pure function `tripCountdownNotifications()` in `lib/features/trips/domain/trip_notifications.dart`, fires `kTripCountdownDays` (3, not user-configurable — no equivalent convention to anchor a setting to) before `Trip.startDate`, only for non-archived trips currently `TripStatus.upcoming`. "Needs attention" = `ExpiryChecker.isRiskyForTrip` over that trip's linked documents, not just "any document expiring soon" — ties the count to *this* trip's dates specifically
- [x] Cancel/reschedule on document or trip edit/delete — not wired at individual mutation call sites; instead `lib/core/notifications/notification_wiring.dart` uses `ref.listen` on `vaultDocumentsProvider`/`tripListProvider`/the notification settings providers and calls `resyncAll()` on any change, plus once at startup. Deliberate choice over per-call-site resync: can't forget to wire a new mutation path later. `NotificationService.resyncAll` is itself a full cancel-then-reschedule (M5.1), so this is correct by construction, not just by convention
- [x] Tests: `test/unit/vault/document_notifications_test.dart`, `test/unit/trips/trip_notifications_test.dart` — fire-time computation (injected clock), notice-window boundaries, singular/plural body copy, cross-trip document isolation, the "ideal date already passed" clamp for both sources

Note: notification title/body text lives in `AppLocalizations` per CLAUDE.md hard rule 3 (every user-facing string through ARB), but these pure functions run outside the widget tree (background resync, not a build method), so they take an `AppLocalizations` instance directly (`lookupAppLocalizations(const Locale('en'))`, gen-l10n's context-free lookup) rather than pulling it from `BuildContext`.

**Real gap found on-device (2026-07-23):** nothing ever appeared in the notification tray. Root cause: `NotificationService.requestPermission()` / `PluginNotificationScheduler.requestPermission()` were fully built but never actually *called* anywhere in the app — Android 13+ requires `POST_NOTIFICATIONS` granted at runtime, and without that call every `zonedSchedule` silently no-ops. Fixed in `notification_wiring.dart`: request permission, then run the initial resync, sequenced (not concurrent) so the first schedule call doesn't race the permission prompt's result.

Two more on-device caveats worth knowing before re-testing: (1) this fix needs a full app restart, not a hot reload — the permission request only runs once, at provider-creation time; (2) `AndroidScheduleMode.inexactAllowWhileIdle` (chosen deliberately to avoid `SCHEDULE_EXACT_ALARM`, see `AndroidManifest.xml`) means the OS can batch/delay delivery, especially for the "fire almost immediately" clamp case (~1 minute out) — some OEM battery managers (Samsung, Xiaomi, etc.) delay inexact alarms well past that, so "didn't show up within a minute" isn't necessarily still broken.

## 5.3 Check-in-opens reminders

Built 2026-07-23:

- [x] Derive from a flight `Document`'s stored departure time minus a **fixed 24h offset** — pure function `checkInOpensNotifications()` in `lib/features/vault/domain/checkin_notifications.dart`. SPEC is explicit this is a deliberate simplification (real airlines vary 24-48h); the notification body says so rather than implying precision it doesn't have
- [x] Schedule via 5.1 on document save if `Document.details` has a parsed departure time; no-op (not an error state) if it doesn't — wired as a third source in `notification_wiring.dart`, gated on the existing `checkInNotificationsEnabledProvider`
- [x] **Gap found and closed:** no departure-time data existed anywhere before this — `DocumentFormSheet` had only `flightNumber`/`confirmationCode` for flights, nothing date/time-shaped. Added an optional date+time picker (Flight category only) writing an ISO-8601 string to `Document.details['departureTime']` (`kDepartureTimeDetailKey`). Without this the whole feature would be dead code with no data path until OCR (5.4) or email parsing (5.11) ships — those will also write this same key once built, this doesn't need to change when they land
- [x] Tests: `test/unit/vault/checkin_notifications_test.dart` (offset computation, no-op for missing/unparsable/non-flight/already-departed, the "check-in already open" clamp) and `test/widget/vault/document_form_sheet_test.dart` (field visibility by category, optional-save leaves the key unset). Not tested: driving the actual native date/time picker dialogs through a widget test — that exercises Flutter's own calendar/clock widgets, not app logic; verify the real picker flow on-device

## 5.4 OCR on document photos — ⚠️ PAUSED, NOT DONE (2026-07-23)

Zero network, zero cost, fully on-device. See the SPEC correction above — this adds ML-Kit fresh.

**Status: parked mid-flight at the user's call — "there are a lot of mistakes in the flow".** What works: passport MRZ prefill from a photo (confirmed on-device). What doesn't: non-passport extraction is unreliable on real documents — across three on-device rounds the flight number matched but booking code / departure / expiry repeatedly didn't, and an earlier round put the *landing* time into the departure field. Each fix so far has been a reaction to one document; the pattern set is clearly still under-fitted to real-world layouts.

**Before resuming, read this:** the loop of "widen a regex, rebuild, retest one file" is not converging and shouldn't just be continued. Better next step is to collect a handful of real documents (boarding pass PDF, airline HTML email, hotel confirmation) as *fixtures* first, then work against them as a test suite — `travelDocDebugLines()` already dumps the keyword-adjacent lines in debug builds for exactly this. Also worth reconsidering the design: a review-before-apply sheet (show what was found, let the user accept/reject per field) would make partial or wrong extraction a non-issue rather than something the parser has to get right blind. Everything below is accurate as built; the checkboxes reflect code that exists and is tested, not a feature that's finished.

Built 2026-07-23:

- [x] Add `google_mlkit_text_recognition` (`^0.13.0` — version unverified against pub.dev in this sandbox, confirm on `flutter pub get`)
- [x] `DocumentTextRecognizer` seam in `lib/features/vault/data/document_ocr_service.dart` — ML-Kit behind an interface (same pattern as M5.1's `NotificationScheduler`), any recognition failure degrades to `''`/no-prefill, never an error. The real impl is the provider default (safe in the test VM: the plugin's MissingPluginException is swallowed into `''`)
- [x] Passport MRZ parser first — `lib/features/vault/domain/mrz_parser.dart`, pure Dart, ICAO 9303 TD3 (2×44 chars): tolerates OCR-inserted spaces and surrounding page text; validates the document-number and expiry check digits independently (a failed digit drops that field, not the whole parse); **rejects any candidate where neither check digit validates** — check digits are the entire trust basis, a name-only "match" with zero validation is treated as noise; expiry two-digit year pivots at 80
- [x] Wire into `DocumentFormSheet` as prefill — never clobbers user input: the rules live in pure `computeMrzPrefill()` (category only replaces the untouched default, title only replaces empty-or-filename-autofill, expiry/number only fill empty fields, number only for the passport category). Quiet "Filled in from the photo — double-check before saving." snackbar; PDFs skipped (images only)
- [x] No schema change — expiry → existing `expiryDate` column, number → existing `details['number']` key the passport category already used
- [x] Tests — `test/unit/vault/mrz_parser_test.dart`: ICAO specimen parse, OCR-space tolerance, embedded-in-page-text, per-field check-digit corruption, garbage/never-throws, non-MRZ-second-line rejection, year windowing, and all four never-clobber rules via `computeMrzPrefill`. The clobber rules are deliberately in a pure function so they're tested without a widget tree, `FilePicker` fake, or ML-Kit

Not covered by tests, verify on-device: real ML-Kit accuracy against an actual passport photo (fixtures can't measure recognition quality — expect the MRZ to work well and freeform fields to be hit-or-miss, per SPEC's own framing), and the end-to-end pick-photo→prefill flow.

**First on-device attempt failed silently (2026-07-23), two fixes:**
- Real bug: OCR prefill only ran on the "Attach file" button path — a photo arriving via the Android share-into-Tripper flow (`initialFilePath` in `initState`) skipped it entirely. Now both paths run `_tryOcrPrefill`.
- Parser hardening for real OCR output (clean fixtures were too optimistic): trailing `<<<<` filler truncation on either line is padded back out instead of rejected (line 2 needs only positions 0-27 intact), both lines merged into one 88-char OCR line are split, and guillemet misreads («/»/‹/›) map back to chevrons. All covered by new fixture tests.
- Debug diagnostics added (`[ocr] ...` lines, `kDebugMode` only, lengths/stages — never the recognized text itself): distinguishes "not an image" / "recognizer returned nothing" / "text found but no MRZ" when running via `flutter run`.

**Freeform extraction for non-passport documents added (2026-07-23, user request):** when no MRZ is found, `parseTravelDoc()` (`lib/features/vault/domain/travel_doc_parser.dart`) runs keyword-gated heuristics over the OCR text: flight number (`\b[A-Z]{2}\s?\d{1,4}\b`, FLIGHT-line preferred; letter-digit airline codes like U2/9W out of scope v1), booking/PNR code (5-10 alnum near PNR/BOOKING/CONFIRMATION keywords, stopword-filtered, all-digit accepted at ≥6), departure date+time (DEPART/STD-gated, both date AND clock time required — date-only would misplace the M5.3 check-in reminder — plausibility window now-1d..now+2y), and expiry (EXPIR/VALID UNTIL-gated, window now-5y..now+40y). Date formats: dd MMM yyyy, ISO, dd/mm/yyyy (day-first per app convention; US mm/dd misparses — accepted v1 limitation). `computeTravelPrefill()` applies the same never-clobber contract as the MRZ path, auto-picks the flight category only when ≥2 flight-context keywords (or number + 1) are present, maps codes to the right per-category detail slot, and suggests "Flight LY315"-style titles. No check digits exist here, so unlike MRZ this is hit-or-miss by design — SPEC's own framing. **Deliberately input-agnostic: this is exactly the heuristic set M5.11's email parsing needs — reuse `parseTravelDoc` on shared email text and run the spike gate against it.** Tests: `travel_doc_parser_test.dart` (boarding pass/hotel/visa fixtures, date formats, plausibility windows, stopwords, prose-yields-nothing, and all prefill clobber rules).

**Arrival-mistaken-for-departure bug fixed + HTML support (2026-07-23, user report):** real flight documents produced departure times that were actually the *landing* time — the departure search window blindly absorbed following lines, including the arrival block. Fix in `_findDeparture`: arrival markers (ARR/ARRIVAL/LANDING/ETA) now bound the search — the keyword line is truncated at the first arrival marker after DEPART (handles single-line "DEP 07:25 ARR 10:45" columns), following lines stop joining the window at the first arrival-marked line, text left of the DEPART keyword is never scanned, and "DEP" (not just "DEPART") now matches. Also: a date on the line *above* the labeled departure row is used (common ticket layout). HTML: `.html`/`.htm` files (airline confirmations saved from email) are now valid vault attachments — `htmlToPlainText()` (`domain/html_text.dart`, dependency-free: strips script/style/comments, block closers → newlines, entity decoding) feeds the same `parseTravelDoc` pipeline, no OCR involved; file picker + mime map + a `text/html` share-target intent-filter added. Tests: 5 new arrival-boundary cases, `html_text_test.dart`, extractor html-routing + missing-file degradation.

**Pattern widening after a real airline HTML email (2026-07-23):** 6287 chars / 176 lines extracted fine and the flight number matched, but code/departure/expiry didn't — the patterns were too narrow for real email layouts. Added: US-style month-first dates ("AUGUST 13, 2026"), ordinal suffixes ("13TH AUG"), 12-hour AM/PM times, all-letter 6-char PNRs (ABCDEF — the classic format, previously rejected as too word-like) when next to a *strong* keyword, a strong/weak keyword split (PNR/RECORD LOCATOR/BOOKING REF/ETICKET/ORDER NUMBER vs. bare BOOKING/CONFIRMATION/REFERENCE), label→value lookahead widened to 3 lines and the departure window to 4 (HTML tables split one visual row across many lines; the arrival-marker boundary is what keeps that safe), and a much longer stopword list. Also added `travelDocDebugLines()`: on a partial extraction in debug builds only, dumps the keyword-adjacent lines (with context, truncated) so layouts can be diagnosed rather than guessed at — never in release, since it's real document content.

**Encoding fix, same day:** the first real .html file failed with `FileSystemException: Failed to decode data using encoding 'utf-8'` — saved-email HTML is frequently UTF-16 (Outlook/Gmail exports) or Windows-1252, and `File.readAsString()` uses a strict UTF-8 decoder that throws on those. Added `decodeTextBytes()`: BOM detection (UTF-8/UTF-16 LE/BE) → BOM-less UTF-16 detection via interleaved-NUL ratio (valid UTF-8 text never contains NULs) → UTF-8 with `allowMalformed` → latin-1, which decodes any byte sequence and so is a guaranteed terminal fallback. Never throws. Accented characters may degrade in the worst case; every field extraction actually reads (flight numbers, codes, dates) is ASCII. Tests cover all six encodings plus empty/garbage input, with a UTF-16 regression test at the extractor level.

**PDF support added (2026-07-23, user request, after photo prefill was confirmed working on-device):** ML-Kit reads images only, so `PdfxPageRasterizer` (behind a `PdfPageRasterizer` seam) renders a PDF's first 3 pages to temp PNGs at 3× point size (~216dpi — 72dpi is too coarse for MRZ glyphs) via the already-present `pdfx` dependency, and `DocumentTextExtractor` routes by extension: images → recognizer directly, PDFs → rasterize-then-recognize with best-effort temp cleanup, anything else → `''`. The form now calls the extractor and no longer does its own extension gating. Tests: `document_text_extractor_test.dart` (routing, page-text joining, temp-file cleanup, failed-rasterization and unsupported-extension degradation). Real pdfx rendering itself is on-device-only (plugin), not unit-testable — verify with an actual passport PDF.

**Second on-device attempt: OCR succeeded (635 chars) but "MRZ not found" (2026-07-23).** 47 output lines revealed ML-Kit shatters a passport page into many tiny text blocks — the "two intact, adjacent MRZ lines" assumption was wrong for real photos. Parser rewritten: line 2 (which carries every validated field) is now searched for **independently** — it self-validates via check digits, so no adjacency or pairing with line 1 is assumed; line 1 (names) is a separate best-effort search and the result stands without it. Fragmentation healed by also trying joins of up to 3 consecutive MRZ-alphabet-only lines. Two-pass validation: first pass requires *both* check digits (rules out a real hazard found in dry-running — a join like `PASSPORT`+line2 shifts the birth-date field, which has its own valid check digit, into the expiry slot), single-digit validation only as a fallback when no fully-valid candidate exists. New tests: 2-way and 3-way line-2 fragmentation, MRZ lines separated by other page text.

## 5.5 Expense tracking

Fully local, no dependencies on anything else in this milestone.

Built 2026-07-23:

- [x] Drift table `Expenses` — schema **v7**. Two deliberate choices: amounts are `amountMinor` **integer minor units** (1230 = 12.30), never a float, so running totals stay exact (binary floats can't represent 0.1 and sums drift); and the trip FK is **CASCADE**, unlike `Places`' SET NULL — a wishlist place outlives its trip, a spend record without its trip is meaningless
- [x] Schema bump + migration test — `expenses_migration_test.dart` drives the real `onUpgrade` from a v6-shaped DB (drift's snapshot tooling isn't set up in this repo), asserting the new table appears, existing rows survive, raw-SQL column names match what the DAO expects, and the FK cascade actually fires. Also updated `trips_dao_test.dart`'s hardcoded "opens at v6" assertion, which the bump would otherwise have broken
- [x] `ExpenseRepository` CRUD + `ExpensesDao` (newest-date-first). Total and breakdown are **pure domain functions** (`totalMinor`, `categoryBreakdown`, `tripCurrency` in `domain/expense.dart`) over the watched list rather than extra SQL — testable without a database, and the list is already in memory
- [x] ~~v1 single-currency per trip~~ — **corrected 2026-07-23 after a real bug:** adding ₪100 then $50 reported a total of "150" in one currency. SPEC's "single-currency per trip" was an unsafe assumption; trips genuinely mix currencies and silently summing them is worse than any alternative. Totals are now grouped **per currency** (`totalsByCurrency`) and never summed across them; category breakdown lists each currency separately; every expense row shows its code; the form still pre-fills the trip's most-used currency, so the common single-currency flow is unchanged. Still no conversion (no rates, per SPEC) — two honest lines beat one invented number. Mixed trips also fall back to stable category ordering, since ranking 100 ILS against 50 USD would require rates the app deliberately doesn't have
- [x] Trip detail: third **"Spend"** tab (`TripExpensesTab`) — summary card with total + per-category breakdown sorted biggest-first, then the expense log; mono numerals throughout per the design system's data convention. Add/edit via a bottom sheet, delete inline with a snackbar
- [x] Amount input parsing is its own pure function (`parseAmountToMinor`) handling `12`, `12.3`, `12.30`, comma decimals, and rejecting negatives/over-precision/junk — validated in the form rather than silently storing a wrong number
- [x] Tests: `expense_test.dart` (parse/format round-trip, exact integer summing incl. the classic 0.1+0.2 float trap, breakdown ordering, empty cases), `expenses_dao_test.dart` (CRUD, per-trip isolation, ordering, live re-emit, currency normalization, no-op update of a missing row, trip-delete cascade, 100-row exact total), `trip_expenses_tab_test.dart` (empty state, totals/breakdown rendering, note-vs-category fallback, cross-trip isolation, delete + snackbar, error state, 150-row overflow)

**Active trips open on Spend (2026-07-23, user request):** `TripDetailScreen`'s `DefaultTabController` takes `initialIndex: 2` when `bucketTrip(...) == TripStatus.active`. Deliberately scoped to *active* only — before departure the documents tab is what you came for, and on a past trip landing on Spend would bury them. `trip_detail_screen_test.dart` pins all four bucket cases plus tab reachability, so reordering the tabs fails loudly instead of silently opening the wrong one.

### 5.5b Currency conversion (added 2026-07-23, user request)

Turns the honest-but-clunky per-currency lists into one combined figure, without breaking offline use.

- [x] **Conversion is stored per expense, not computed on read** — schema **v8** adds nullable `convertedAmountMinor` / `convertedCurrency` / `convertedRateAt` to `Expenses`. Two consequences, both good: the rate used is roughly the one that applied when the expense was added (not today's), and once converted the total needs no network ever again. Null means "not yet", never "zero" — an expense added offline simply stays blank until the next connection, exactly as asked
- [x] `ExchangeRateSource` (`open.er-api.com`, free, no key, ~160 currencies — chosen over ECB-based endpoints for travel coverage: THB, VND, AED) behind an interface, wrapped by `ExchangeRateService` with a **SharedPreferences** cache (deliberately not Drift: rates are a disposable cache and must not land in the backup archive as if they were user data). Falls back to stale cache over nothing. **Endpoint response shape unverified from the sandbox — if conversion never populates on device, check that parser first; the `[rates]` debug line prints what came back**
- [x] `ExpenseConversionService.backfill()` — converts anything lacking a home-currency value; no rates (offline/down) is a silent non-event. `clearStaleConversions()` wipes conversions pointing at a previous home currency so changing the setting recomputes rather than mixing two "home" currencies (the original bug in a new costume)
- [x] Wired in `expense_providers.dart`: backfills at startup, on any expense change (so an offline addition converts as soon as the stream re-emits after reconnect), and on home-currency change. Re-entrancy guard — writing conversions re-fires the watch that triggered the backfill
- [x] ~~Free-text 3-letter code~~ → **curated picker, both places** (2026-07-23, user request: "make the currency mistake proof"). `domain/currencies.dart` holds ~42 travel-relevant currencies with name + symbol; `showCurrencyPicker` (searchable by code/name/symbol) replaces the free-text fields in the expense form and settings. Free text let a user store `NIS` — not an ISO code at all — which saves fine and then silently fails every rate lookup forever; picking from the catalogue makes that unrepresentable. Settings picker keeps an explicit "Off" entry (= per-currency lists, no conversion)
- [x] **Zero-decimal currencies handled** — a fixed list means offering JPY/KRW/VND/CLP/ISK, which have no decimal places, and the previous code assumed 2 everywhere. `Currency.minorDigits` now drives `formatMinor`/`parseAmountToMinor` (¥1000 is 1000 minor units, not 100000; a typed "10.50" in yen is rejected rather than truncated) and — the dangerous one — `convertMinor` rescales by `10^(toDigits − fromDigits)`, without which JPY↔ILS conversion would be **wrong by 100×**. Unknown codes fall back to 2 digits so pre-picker rows still render
- [x] Tests: `currencies_test.dart` — catalogue integrity (unique/uppercase/3-letter codes, every entry named, minorDigits ∈ {0,2}), case-insensitive lookup, `NIS`/`XXX`/empty rejected, search by code/name/symbol, and the zero-decimal format/parse/convert cases including the 100× regression both directions
- [x] UI: each row shows `≈ <amount> <home>` beneath its native amount when converted and different; the summary adds an `≈` combined total plus **"N expenses not converted yet"** and a "Rates from <date>" line. Approximations never replace the exact per-currency lines, and the total reports the *oldest* rate feeding it — it's only as fresh as its stalest input
- [x] Tests: `exchange_rates_test.dart` (cross rates, identity, unknown-currency → null not a guess, rounding, all-or-nothing totals, staleness), `expense_conversion_service_test.dart` (converts, skips natives without a rate lookup, **offline leaves it null**, a later backfill fills it in, unconvertible currency stays pending, no re-conversion, home-currency-change clearing), plus `homeTotal`/`needingConversion` cases in `expense_test.dart` and a v7→v8 migration test

**Migration bug caught by the v8 test (2026-07-23) — worth remembering:** `Migrator.createTable` always builds a table at its *current* definition, not its definition as of that schema version. So `if (from < 7) createTable(expenses)` followed by `if (from < 8) addColumn(expenses, ...)` crashed with `duplicate column name` for anyone upgrading **across two versions at once** (v6 → v8) — while fresh installs and single-step upgrades passed fine, which is exactly why it would have shipped. Fixed by making create and add mutually exclusive (`else if`). The same latent overlap existed on `trips.completion_prompt_shown` for a v1 → v6+ jump and is fixed too. `expenses_migration_test.dart` now covers v6→v7, v7→v8 (against a hand-built v7-shaped table), and both multi-version jumps.

**"Why is there no conversion?" (2026-07-23) — two causes, both fixed:**
- **Discoverability, the actual answer:** conversion is off until a home currency is picked, and nothing said so — a mixed-currency trip just showed per-currency lines with no explanation. The summary card now shows "Set a home currency in Settings to see one combined total." whenever a trip mixes currencies and the setting is empty. A silent opt-in feature is indistinguishable from a broken one.
- **Real latent bug found while investigating:** `INTERNET` was declared **only** in `src/debug/AndroidManifest.xml` (the one Flutter adds for hot reload). Debug builds had network, release builds would have had none — killing map tiles, places search, Maps short-links and rates alike, with no error a user could act on. Now declared in the main manifest.
- Also added `[rates]` debug logging across the whole path (home-currency unset / pending count / rates fetched / per-expense unconvertible / converted count), mirroring the `[ocr]` diagnostics that made M5.4 debuggable.

Not verified: the live endpoint, and the rate values themselves. Worth one on-device check that a USD expense on an ILS-home trip converts to a sane number.

## 5.6 Days-traveled stat

Trivial — derived, no new entity.

Built 2026-07-23:

- [x] Pure function `daysTraveled(trips, today)` in `trips/domain/trip.dart`. Two decisions the naive `endDate - startDate` version gets wrong: **only elapsed days count** (a finished trip contributes its full length, an active one only up to today, upcoming/planned contribute nothing — otherwise "days away" counts holidays not yet taken), and **overlapping trips count a shared day once** (collects distinct dates into a Set rather than summing lengths). Open-ended trips run to today; archived trips are excluded
- [x] Third cell in the existing Places-tab stats header ("DAYS AWAY"). `placeStatsProvider` now also watches `tripListProvider` — the stat is derived from trips but shares the places header, which is the only slightly odd part of the wiring and is commented as such
- [x] Tests: `days_traveled_test.dart` — inclusive length, single-day trip, in-progress partial count, starts-today, upcoming/planned excluded, open-ended, archived excluded, additive across trips, **overlap counted once**, month boundary, leap day, and time-of-day on the clock not shifting the count. Plus a `places_screen_test.dart` case asserting the rendered figure counts past + in-progress only

## 5.7 Day-by-day itinerary builder — ~~built~~ **WITHDRAWN, currently won't do (2026-07-26)**

> Built 2026-07-23, redesigned the same day per [ADR-001](../adr/ADR-001-itinerary-redesign.md), removed 2026-07-26. Two designs were shipped and used; neither earned its place, so the Plan tab came out of the app rather than a third variant going in. Read the ADR's withdrawal note before reviving this.
>
> **All that survives in the codebase:** the `ItineraryItems` table (schema v9, no DAO, no reader — kept so no device faces a destructive migration), `itinerary_migration_test.dart`, and the schema assertion in `trips_dao_test.dart`. Trip detail is back to three tabs: Documents · Places · Spend.
>
> The checklist below is left as-is for the record — it describes code that no longer exists.

Depends on places search (already shipped, M3) so items can attach to real, located places from day one.

Built 2026-07-23:

- [x] Drift table `ItineraryItems` — schema **v9**. Deliberately separate from journal entries (forward-planning vs. backward-recording). Two field choices worth noting: the time is **`startMinutes` (int from midnight, nullable)** rather than a `DateTime`, so it can't drift out of sync with `date` or carry a bogus timezone — and plenty of plans are legitimately "sometime Tuesday"; `date` is stored normalised to midnight so a stray time component can never split one day into two groups
- [x] FK decisions: `tripId` **CASCADE** (a plan without its trip is meaningless, same as expenses), `placeId` **SET NULL** (deleting a wishlist place must not silently delete the plan that mentioned it — tested end-to-end)
- [x] Schema bump + migration test, including the v6→v9 multi-version jump that would have caught the v8 `createTable`/`addColumn` bug
- [x] Repository + DAO: CRUD, `watchForTrip` ordered date-then-index, and `setOrderIndexes` in a **transaction** (a half-applied reorder would leave the day in an order the user never chose)
- [x] Presentation: **"Plan" tab** (trip detail is now 4 tabs, scrollable). Every trip day gets a heading with its day number, **including days with nothing planned** — an itinerary that skips from day 2 to day 4 looks broken. Drag-to-reorder is scoped to **one `ReorderableListView` per day**, so an item can't be dragged into another day by accident; changing days is an explicit choice in the edit form. Optional place link resolves the stored id to a name; a trip with no dates says so rather than showing a planner it can never fill
- [x] Reorder maths is a pure function (`reorderWithinDay`) returning **only the items whose index changed** — a drag writes two rows, not the whole day. Uses `ReorderableListView.onReorderItem` (not the deprecated `onReorder`), which hands back the final index rather than the pre-removal one — so the classic off-by-one adjustment lives nowhere, and the function means exactly what its signature says
- [x] Tests: `itinerary_item_test.dart` (time formatting/parsing incl. rejecting `9:5` and `24:00`, day grouping, trip-date expansion, out-of-range dates, `nextOrderIndex` per-day, all reorder cases incl. the downward off-by-one, no-op drags, out-of-range indexes), `itinerary_dao_test.dart` (CRUD, date normalisation, per-trip isolation, live re-emit, clearing an optional field, reorder persistence, trip cascade, **place-delete keeps the plan**), `itinerary_migration_test.dart`, `trip_itinerary_tab_test.dart` (empty states incl. the no-dates case, day headings with empty days, timed vs untimed rendering, place-name resolution, ordering, delete + snackbar, error state, 60-item overflow)

**Fixed after first on-device use (2026-07-23):**
- **Dead-end CTA bug:** on a trip with no dates, the empty state's button called `Navigator.maybePop()` — literally "go back" — so tapping it bounced to the trip list and looked like the app refusing the tap. It now pushes `/trips/:id/edit` and is labelled "Add dates" instead of the vaguer "Edit".
- Tab order is now Documents · Places · Spend · **Plan** (Plan moved to last, user request), and the `TabBar` is fixed-width rather than scrollable so the four tabs share the width evenly with centred labels. `_expensesTabIndex` moved to 2 accordingly — that constant is what makes an active trip open on Spend, so the two must stay in sync.

**Superseded 2026-07-23 by [ADR-001](../adr/ADR-001-itinerary-redesign.md).** First real use showed the design's core problem wasn't the form, it was the blank page: the app already holds flight times, trip-linked wishlist places and trip dates, and asked the user to retype them. The Plan tab became a **derived timeline** — anchors computed from documents/places at read time plus stored user items, with a one-line quick-add per day.

**Withdrawn 2026-07-26.** The derived timeline fixed the tedium and still wasn't a tab worth opening, so the feature was marked *currently won't do* and removed. The useful residue is the ADR, not the code: it records why the blank page was the real problem and what the second attempt failed to answer.

## 5.8 Journal entries / timeline

Fully local, fully offline, zero cost standalone. Upgrades later once GPS tracking (M6) ships — not blocked on it.

- [ ] Drift table `JournalEntries(id, tripId, placeId nullable, timestamp, text, createdAt)`
- [ ] Photo join table mirroring `FileVaultService`'s existing file-storage pattern (M2) — reuse that pattern rather than inventing a second file-handling approach
- [ ] Schema bump + migration test
- [ ] Repository: CRUD, `watchForTrip(tripId)` ordered by timestamp, photo attach/detach
- [ ] Presentation: chronological timeline view, entry composer (text + optional photos + optional place link), per design system (Fraunces for entry text? confirm against design-critique before building — journal entries may read better in body sans than serif; check §4.3 typography intent before assuming)
- [ ] Tests: DAO CRUD + timestamp ordering; photo attach/detach reusing M2's file-storage test patterns; empty state

## 5.9 Arrival info card

Depends on 5.4 (OCR) or manually-entered document data being present — degrades gracefully if not.

- [ ] One screen: first-night address, flight number, return date — pulled from the trip's linked documents (`Document.details`)
- [ ] Missing-field handling: show what's available, quiet prompt for what isn't (never a blocked/error screen for incomplete data — this is enhancement, not a gate, per hard rule 4)
- [ ] Tests: full-data case; partial-data case; zero-linked-documents case

## 5.10 Nearby POI / restaurants / sights — configurable, cost-guarded

Same API family as the already-shipped places search. **Off by default.**

- [ ] Settings toggle, default off — confirm the toggle state gates the feature entirely (no code path reachable without it, not just a hidden UI element)
- [ ] Pull-based only: an explicit "Find nearby" button — never background refresh, never refetch-on-map-pan
- [ ] Per-location result cache (~1 hour) using the existing places API client from M3
- [ ] In-app call counter in settings, visible before a surprise bill — persisted, not session-only
- [ ] Saved results become a normal `Place` via the existing M3 wishlist flow — no new persisted entity for suggestions themselves
- [ ] Tests: toggle-off makes the feature fully unreachable (not just visually hidden); cache hit avoids a second network call within the window; call-counter increments correctly; offline fallback (quiet "unavailable offline" state, never a hanging spinner, per hard rule 4)

## 5.11 Flight/hotel email parsing — spike-gated, unpaid

**Gate before scoping real build time:** run a manual accuracy spike against 5-6 real confirmation emails. Below ~50% field-catch rate, shelve this rather than reach for a paid parsing service. Do this spike first, as a standalone throwaway script if useful — don't build the production form-prefill path until the gate passes.

- [ ] Spike: regex/heuristic extraction (PNR codes, flight numbers, dates) against real sample emails; record the actual catch rate
- [ ] **Decision point recorded here once run:** _(pending — fill in spike result before building further)_
- [ ] If gate passes: reuse existing `ACTION_SEND` share-target handler (M2.4.1) for shared email text/HTML → regex/heuristic extraction → writes into `Document.details`
- [ ] Always "review before saving" — never silent auto-fill, matching the OCR prefill precedent from 5.4
- [ ] Tests (if built): extraction accuracy against a fixed fixture set of sample emails; garbage-input doesn't crash; review-before-save flow

## 5.12 Transport/booking deep-links

- [ ] Outbound links only (Omio/Skyscanner-style) — not in-app booking, no new permission/API surface
- [ ] Tests: link construction correctness; missing-data fallback (no dead-end blank links)

## 5.13 Trip sharing/export (PDF)

Deliberately static/one-shot, not live — SPEC is explicit this is intentional, not a stopgap.

- [ ] PDF generation from trip data (itinerary, places, journal highlights — scope exact contents against design-critique before building the full layout)
- [ ] Export via OS share sheet (reuse `share_plus`, already a dependency from M4's backup export)
- [ ] Tests: PDF generation doesn't crash on a minimal trip (no places/journal/itinerary yet) or a maximal one; share-sheet invocation mocked in tests, never actually shared

## 5.14 Hebrew localization + full RTL pass

Deliberately last — sweeps over whatever ARB strings and layouts 5.1–5.13 added, so doing it earlier means redoing it.

- [ ] Hebrew translations for every string added across this milestone plus everything already in `app_en.arb`
- [ ] RTL layout audit: confirm `EdgeInsetsDirectional`/start-end conventions (CLAUDE.md hard rule 3) actually hold under RTL for every screen touched this milestone, not just new ones
- [ ] Tests: golden tests re-run under RTL for any component whose layout isn't purely symmetric

---

## Tests (cross-cutting, applies to every sub-milestone above)

Same conventions as M0–M4 (full rules in `M4-polish.md`'s Testing & CI section) — called out again here because Phase 2a is the first milestone with real network-touching surfaces beyond map tiles/short-links:

- [ ] Every network call (nearby POI, email-parsing short-link resolves if any) has a mocked-boundary test and a tested offline-fallback — no real network in any test
- [ ] Every new Drift table ships its schema bump + migration test in the same commit
- [ ] Widget tests mock at the repository boundary, not the DAO
- [ ] Notification scheduling never touches the real OS notification tray in tests — fake plugin implementation throughout

## Watch out for

- Notification IDs colliding across trigger types if the derivation scheme isn't actually collision-proof — test this explicitly, don't assume
- Android 13+ requires runtime `POST_NOTIFICATIONS` permission separately from scheduling exact alarms — both need handling, and both can be denied independently
- OCR/MRZ parsing on real passport photos will have real accuracy limits ML-Kit's on-device model won't match a cloud OCR service — set expectations in UI copy, don't oversell
- Nearby POI's cost guard is only real if the "off by default + no code path reachable" claim is actually tested, not just assumed from the toggle's default value
- Email-parsing gate: don't let sunk cost turn a failed spike into "well, let's build it anyway" — the ~50% threshold was set for a reason
