# M2 — Document vault

**Goal:** attach files or manual records to trips, keep a global vault for documents that outlive trips (passport, license, insurance), pinned quick-access, expiry warnings. Your top-priority feature — this milestone gets the deepest test coverage.

**Exit criteria:** attach a PDF to a trip and open it; passport lives in global vault, linked into a trip, shows rust expiry warning; pinned docs open ≤2 taps from launch; goldens for every card category; CI green.

## 2.1 Data layer (`lib/features/vault/data/`)

- [ ] Drift table `Documents`: `id`, `title`, `category` (enum: passportId, visa, flight, stay, insurance, transport, other), `filePath` (nullable — manual records have no file), `mimeType` (nullable), `expiryDate` (nullable), `isGlobal` (bool), `isPinned` (bool), `createdAt`, plus category-specific JSON `details` column (flight number, confirmation code, check-in/out dates…) — one flexible column beats seven sparse tables at this scale
- [ ] Join table `TripDocuments (tripId, documentId)` — a global doc links into many trips without file duplication; PK on the pair
- [ ] Schema v3 + migration test
- [ ] `DocumentsDao`: CRUD, `watchForTrip(tripId)`, `watchGlobal()`, `watchPinned()`, link/unlink
- [ ] `DocumentRepository` + domain model

## 2.2 File storage service (`lib/core/files/`)

- [ ] `FileVaultService`: `import(sourcePath) → vaultPath` — copies picked file into `{appDocs}/vault/{uuid}.{ext}`; original never referenced (content-URI paths from pickers are ephemeral on Android)
- [ ] `delete(vaultPath)` — removes file; called only when the *document* is deleted, and only if no other links remain
- [ ] Orphan sweep on startup (files with no DB row → delete; rows with no file → flag "file missing" state on the card)
- [ ] Size guard: warn above ~20MB per file
- [ ] Deps added now: `file_picker` (pick), `open_filex` (view via OS default app — no in-app PDF renderer in MVP)

## 2.3 Domain logic

- [ ] `ExpiryChecker` — pure, clock-injected: `expired`, `expiringSoon(withinDays: 90)`, and trip-aware `riskyForTrip(doc, trip)` = expiry before `trip.endDate + 90 days` (passport six-month-rule approximation; the 90 is a named constant to tune)
- [ ] Pinning rules: max 4 pinned; "Next flight" pin auto-derives from the soonest upcoming flight doc with a departure datetime in `details`

## 2.4 Presentation (`lib/features/vault/presentation/`)

- [ ] `VaultScreen` (tab 2): PINNED grid (white cards, 1px teal border — per revised mockup) then ALL DOCUMENTS grouped list; upload action in header
- [ ] `DocumentFormSheet` — bottom sheet: pick file *or* manual entry; category picker drives which detail fields show (flight → flight no./conf code/times; stay → name/dates/booking ref; passport → number/expiry)
- [ ] Category card widgets, one per category, shared anatomy (category label + icon top-left, status right, serif title, mono metadata row) — Omio pattern. Flight card gets the `TLV ---✈--- BKK` route row
- [ ] Expiry warning: rust border + rust chip on card; warning banner inside trip detail when any linked doc is `riskyForTrip`
- [ ] Trip detail → Documents tab (fills M1 shell): linked docs + "link from vault" + "add new"
- [ ] Missing-file state card (gray, "file missing — re-attach")

## 2.4.1 Android share target

- [ ] Register Tripper for `ACTION_SEND` (`application/pdf`, `image/*`) via `receive_sharing_intent` (or manifest + method channel if the package is stale — verify maintenance before adopting)
- [ ] Shared file → "Save to vault" sheet: trip picker (defaults to active trip), category picker, title prefilled from filename → imports through `FileVaultService`
- [ ] Cold-start and warm-start share paths both handled (Android delivers them differently)

## 2.4.2 "Show code" mode

- [ ] Flight/transport/other cards with an image or PDF: on save, scan for QR/barcode via `google_mlkit_barcode_scanning` on a rendered page image; store extracted code payload + format in `details`
- [ ] `ShowCodeScreen`: full-screen re-rendered barcode/QR (`barcode_widget`), white background, forces max brightness (`screen_brightness`), keeps screen awake; one tap from pinned card ("Next flight" pin opens straight here when a code exists)
- [ ] Fallback when no code detected: full-screen image/PDF page view instead — same one-tap path

## 2.4.3 Biometric vault lock

- [ ] `local_auth` gate: opening Vault tab or any document prompts fingerprint/face; session stays unlocked 2 minutes (re-auth after background > 2 min)
- [ ] Graceful fallback to device PIN; if no device lock configured, vault opens with a one-time "your device has no lock screen" notice
- [ ] Setting to disable (default on)
- [ ] Lock applies to documents opened from trip detail too, not just the Vault tab

## 2.5 Tests

Unit:

- [ ] `ExpiryChecker` boundaries: expiry on trip end, +89/90/91 days, null expiry, expired today
- [ ] `FileVaultService` with temp dirs: import copies + renames; delete respects remaining links; orphan sweep both directions
- [ ] DAO: link/unlink, global vs trip queries, pinned cap, cascade rules (deleting trip unlinks but never deletes docs — decision from M1)
- [ ] `details` JSON roundtrip per category

Widget:

- [ ] Vault screen: empty / pinned-only / full; pinned tap opens viewer intent (mock `open_filex`)
- [ ] Form sheet: category switch swaps detail fields; manual record saves without file
- [ ] Trip Documents tab: shows linked, link-from-vault flow

Golden:

- [ ] All 7 category cards + expiry-warning variant + missing-file variant, light + dark (this is the app's visual core — goldens earn their keep here)

- [ ] Share-sheet save flow with a faked incoming intent; barcode extraction on fixture images (QR, PDF417 boarding pass, none-present)
- [ ] Vault lock: locked state blocks document open; unlock session expiry logic (clock-injected)

Integration (`integration_test/`):

- [ ] Create trip → add flight doc (manual) → pin it → relaunch-simulated cold open → open from pinned in 2 taps
- [ ] Biometric flow on emulator with test credentials (or mock `local_auth` platform channel)

## Watch out for

- Android storage: app-private dir needs no permissions — do **not** add `MANAGE_EXTERNAL_STORAGE`; `file_picker` handles SAF
- Backup semantics: app-private files are lost on uninstall — surface this honestly in UI copy ("stored only on this device"); cloud backup is Phase 3
- `open_filex` needs a `FileProvider` entry in the Android manifest to share private files with viewer apps
