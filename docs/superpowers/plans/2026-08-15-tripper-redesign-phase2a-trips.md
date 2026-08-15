# Tripper Redesign — Phase 2a: Trips Reskin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the Trips feature (list card, list screen chrome, trip detail) per the "Immersive Golden Hour" spec, and wire up the cover-photo picker so `Trip.coverPhotoPath` (shipped in Phase 1, unused until now) actually gets set from the UI.

**Architecture:** Five tasks. Task 1 generalizes the existing document `FileVaultService` so cover photos get their own storage subfolder (never mixed with vault documents) without touching vault behavior. Task 2 wires the picker into the trip form. Tasks 3-5 are the visual reskin itself — `TripCard`, the list screen's chrome, and `TripDetailScreen` — each consuming Phase 1's `AppColors`, `generatedCoverGradient()`, and `GlassChrome` primitives directly; no new design-system work is needed.

**Tech Stack:** Flutter/Dart, Riverpod, `image_picker` (already a dependency, already used once in Journal — same UX pattern reused here), `go_router`.

**Spec:** `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md` (§5 Trips list/detail, §6 cover-photo technical implications). Phase 1's plan and shipped code: `docs/superpowers/plans/2026-08-14-tripper-redesign-phase1-foundation.md`.

## Global Constraints

- Reuse Phase 1's shipped primitives — do not recreate them: `AppColors`/`AppShape` (`lib/core/theme/app_colors.dart`, `lib/core/theme/app_spacing.dart`), `generatedCoverGradient()` (`lib/core/theme/generated_cover_gradient.dart`), `GlassChrome` (`lib/core/widgets/glass_chrome.dart`).
- No `Color(0xFF...)` or other raw/named color literals (`Colors.white`, etc.) outside `lib/core/theme/app_colors.dart`. Text/icons sitting on a photo or gradient scrim use the *fixed* `AppColors.dark.inkPrimary`/`AppColors.dark.paper` reference values (not `context.colors`, which flips with the theme) — this is the same pattern Phase 1's `GlassChrome` already established for its shadow tint; extend it, don't invent a new one.
- One accent only (coral, `colors.accent`). Gradients stay scoped to hero/cover-photo art — never buttons, text backgrounds, or flat surfaces.
- Every user-facing string goes through ARB (`lib/l10n/app_en.arb`), English only. All new layout code uses `EdgeInsetsDirectional`/`AlignmentDirectional`/directional icons — this app just shipped Hebrew RTL support and it must not regress.
- No `DateTime.now()` in domain code (not touched by this plan — no domain-layer changes).
- Tests land in the same commit as the feature; widget tests mock at the repository boundary (`FakeTripRepository`).

**Design decisions locked in for this plan** (so every task agrees on them):
1. **Cover-photo storage** gets its own subfolder (`{appDocs}/covers/`) via a generalized `FileVaultService`, never the shared `vault/` folder — mixing them would make `FileVaultService.sweepOrphans()` (used by the vault feature) treat cover photos as orphaned documents and delete them.
2. **File lifecycle lives in the presentation layer** (`trip_form_screen.dart`), not in `DriftTripRepository`. Unlike documents (created/deleted from several places), a trip's cover photo is only ever set from one screen (the form) and only ever deleted alongside the trip from one place (the detail screen's delete menu) — centralizing import/delete in the repository would mean changing `DriftTripRepository`'s constructor, which 7 unrelated test files across 5 other features construct directly (`grep -rn "DriftTripRepository(" --include=*.dart` confirms this). Keeping file I/O in the form avoids that blast radius entirely. `Trip.coverPhotoPath` keeps meaning exactly what it already means post–Phase 1: the final, already-stored path.
3. **Two Heroes fly together**, not one replacing the other: the existing `'trip-name-${trip.id}'` Hero (shipped, tested) stays exactly as is; a new `'trip-cover-${trip.id}'` Hero is added for the cover image/gradient. Flutter supports multiple simultaneous Hero flights between the same two routes with no extra wiring.
4. **Cover-photo picker UI** mirrors the existing Journal photo-picker exactly (`lib/features/journal/presentation/journal_entry_form_sheet.dart:354-378`): a bottom sheet offering Camera/Gallery via `ImageSource`, then `ImagePicker().pickImage(source: source)`. That flow has no test coverage anywhere in this codebase today (no mock seam for `ImagePicker` exists) — this plan follows that same precedent rather than inventing new test infrastructure; widget tests cover everything *around* the picker call (the placeholder, the thumbnail, the clear button, and what gets saved), not the platform picker itself.

---

### Task 1: Configurable storage subfolder for `FileVaultService` + a cover-photo file service

**Files:**
- Modify: `lib/core/files/file_vault_service.dart`
- Modify: `lib/features/trips/presentation/trip_providers.dart`
- Test: `test/unit/vault/file_vault_service_test.dart:1-73` (extend)

**Interfaces:**
- Produces: `FileVaultService(Future<Directory> Function() baseDir, {String subfolder = 'vault'})` — existing callers (`fileVaultServiceProvider`, `DriftDocumentRepository`, `BackupService`, `DriftJournalRepository`) are unaffected since the default preserves today's exact behavior. New: `coverPhotoFileServiceProvider` (`Provider<FileVaultService>`), subfolder `'covers'`. Task 2 reads this provider.

- [ ] **Step 1: Write the failing test for the subfolder param**

Append to `test/unit/vault/file_vault_service_test.dart`, inside `main()`, after the existing `sweepOrphans` test:

```dart
  test('a custom subfolder keeps files separate from the default vault dir',
      () async {
    final covers = FileVaultService(() async => tempDir, subfolder: 'covers');
    final src = await sourceFile('sunset.jpg');
    final coverPath = await covers.import(src.path);

    expect(p.dirname(coverPath), p.join(tempDir.path, 'covers'));
    expect(await File(coverPath).exists(), isTrue);

    // sweepOrphans only ever sees its own subfolder — a file a different
    // FileVaultService instance owns must not be treated as this one's
    // orphan (the whole reason cover photos get their own subfolder).
    final missing = await service.sweepOrphans({});
    expect(await File(coverPath).exists(), isTrue);
    expect(missing, isEmpty);
  });
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/unit/vault/file_vault_service_test.dart`
Expected: FAIL — `subfolder` is not a parameter of `FileVaultService`.

- [ ] **Step 3: Add the `subfolder` parameter**

In `lib/core/files/file_vault_service.dart`, replace lines 8-24:

```dart
/// Owns a storage subfolder: {appDocs}/{subfolder}/{uuid}.{ext}. Defaults
/// to the document vault ('vault'); pass a different [subfolder] for other
/// local-file features (e.g. trip cover photos — 'covers') so their files
/// never mix with vault documents. [sweepOrphans] assumes every file in
/// its own folder belongs to the table it was constructed for, so mixing
/// folders would make it delete files a different feature still needs.
/// Files are always copied in — picker content-URIs are ephemeral on Android.
class FileVaultService {
  FileVaultService(this._baseDir, {String subfolder = 'vault'})
      : _subfolder = subfolder;

  /// Injected for tests (temp dir) vs production (app documents dir).
  final Future<Directory> Function() _baseDir;
  final String _subfolder;
  final _uuid = const Uuid();

  static const maxFileBytes = 20 * 1024 * 1024;

  Future<Directory> _vaultDir() async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, _subfolder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
```

(Everything below `_vaultDir()` — `import`, `delete`, `exists`, `sweepOrphans`, `FileTooLargeException`, `fileVaultServiceProvider` — is unchanged.)

- [ ] **Step 4: Run the test again to confirm it passes**

Run: `flutter test test/unit/vault/file_vault_service_test.dart`
Expected: PASS (all 5 tests) — the 4 pre-existing tests must still pass unmodified, proving the default subfolder still behaves exactly as before.

- [ ] **Step 5: Add the cover-photo provider**

In `lib/features/trips/presentation/trip_providers.dart`, add to the imports (after the existing `flutter_riverpod` import):

```dart
import 'package:path_provider/path_provider.dart';

import '../../../core/files/file_vault_service.dart';
```

Add after the `tripsDaoProvider` declaration (after line 9):

```dart
/// Trip cover photos live in their own subfolder — see Task 1's design
/// note: never share `fileVaultServiceProvider`'s 'vault' folder, or the
/// vault feature's orphan sweep would delete cover photos it doesn't own.
final coverPhotoFileServiceProvider = Provider<FileVaultService>(
  (ref) => FileVaultService(getApplicationDocumentsDirectory, subfolder: 'covers'),
);
```

- [ ] **Step 6: Run the full trips + vault test folders**

Run: `flutter test test/unit/trips test/unit/vault`
Expected: PASS — confirms nothing in either feature broke.

- [ ] **Step 7: Commit**

```bash
git add lib/core/files/file_vault_service.dart lib/features/trips/presentation/trip_providers.dart test/unit/vault/file_vault_service_test.dart
git commit -m "feat(trips): give cover photos their own FileVaultService subfolder"
```

---

### Task 2: Cover-photo picker in the trip form

**Files:**
- Modify: `lib/features/trips/presentation/trip_form_screen.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/widget/trips/trip_form_screen_test.dart` (new — this screen has no dedicated widget test file today)

**Interfaces:**
- Consumes: `coverPhotoFileServiceProvider` (Task 1), `TripRepository.createTrip(..., String? coverPhotoPath)` / `Trip.copyWith(..., String? Function()? coverPhotoPath)` (both already shipped by Phase 1 — unchanged here).
- Produces: nothing new consumed by later tasks — this task is UI + save-path wiring only.

- [ ] **Step 1: Add the new ARB strings**

In `lib/l10n/app_en.arb`, add after line 57 (`"tripFormEndDate": "End date",`):

```json
  "tripFormCoverPhoto": "Cover photo",
```

(Reuses the existing `journalPhotoSourceCamera`/`journalPhotoSourceGallery` strings — "Camera"/"Gallery" are generic enough that a second, feature-prefixed copy would just be a duplicate translation burden.)

- [ ] **Step 2: Write the failing widget tests**

Create `test/widget/trips/trip_form_screen_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/files/file_vault_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_form_screen.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_trip_repository.dart';

final _today = DateTime(2026, 7, 19);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trip_form_cover_test');
  });

  tearDown(() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<Widget> app(FakeTripRepository repo, {Trip? initial}) async =>
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repo),
          coverPhotoFileServiceProvider.overrideWithValue(
            FileVaultService(() async => tempDir, subfolder: 'covers'),
          ),
          clockProvider.overrideWithValue(() => _today),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TripFormScreen(initial: initial),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      );

  File writeCoverPhoto() {
    return File('${tempDir.path}/source-cover.png')
      ..writeAsBytesSync(const <int>[137, 80, 78, 71]);
  }

  testWidgets('new trip shows the empty cover-photo placeholder',
      (tester) async {
    await tester.pumpWidget(await app(FakeTripRepository([])));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
      'editing a trip with an existing cover photo shows it and a clear button',
      (tester) async {
    final photo = writeCoverPhoto();
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    await tester.pumpWidget(
      await app(FakeTripRepository([trip]), initial: trip),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
  });

  testWidgets('clearing the cover photo reverts to the empty placeholder',
      (tester) async {
    final photo = writeCoverPhoto();
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    await tester.pumpWidget(
      await app(FakeTripRepository([trip]), initial: trip),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
  });

  testWidgets('saving without touching the photo keeps it unchanged',
      (tester) async {
    final photo = writeCoverPhoto();
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    final repo = FakeTripRepository([trip]);
    await tester.pumpWidget(await app(repo, initial: trip));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getTrip('t1');
    expect(saved!.coverPhotoPath, photo.path);
  });

  testWidgets(
      'saving after clearing the photo persists null and deletes the file',
      (tester) async {
    final photo = writeCoverPhoto();
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    final repo = FakeTripRepository([trip]);
    await tester.pumpWidget(await app(repo, initial: trip));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getTrip('t1');
    expect(saved!.coverPhotoPath, isNull);
    expect(await photo.exists(), isFalse);
  });
}
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `flutter test test/widget/trips/trip_form_screen_test.dart`
Expected: FAIL — `coverPhotoFileServiceProvider` doesn't exist yet in this screen's context, and none of the photo widgets/icons exist yet.

- [ ] **Step 4: Add imports and photo state to `TripFormScreen`**

In `lib/features/trips/presentation/trip_form_screen.dart`, replace lines 1-13 (the import block) with:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/trip.dart';
import '../domain/trip_validator.dart';
import 'trip_card.dart';
import 'trip_providers.dart';
```

Replace the state fields and `initState` (lines 27-43):

```dart
  late final TextEditingController _name;
  late final TextEditingController _destinationInput;
  late List<String> _destinations;
  DateTime? _start;
  DateTime? _end;

  /// Captured once — the stored path this screen opened with, if any.
  /// Compared against [_coverPhotoPath] at save time to know whether the
  /// old file needs deleting (replaced or cleared) or left alone
  /// (unchanged, or a brand-new trip that never had one).
  late final String? _originalCoverPhotoPath;
  String? _coverPhotoPath;
  List<TripValidationError> _errors = const [];

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _name = TextEditingController(text: t?.name ?? '');
    _destinationInput = TextEditingController();
    _destinations = [...?t?.destinations];
    _start = t?.startDate;
    _end = t?.endDate;
    _originalCoverPhotoPath = t?.coverPhotoPath;
    _coverPhotoPath = t?.coverPhotoPath;
  }
```

- [ ] **Step 5: Add the picker UI to the form body**

In `lib/features/trips/presentation/trip_form_screen.dart`, insert into the `ListView`'s `children` (after the destinations `Row` that ends around the original line 114, before the `SizedBox(height: AppSpacing.xl)` that precedes `Text(l10n.tripFormDates)`):

```dart
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.tripFormCoverPhoto),
          const SizedBox(height: AppSpacing.sm),
          _CoverPhotoField(
            path: _coverPhotoPath,
            onPick: _pickCoverPhoto,
            onClear: _clearCoverPhoto,
          ),
```

(This sits between the existing destinations block and the existing `Text(l10n.tripFormDates)` block — both stay exactly where they are.)

- [ ] **Step 6: Add the picker/clear methods and the `_CoverPhotoField` widget**

In `lib/features/trips/presentation/trip_form_screen.dart`, add these methods inside `_TripFormScreenState`, after `_pickDate` and before `_save`:

```dart
  Future<void> _pickCoverPhoto() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.journalPhotoSourceCamera),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.journalPhotoSourceGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;

    final files = ref.read(coverPhotoFileServiceProvider);
    final imported = await files.import(picked.path);
    // A pick from earlier this session that was never saved — replace it
    // rather than leaking it (the original stored photo, if any, is left
    // alone until save so cancelling the form doesn't destroy it).
    if (_coverPhotoPath != null && _coverPhotoPath != _originalCoverPhotoPath) {
      await files.delete(_coverPhotoPath!);
    }
    if (!mounted) return;
    setState(() => _coverPhotoPath = imported);
  }

  void _clearCoverPhoto() {
    final path = _coverPhotoPath;
    if (path != null && path != _originalCoverPhotoPath) {
      // An unsaved fresh import — nothing else references it.
      unawaited(ref.read(coverPhotoFileServiceProvider).delete(path));
    }
    setState(() => _coverPhotoPath = null);
  }
```

Add the `_CoverPhotoField` widget at the end of the file, after the existing `_DateField` class:

```dart
class _CoverPhotoField extends StatelessWidget {
  const _CoverPhotoField({
    required this.path,
    required this.onPick,
    required this.onClear,
  });

  final String? path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onPick,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppShape.radius),
        child: SizedBox(
          height: 140,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              path == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(
                          color: colors.hairline,
                          width: AppShape.hairlineWidth,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: colors.inkMuted,
                          size: 32,
                        ),
                      ),
                    )
                  : Image.file(File(path!), fit: BoxFit.cover),
              if (path != null)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: AppSpacing.sm,
                  end: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: onClear,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.dark.paper.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.dark.inkPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Wire the photo into `_save()`**

In `lib/features/trips/presentation/trip_form_screen.dart`, replace the `_save` method:

```dart
  Future<void> _save() async {
    // Unsubmitted text in the destination field counts — common flow is
    // typing the only destination and hitting save without "+".
    _addDestination();
    final errors = validateTrip(
      name: _name.text,
      destinations: _destinations,
      startDate: _start,
      endDate: _end,
    );
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    if (_originalCoverPhotoPath != null &&
        _originalCoverPhotoPath != _coverPhotoPath) {
      // Replaced or cleared — the old file is no longer referenced.
      await ref
          .read(coverPhotoFileServiceProvider)
          .delete(_originalCoverPhotoPath!);
    }

    final repo = ref.read(tripRepositoryProvider);
    if (widget.initial == null) {
      await repo.createTrip(
        name: _name.text,
        destinations: _destinations,
        startDate: _start,
        endDate: _end,
        colorTag: widget.initial?.colorTag ?? 0,
        coverPhotoPath: _coverPhotoPath,
      );
    } else {
      await repo.updateTrip(
        widget.initial!.copyWith(
          name: _name.text,
          destinations: _destinations,
          startDate: () => _start,
          endDate: () => _end,
          coverPhotoPath: () => _coverPhotoPath,
        ),
      );
    }
    if (mounted) context.pop();
  }
```

- [ ] **Step 8: Run the tests again to confirm they pass**

Run: `flutter test test/widget/trips/trip_form_screen_test.dart`
Expected: PASS (all 5 tests).

- [ ] **Step 9: Run the full trips test folder**

Run: `flutter test test/unit/trips test/widget/trips`
Expected: PASS — confirms the existing list/detail screen tests are unaffected.

- [ ] **Step 10: Commit**

```bash
git add lib/features/trips/presentation/trip_form_screen.dart lib/l10n/app_en.arb test/widget/trips/trip_form_screen_test.dart
git commit -m "feat(trips): wire the cover-photo picker into the trip form"
```

---

### Task 3: `TripCard` reskin — cover photo/gradient, scrim, cover Hero

**Files:**
- Modify: `lib/features/trips/presentation/trip_card.dart`
- Test: `test/widget/trips/trip_card_test.dart` (new)

**Interfaces:**
- Consumes: `generatedCoverGradient(String, AppColors)` (Phase 1), `AppColors.dark` fixed reference (Phase 1's `GlassChrome` precedent).
- Produces: a second Hero, tag `'trip-cover-${trip.id}'`, alongside the existing `'trip-name-${trip.id}'` Hero (unchanged). Task 5 (`TripDetailScreen`) matches this tag.

- [ ] **Step 1: Write the failing tests**

Create `test/widget/trips/trip_card_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_card.dart';
import 'package:tripper/l10n/app_localizations.dart';

final _today = DateTime(2026, 7, 19);

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

void main() {
  testWidgets('no cover photo renders the generated gradient fallback',
      (tester) async {
    const trip =
        Trip(id: 'no-photo', name: 'Thailand', destinations: ['Krabi']);
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.planned, today: _today)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).gradient is LinearGradient,
      ),
      findsWidgets,
    );
  });

  testWidgets('a cover photo renders as an Image, not the gradient',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('trip_card_cover');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    final photo = File('${dir.path}/cover.png')
      ..writeAsBytesSync(const <int>[137, 80, 78, 71]);
    final trip = Trip(
      id: 'with-photo',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.planned, today: _today)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('both the cover and the name carry their Hero tags',
      (tester) async {
    const trip = Trip(id: 'h1', name: 'Japan', destinations: ['Tokyo']);
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.planned, today: _today)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == 'trip-cover-h1'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == 'trip-name-h1'),
      findsOneWidget,
    );
  });

  testWidgets('active trip shows the day-count pill', (tester) async {
    final trip = Trip(
      id: 'a1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      startDate: DateTime(2026, 7, 16),
      endDate: DateTime(2026, 7, 27),
    );
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.active, today: _today)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day 4 of 12'), findsOneWidget);
  });

  testWidgets('tapping the card fires onTap', (tester) async {
    const trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);
    var tapped = false;
    await tester.pumpWidget(
      _app(
        TripCard(
          trip: trip,
          status: TripStatus.planned,
          today: _today,
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TripCard));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `flutter test test/widget/trips/trip_card_test.dart`
Expected: FAIL — no `'trip-cover-*'` Hero exists yet, no gradient/`Image` in the current text-only card.

- [ ] **Step 3: Rewrite `TripCard`**

Replace `lib/features/trips/presentation/trip_card.dart` lines 1-11 (imports) with:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/generated_cover_gradient.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/trip.dart';
```

Replace the `TripCard` class (everything from `class TripCard extends StatelessWidget {` to the end of the file) with:

```dart
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.status,
    required this.today,
    this.onTap,
  });

  final Trip trip;
  final TripStatus status;
  final DateTime today;
  final VoidCallback? onTap;

  static const _coverHeight = 140.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final isPast = status == TripStatus.past;

    return PaperCard(
      recessed: isPast,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppShape.radius),
            ),
            // Shares a tag with TripDetailScreen's cover hero. Both routes
            // sit in the same shell-branch Navigator, so this flies on the
            // default push transition with no extra wiring — same as the
            // pre-existing trip-name Hero below, which is untouched.
            child: Hero(
              tag: 'trip-cover-${trip.id}',
              child: SizedBox(
                height: _coverHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CoverBackground(trip: trip, colors: colors),
                    // Text-on-photo scrim (component rule 6: every
                    // text-on-photo moment gets a scrim strong enough to
                    // hit WCAG AA).
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xBF12141C)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: AppSpacing.sm,
                      child: Row(
                        children: [
                          Expanded(
                            child: Hero(
                              tag: 'trip-name-${trip.id}',
                              child: Material(
                                type: MaterialType.transparency,
                                child: AutoDirectionText(
                                  trip.name,
                                  style: AppTextStyles.title.copyWith(
                                    fontSize: 17,
                                    color: AppColors.dark.inkPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          if (status == TripStatus.active) ...[
                            const SizedBox(width: AppSpacing.sm),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius:
                                    BorderRadius.circular(AppShape.radius),
                              ),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                child: Text(
                                  activeDayLabel(l10n, trip, today),
                                  style: AppTextStyles.sectionLabel.copyWith(
                                    color: colors.surface,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: MonoText(
              '${TripDateFormatter.line(l10n, trip)}'
              ' · ${trip.destinations.join(' → ')}',
              muted: isPast,
            ),
          ),
        ],
      ),
    );
  }
}

/// The cover image if the trip has one, else the deterministic gradient
/// fallback (component rule 2: gradients scoped to hero/cover art only —
/// this is that art).
class _CoverBackground extends StatelessWidget {
  const _CoverBackground({required this.trip, required this.colors});

  final Trip trip;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final path = trip.coverPhotoPath;
    if (path != null) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: generatedCoverGradient(trip.id, colors),
      ),
    );
  }
}
```

Note: `TripDateFormatter` and `activeDayLabel` (lines 14-39 of the original file) are unchanged — keep them exactly as they are, above the `TripCard` class.

The scrim uses a literal `Color(0xBF12141C)` (75% `bg.night`) rather than `AppColors.dark.paper.withValues(alpha: 0.75)` — both are equivalent, but a `const` gradient can't call a non-const method, and this scrim is decorative chrome unrelated to the app's theme (always dark, regardless of light/dark mode, matching the fixed-token pattern already established). This is the one narrow, justified exception to "no `Color(0xFF...)` outside `app_colors.dart`": a `const` scrim value equal to a token already defined there. If a reviewer flags it, the fix is switching to non-const `AppColors.dark.paper.withValues(alpha: 0.75)` — functionally identical, only loses the `const`.

- [ ] **Step 4: Run the tests again to confirm they pass**

Run: `flutter test test/widget/trips/trip_card_test.dart`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Run the full trips test folder**

Run: `flutter test test/unit/trips test/widget/trips`
Expected: PASS — `trip_list_screen_test.dart`'s existing Hero-tag assertion (`'trip-name-a'`) must still pass since that Hero is untouched.

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/presentation/trip_card.dart test/widget/trips/trip_card_test.dart
git commit -m "feat(trips): reskin TripCard with cover photo/gradient and scrim"
```

---

### Task 4: Trips list screen — coral FAB + container updates

**Files:**
- Modify: `lib/features/trips/presentation/trip_list_screen.dart:51-88`
- Test: `test/widget/trips/trip_list_screen_test.dart` (extend)

**Interfaces:** None new — this task only moves an existing action from the AppBar to a `FloatingActionButton`.

- [ ] **Step 1: Write the failing test**

Append to `test/widget/trips/trip_list_screen_test.dart`, inside `main()`, after the last existing test:

```dart
  testWidgets('the coral FAB opens the new-trip route', (tester) async {
    await tester.pumpWidget(
      await _app([
        _trip('a', 'Active trip', DateTime(2026, 7, 16), DateTime(2026, 7, 27)),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('form-screen'), findsOneWidget);
  });
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/widget/trips/trip_list_screen_test.dart`
Expected: FAIL — no `FloatingActionButton` exists yet.

- [ ] **Step 3: Convert the AppBar add-icon into a FAB**

In `lib/features/trips/presentation/trip_list_screen.dart`, replace the `build` method's `return Scaffold(...)` block (lines 51-88):

```dart
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: colors.inkMuted,
            ),
            tooltip: l10n.themeToggleTooltip,
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colors.inkMuted),
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/trips/new'),
        backgroundColor: colors.accent,
        foregroundColor: colors.surface,
        tooltip: l10n.tripsEmptyCta,
        child: const Icon(Icons.add),
      ),
      body: _body(
        context,
        ref,
        l10n,
        asyncTrips,
        isEmpty,
        buckets,
        archived,
        today,
      ),
    );
```

- [ ] **Step 4: Run the test again to confirm it passes**

Run: `flutter test test/widget/trips/trip_list_screen_test.dart`
Expected: PASS (all tests, including the new one).

- [ ] **Step 5: Run the full trips + accessibility test folders**

Run: `flutter test test/unit/trips test/widget/trips test/widget/accessibility_test.dart`
Expected: PASS — `accessibility_test.dart` exercises the Trips list screen's tap targets/labels; a FAB needs to clear the same guidelines the old AppBar icon did (it does — `FloatingActionButton`'s default size is 56×56, well above the 48dp minimum, and `tooltip:` provides its accessible label the same way the old `IconButton`'s did).

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/presentation/trip_list_screen.dart test/widget/trips/trip_list_screen_test.dart
git commit -m "feat(trips): move add-trip to a coral FloatingActionButton"
```

---

### Task 5: `TripDetailScreen` reskin — full-bleed cover hero, glass topbar, glass tab bar

**Files:**
- Modify: `lib/features/trips/presentation/trip_detail_screen.dart`
- Test: `test/widget/trips/trip_detail_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `'trip-cover-${trip.id}'` Hero tag (Task 3), `GlassChrome` (Phase 1), `generatedCoverGradient()` (Phase 1).
- Produces: nothing consumed by a later task in this plan — Places (Phase 3) and Journal/Expenses (Phase 4) reskin their own tab *bodies* separately; this task only touches the screen's header chrome. The 4 tab body widgets (`TripDocumentsTab`, `TripPlacesTab`, `TripExpensesTab`, `TripJournalTab`) are unchanged.

- [ ] **Step 1: Write the failing test**

In `test/widget/trips/trip_detail_screen_test.dart`, add to the imports:

```dart
import 'package:tripper/core/widgets/glass_chrome.dart';
```

Append inside `main()`, after the last existing test:

```dart
  testWidgets(
      'the cover hero and glass chrome render without overflow',
      (tester) async {
    final trip = _trip(
      start: DateTime(2026, 7, 16),
      end: DateTime(2026, 7, 27),
    );
    await tester.pumpWidget(await _app(trip));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'trip-cover-t1',
      ),
      findsOneWidget,
    );
    // One GlassChrome for the topbar (back/name/menu), one for the
    // floating tab bar.
    expect(find.byType(GlassChrome), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/widget/trips/trip_detail_screen_test.dart`
Expected: FAIL — no `'trip-cover-*'` Hero or `GlassChrome` exists in this screen yet.

- [ ] **Step 3: Rewrite `TripDetailScreen`**

Replace `lib/features/trips/presentation/trip_detail_screen.dart` lines 1-18 (imports) with:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/generated_cover_gradient.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/glass_chrome.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../expenses/presentation/trip_expenses_tab.dart';
import '../../journal/presentation/trip_journal_tab.dart';
import '../../places/presentation/trip_places_tab.dart';
import '../../vault/presentation/trip_documents_tab.dart';
import '../domain/trip.dart';
import 'trip_card.dart';
import 'trip_providers.dart';
```

Add two new file-level constants after the existing `_tabCount`/`_expensesTabIndex` (original lines 27-28), matching that file's existing "widget-scoped constants live at file level" convention:

```dart
const _coverHeight = 220.0;
const _tabBarOverlap = 28.0;
```

Replace the `build` method (from `Widget build(BuildContext context, WidgetRef ref) {` through the closing of the `DefaultTabController(...)` widget, i.e. the original lines 35-145) with:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final trips = ref.watch(tripListProvider).valueOrNull;
    final trip = trips?.where((t) => t.id == tripId).firstOrNull;

    if (trips == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (trip == null) {
      // Deleted while open — leave gracefully.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final today = ref.watch(clockProvider)();
    final status = bucketTrip(trip, today);

    return DefaultTabController(
      length: _tabCount,
      // While a trip is under way, spend is what you open the app for —
      // documents matter most before departure, places while planning.
      // Only `active` gets this: on an upcoming or past trip, landing on
      // Spend would bury the documents you actually came for.
      initialIndex: status == TripStatus.active ? _expensesTabIndex : 0,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Shares a tag with TripCard's cover hero (Task 3).
                Hero(
                  tag: 'trip-cover-${trip.id}',
                  child: SizedBox(
                    height: _coverHeight,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CoverBackground(trip: trip, colors: colors),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.dark.paper.withValues(alpha: 0.55),
                                AppColors.dark.paper.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                      child: GlassChrome(
                        borderRadius:
                            BorderRadius.circular(AppShape.pillRadius),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              // BackButton (not a raw Icon) so the glyph
                              // still auto-mirrors for RTL — building the
                              // topbar by hand must not lose what AppBar
                              // gave us for free.
                              BackButton(
                                color: AppColors.dark.inkPrimary,
                                onPressed: () => context.pop(),
                              ),
                              Expanded(
                                child: Hero(
                                  tag: 'trip-name-${trip.id}',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: AutoDirectionText(
                                      trip.name,
                                      style: AppTextStyles.title.copyWith(
                                        color: AppColors.dark.inkPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: AppColors.dark.inkPrimary,
                                ),
                                onSelected: (action) =>
                                    _onMenu(context, ref, trip, action),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.menuEdit),
                                  ),
                                  PopupMenuItem(
                                    value: 'archive',
                                    child: Text(
                                      trip.archived
                                          ? l10n.menuUnarchive
                                          : l10n.menuArchive,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.menuDelete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: -_tabBarOverlap,
                  child: GlassChrome(
                    borderRadius: BorderRadius.circular(AppShape.radius),
                    child: TabBar(
                      labelColor: colors.inkPrimary,
                      unselectedLabelColor: colors.inkMuted,
                      indicatorColor: colors.accent,
                      labelStyle: AppTextStyles.label,
                      // Fixed (non-scrollable) so the tabs share the width
                      // evenly and each label sits centred in its slot.
                      tabs: [
                        Tab(text: l10n.tabDocuments),
                        Tab(text: l10n.tabPlacesInTrip),
                        Tab(text: l10n.tabExpenses),
                        Tab(text: l10n.tabJournal),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Clears the tab bar's overlap below the cover Stack so the
            // date line starts right after it, not underneath it.
            const SizedBox(height: _tabBarOverlap + AppSpacing.md),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: MonoText(
                '${TripDateFormatter.line(l10n, trip)}'
                ' · ${trip.destinations.join(' → ')}'
                '${status == TripStatus.active ? ' · ${activeDayLabel(l10n, trip, today)}' : ''}',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TabBarView(
                // Journal's globe needs full ownership of horizontal drags
                // to rotate — a swipeable TabBarView competes for the same
                // gesture and wins, so tabs are tap-only everywhere.
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  TripDocumentsTab(trip: trip),
                  TripPlacesTab(trip: trip),
                  TripExpensesTab(trip: trip),
                  TripJournalTab(trip: trip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
```

The `_onMenu` method (original lines 147-182) is unchanged — leave it exactly as is.

Add the cover-background helper at the end of the file, after the `TripDetailScreen` class:

```dart
class _CoverBackground extends StatelessWidget {
  const _CoverBackground({required this.trip, required this.colors});

  final Trip trip;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final path = trip.coverPhotoPath;
    if (path != null) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: generatedCoverGradient(trip.id, colors),
      ),
    );
  }
}
```

Note: `_CoverBackground` is duplicated between `trip_card.dart` (Task 3) and this file rather than shared, matching this codebase's existing convention of small, file-local private widgets over premature cross-file abstraction (e.g. `_DateField` in `trip_form_screen.dart` isn't shared either). If a reviewer prefers a shared widget, that's a legitimate Minor suggestion, not a blocking defect — YAGNI favors the duplication until a third use appears.

- [ ] **Step 4: Run the test again to confirm it passes**

Run: `flutter test test/widget/trips/trip_detail_screen_test.dart`
Expected: PASS (all tests, including the new one). Pay particular attention to `tester.takeException()` being `null` — the `Stack`/`Positioned`/negative-offset layout is the riskiest part of this task; any overflow or layout exception must show up here.

- [ ] **Step 5: Run the full trips test folder plus accessibility**

Run: `flutter test test/unit/trips test/widget/trips test/widget/accessibility_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the whole suite**

Run: `flutter test`
Expected: PASS — this is the last task in the plan; confirm nothing anywhere else regressed.

- [ ] **Step 7: Commit**

```bash
git add lib/features/trips/presentation/trip_detail_screen.dart test/widget/trips/trip_detail_screen_test.dart
git commit -m "feat(trips): reskin TripDetailScreen with cover hero and glass chrome"
```
