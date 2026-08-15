# Tripper Redesign — Phase 3: Places Reskin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the Places feature per the "Immersive Golden Hour" spec: an authored light/dark Google Maps style built from the app's own tokens (replacing Google's stock/Night look), custom layered-dot map markers replacing the default red teardrop pins, removal of the pre-redesign stats header (a design call made directly with the user, superseding the spec's literal "countries/been/want counts in coral" header prose), and the category/country filter chips moving from an always-visible inline `Wrap` into a glass-chrome modal bottom sheet.

**Architecture:** Four tasks. Task 1 retunes `map_style.dart`'s light/dark JSON style strings to the app's `mapWater`/`mapLand`/`warning` tokens (Phase 1 already shipped these tokens, unused until now) — a leaf, low-risk change that both `PlacesMapView` and `JournalMapView` inherit automatically. Task 2 replaces `PlacesMapView`'s default `Marker` pins with custom layered-dot `BitmapDescriptor`s (halo+ring+core), reusing the exact technique and proportions `journal_map_view.dart` already established for the Journal map — "matching the globe's dot language" per spec. Task 3 deletes `PlaceStatsHeader` and its supporting provider (a scoped removal, decided directly with the user — see Design Decisions below). Task 4 moves `PlaceFilterBar`'s chips into a `GlassChrome`-topped modal bottom sheet, shared between `PlacesScreen` and `TripPlacesTab` (both already reuse the same `PlaceFilterBar` widget today).

**Tech Stack:** Flutter/Dart, Riverpod, `google_maps_flutter` (already a dependency; markers use its non-deprecated `BitmapDescriptor.bytes()`/`BytesMapBitmap` API, confirmed present at the pinned `google_maps_flutter_platform_interface: 2.16.0`), `dart:ui` canvas drawing (no new dependency — same technique `journal_map_view.dart` already uses).

**Spec:** `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md` (§5 Places bullet, §6 map-styling/custom-markers technical implications, §3.1 `mapWater`/`mapLand` tokens). Phase 1's shipped tokens: `docs/superpowers/plans/2026-08-14-tripper-redesign-phase1-foundation.md`. Phase 2a's `GlassChrome`-wrapping-a-`TabBar` precedent (`docs/superpowers/plans/2026-08-15-tripper-redesign-phase2a-trips.md`, Task 5) is this plan's precedent for wrapping the filter sheet in glass chrome.

## Global Constraints

- No `Color(0xFF...)` or raw hex outside `lib/core/theme/app_colors.dart`, **except** `map_style.dart`'s two JSON style strings, which must be *literal copies* of `AppColors.light`/`AppColors.dark` token values (they can't reference `AppColors` directly — `GoogleMap.style` needs a plain JSON string, not a runtime-computed one). This is the same narrow, justified exception phase2a's Task 3 used for `TripCard`'s scrim color — copy the hex, don't invent a new one, and keep a comment cross-referencing `app_colors.dart` so the two stay in sync by inspection.
- One accent only (coral, `colors.accent`). Amber (`colors.warning`) stays reserved for expiry/danger-adjacent warnings and, per spec §3.1, map labels — never a second UI accent.
- Every user-facing string goes through ARB (`lib/l10n/app_en.arb`), English only (Hebrew is a future pass — do not touch `app_he.arb`, matching phase2a's precedent). All new/changed layout code uses `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional` — this app just shipped Hebrew RTL support and it must not regress.
- No `DateTime.now()` in domain code (not touched by this plan — no domain-layer changes).
- Tests land in the same commit as the feature, **except** Task 2's canvas-drawn marker bitmaps: `journal_map_view.dart`'s equivalent `_plainDotMarkerBitmap`/`_photoMarkerBitmap` functions are private, untested today (confirmed: no test file references them; `journal_map_view_test.dart` only ever exercises the `renderMap: false` scaffold, which bypasses bitmap generation entirely), because `GoogleMap` needs a platform view widget tests can't create, and the private functions aren't importable from a separate test file either. Task 2 follows that exact, already-established precedent rather than inventing a new one.

**Design decisions locked in for this plan** (resolved directly with the user before writing this plan, not a literal reading of spec §5's Places prose):

1. **`PlaceStatsHeader` is removed entirely**, not reskinned. The spec's "mono/serif stats header (countries/been/want counts in coral)" prose predates the header's actual shipped shape (countries/visited/days-traveled, M5.6) and predates this decision — the user chose to drop the header outright rather than reconcile the mismatch. `placeStatsProvider` (presentation-layer glue that existed only to feed this header) is deleted as part of the same task. The underlying domain functions it called — `visitedStats` (`lib/features/places/domain/place.dart`) and `daysTraveled` (`lib/features/trips/domain/trip.dart`) — are **not** deleted: both are independently unit-tested, general-purpose domain logic (`daysTraveled` in particular is its own tracked M5.6 milestone item with 11 dedicated tests in `test/unit/trips/days_traveled_test.dart`), not view-specific cruft. Losing their only caller doesn't make the underlying business logic wrong or worth destroying — this is a deliberate keep, not an oversight.
2. **Filter chips move into a modal bottom sheet**, triggered by a small `PlaceFilterButton` (a `tune` icon with a coral dot badge when a filter is active) instead of always-rendering inline. This applies to *both* consumers of the shared `PlaceFilterBar` widget — `PlacesScreen` (button lives in the `AppBar`) and `TripPlacesTab` (no `AppBar` of its own, since it's a tab body under `TripDetailScreen`'s custom header — button sits inline next to the existing progress `SectionLabel`). The sheet itself is wrapped in `GlassChrome`, matching phase2a's glass-tab-bar-over-content idiom, rather than the plain default `Material` sheet surface `place_actions_sheet.dart` uses elsewhere in this feature (that file's plain sheets are untouched — this is a deliberately different, spec-directed treatment for filters specifically).
3. **The sheet watches its places list live**, not a static snapshot captured when it opened. If it captured a snapshot, the existing "stale filter selection self-prunes when its last matching place disappears" behavior (a real fix from M4/M5, covered by dedicated tests in both `places_screen_test.dart` and `trip_places_tab_test.dart`) would still work for the underlying list — that logic lives entirely in the parent screens and doesn't route through the sheet — but the sheet's own chip would keep showing a chip for a category that no longer exists in the data until the sheet was closed and reopened, which reads as a bug. Watching live avoids that.

---

### Task 1: Authored map style — light + dark JSON from the app's own tokens

**Files:**
- Modify: `lib/features/places/presentation/map_style.dart` (entire file, currently 37 lines)
- Modify: `lib/features/places/presentation/places_map_view.dart:1-16` (header doc comment only — the code below it is untouched by this task)
- Test: `test/unit/places/map_style_test.dart` (new)

**Interfaces:**
- Produces: `kMapStyleLight` changes type from `String?` (always `null`) to `String` (a real JSON style). `kMapStyleDark` keeps its existing `String` type, new content. Both are consumed unchanged (`style: isDark ? kMapStyleDark : kMapStyleLight`) by four existing call sites — `places_map_view.dart`, `journal_map_view.dart`, `journal_location_picker.dart`, `add_place_screen.dart` — none of which need code changes; they inherit the new look automatically.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/places/map_style_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/presentation/map_style.dart';

void main() {
  group('map styles', () {
    test('both styles are valid JSON', () {
      expect(jsonDecode(kMapStyleLight), isA<List<dynamic>>());
      expect(jsonDecode(kMapStyleDark), isA<List<dynamic>>());
    });

    test(
        'light style is authored from AppColors.light.mapWater/mapLand, '
        'not left as Google\'s default (null) tiles', () {
      expect(kMapStyleLight, contains('#dceae6')); // mapWater (light)
      expect(kMapStyleLight, contains('#efe7d8')); // mapLand (light)
    });

    test(
        'dark style is retuned to AppColors.dark.mapWater/mapLand, not '
        'Google\'s generic Night style', () {
      expect(kMapStyleDark, contains('#17263c')); // mapWater (dark)
      expect(kMapStyleDark, contains('#242f3e')); // mapLand (dark)
    });

    test(
        'dark style reuses warning.amber for labels, not Google\'s '
        'default gold', () {
      expect(kMapStyleDark, contains('#f2a93c')); // warning.amber (dark)
      expect(kMapStyleDark, isNot(contains('#d59563')));
      expect(kMapStyleDark, isNot(contains('#f3d19c')));
    });
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `flutter test test/unit/places/map_style_test.dart`
Expected: FAIL — `kMapStyleLight` is currently `null` (a `String?`), so `contains(...)` on it doesn't even compile against the new test's expectations; `kMapStyleDark` still contains the old gold hex values.

- [ ] **Step 3: Rewrite `map_style.dart`**

Replace the entire file:

```dart
/// Custom Google Maps style (redesign spec §6, Phase 3): retunes the map
/// surface to the app's own `map.water`/`map.land`/`warning.amber` tokens
/// instead of leaving light mode as Google's stock tiles and dark mode as
/// Google's generic "Night" style. This supersedes the 2026-07-23 "stock
/// Google Maps look" decision that used to live in this file's header —
/// the app's visual language now extends onto the map surface itself.
///
/// The hex literals below are copies of `AppColors.light`/`AppColors.dark`
/// (`lib/core/theme/app_colors.dart`) — `GoogleMap.style` needs a plain
/// JSON string built at compile time, so it can't reference `AppColors`
/// directly. If those tokens ever change, these two strings need updating
/// to match (this is the same narrow "copy, don't invent" exception to
/// "no raw hex outside app_colors.dart" that `TripCard`'s cover scrim
/// uses — see phase2a's plan, Task 3).
///
/// Both styles share the same feature/element shape (base geometry, road,
/// road.highway, transit, water, plus label fill/stroke for each), only
/// dropping Google's separate `poi.park` override — this app's token set
/// has no distinct "park" hue, and folding parks into the base geometry
/// color keeps the palette as tight as the redesign spec calls for
/// (§3.2: "tightened down... named brand hues: three").
const kMapStyleLight = '''
[
  {"elementType":"geometry","stylers":[{"color":"#efe7d8"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#403f47"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#efe7d8"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#8d5513"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#8d5513"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#efe7d8"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#faf3ec"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#403f47"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#efe7d8"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#faf3ec"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#8d5513"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#efe7d8"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#8d5513"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#dceae6"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#56525d"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#dceae6"}]}
]
''';

const kMapStyleDark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#868ba0"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#f2a93c"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#f2a93c"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#12141c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#868ba0"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#12141c"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f2a93c"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#f2a93c"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#868ba0"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}
]
''';
```

- [ ] **Step 4: Run the tests again to confirm they pass**

Run: `flutter test test/unit/places/map_style_test.dart`
Expected: PASS (all 4 tests).

- [ ] **Step 5: Update `places_map_view.dart`'s header comment**

The file's doc comment (lines 9-16) still describes the now-superseded "stock Google Maps look" decision. In `lib/features/places/presentation/places_map_view.dart`, replace lines 9-16:

```dart
/// Styling is the app's own authored light/dark palette (`map_style.dart`,
/// Phase 3 — supersedes the 2026-07-23 "stock Google Maps look" decision):
/// custom colors/labels, but standard Google chrome (zoom controls, map
/// toolbar, my-location button + blue dot), and default markers are
/// replaced with custom layered-dot bitmaps (see Task 2 of the Places
/// redesign plan) — a hybrid of "our palette" and "familiar map UX".
```

- [ ] **Step 6: Run the full places + journal test folders**

Run: `flutter test test/unit/places test/widget/places test/widget/journal`
Expected: PASS — confirms nothing broke in the other three call sites of `kMapStyleLight`/`kMapStyleDark` (they only ever exercise `renderMap: false`, so the actual style string content isn't asserted there, only that it compiles and is passed through).

- [ ] **Step 7: Commit**

```bash
git add lib/features/places/presentation/map_style.dart lib/features/places/presentation/places_map_view.dart test/unit/places/map_style_test.dart
git commit -m "feat(places): author light/dark map styles from the app's own tokens"
```

---

### Task 2: Custom layered-dot map markers (want/been)

**Files:**
- Modify: `lib/features/places/presentation/places_map_view.dart`

**Interfaces:**
- Consumes: `AppColors` (`context.colors`), the exact halo/ring/core layering technique from `lib/features/journal/presentation/journal_map_view.dart`'s `_plainDotMarkerBitmap` (read-only precedent — not imported, duplicated at matching proportions since it's now a second, independent use of the same idiom).
- Produces: nothing consumed by a later task in this plan.

- [ ] **Step 1: Add the `dart:ui` import and dot-bitmap constants**

In `lib/features/places/presentation/places_map_view.dart`, replace the import block (lines 1-7):

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';
import 'map_style.dart';
```

Add these constants after the import block, before the class doc comment:

```dart
// Layered-dot bitmap markers: halo, ring, core — the same three-layer
// technique and proportions journal_map_view.dart's plain dot already
// established for the Journal map (matching "the globe's dot language"
// per the redesign spec, §6). Only the want-to-go state gets the glowing
// halo; been-there stays a plain ring+core, so the two pin states read as
// "glowing" vs. "quiet" at a glance without needing a second hue
// (component rule 5: "coral+glow = want-to-go, muted parchment/grey =
// been-there").
const _dotCanvasSize = 56.0;
const _dotCoreRadius = 9.0;
const _dotBorderRadius = 13.0;
const _dotHaloRadius = 21.0;
const _dotHaloBlur = 6.0;
const _haloAlpha = 0.28;
```

- [ ] **Step 2: Add marker-bitmap state and loading**

Replace lines 44-60 (the `_PlacesMapViewState` class from its opening through the end of `didUpdateWidget`):

```dart
class _PlacesMapViewState extends State<PlacesMapView> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;

  /// Built once per theme brightness (they carry no per-place data) and
  /// reused for every marker of that state.
  BitmapDescriptor? _wantMarker;
  BitmapDescriptor? _beenMarker;

  List<Place> get _located =>
      widget.places.where((p) => p.hasLocation).toList();

  // Not initState: _loadMarkerBitmaps reads context.colors (a Theme
  // lookup), and establishing an InheritedWidget dependency before
  // initState() completes throws — same reasoning as
  // journal_map_view.dart's didChangeDependencies override.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.renderMap && _wantMarker == null) {
      _loadMarkerBitmaps();
    }
  }

  Future<void> _loadMarkerBitmaps() async {
    final colors = context.colors;
    final want = await _dotMarkerBitmap(
      coreColor: colors.accent,
      ringColor: colors.surface,
      glow: true,
    );
    final been = await _dotMarkerBitmap(
      coreColor: colors.inkMuted,
      ringColor: colors.surface,
      glow: false,
    );
    if (!mounted) return;
    setState(() {
      _wantMarker = want;
      _beenMarker = been;
    });
  }

  @override
  void didUpdateWidget(PlacesMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusPlaceId != null &&
        widget.focusPlaceId != oldWidget.focusPlaceId) {
      _focusOn(widget.focusPlaceId!);
    } else if (widget.places.length != oldWidget.places.length) {
      _fitToPins();
    }
  }
```

- [ ] **Step 3: Use the custom bitmaps in the marker set**

In the same file, inside `build()`'s `GoogleMap(...)`, replace the `markers: {...}` block:

```dart
          markers: {
            for (final place in _located)
              Marker(
                markerId: MarkerId(place.id),
                position: LatLng(place.lat!, place.lng!),
                icon: (place.isVisited ? _beenMarker : _wantMarker) ??
                    BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                infoWindow: InfoWindow(
                  title: place.name,
                  snippet: [
                    place.isVisited
                        ? l10n.placesBeenSection
                        : l10n.placesWantSection,
                    if (place.city.isNotEmpty) place.city,
                    if (place.country.isNotEmpty) place.country,
                  ].join(' · '),
                  onTap: widget.onPlaceTap == null
                      ? null
                      : () => widget.onPlaceTap!(place),
                ),
                onTap: widget.onPlaceTap == null
                    ? null
                    : () => widget.onPlaceTap!(place),
              ),
          },
```

(This adds `anchor: const Offset(0.5, 0.5)` — without it, `Marker` anchors a bitmap by its bottom-center, the right assumption for a teardrop pin but wrong for a centered dot; `journal_map_view.dart`'s marker set uses the same centered anchor for the same reason.)

- [ ] **Step 4: Add the bitmap-drawing helper**

At the end of `lib/features/places/presentation/places_map_view.dart`, after the `_EdgeShadow` class, add:

```dart

/// Draws a halo/ring/core dot to a fixed-pixel-size PNG and wraps it as a
/// [BitmapDescriptor] — the flat-canvas equivalent of journal_globe.dart's
/// native Point layering, matching journal_map_view.dart's own
/// `_plainDotMarkerBitmap` proportions so map pins and journal dots read
/// as the same visual language. [glow] off skips the halo layer entirely
/// (the been-there / "quiet" state) rather than drawing it at zero alpha.
Future<BitmapDescriptor> _dotMarkerBitmap({
  required Color coreColor,
  required Color ringColor,
  required bool glow,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(_dotCanvasSize / 2, _dotCanvasSize / 2);

  if (glow) {
    canvas.drawCircle(
      center,
      _dotHaloRadius,
      Paint()
        ..color = coreColor.withValues(alpha: _haloAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _dotHaloBlur),
    );
  }
  canvas.drawCircle(center, _dotBorderRadius, Paint()..color = ringColor);
  canvas.drawCircle(center, _dotCoreRadius, Paint()..color = coreColor);

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(
    _dotCanvasSize.toInt(),
    _dotCanvasSize.toInt(),
  );
  final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    byteData!.buffer.asUint8List(),
    width: _dotCanvasSize,
    height: _dotCanvasSize,
  );
}
```

- [ ] **Step 5: Run the places test folder**

Run: `flutter test test/unit/places test/widget/places`
Expected: PASS, unchanged — every existing test uses `renderMap: false`, which never reaches `didChangeDependencies`'s `widget.renderMap` guard, so bitmap generation never runs under test (matching the `journal_map_view.dart` precedent cited in Global Constraints — no test can exercise this code path without a platform view).

- [ ] **Step 6: Commit**

```bash
git add lib/features/places/presentation/places_map_view.dart
git commit -m "feat(places): replace default map pins with layered-dot markers"
```

---

### Task 3: Remove `PlaceStatsHeader`

**Files:**
- Modify: `lib/features/places/presentation/place_widgets.dart`
- Modify: `lib/features/places/presentation/place_providers.dart`
- Modify: `lib/features/places/presentation/places_screen.dart`
- Modify: `test/widget/places/places_screen_test.dart`

**Interfaces:**
- Produces: `PlacesScreen.build()`/`_body()` no longer take a `stats` parameter. Task 4 builds on this task's version of both methods.

- [ ] **Step 1: Delete `PlaceStatsHeader` from `place_widgets.dart`**

In `lib/features/places/presentation/place_widgets.dart`, delete the `PlaceStatsHeader` class and its `_stat` helper — everything from the `/// Trophy-case stats header...` doc comment (line 262) through the end of the file (line 324/325).

- [ ] **Step 2: Delete `placeStatsProvider` from `place_providers.dart`**

Replace the entire file:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/place_repository.dart';
import '../data/places_dao.dart';
import '../domain/place.dart';

final placesDaoProvider =
    Provider<PlacesDao>((ref) => ref.watch(databaseProvider).placesDao);

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => DriftPlaceRepository(
    ref.watch(placesDaoProvider),
    ref.watch(clockProvider),
  ),
);

final placeListProvider = StreamProvider<List<Place>>(
  (ref) => ref.watch(placeRepositoryProvider).watchAll(),
);

final tripPlacesProvider = StreamProvider.family<List<Place>, String>(
  (ref, tripId) => ref.watch(placeRepositoryProvider).watchForTrip(tripId),
);

/// Set by "View on map" (place actions sheet) so `PlacesScreen` knows which
/// pin to fly the camera to and pop the info window for. Cleared once
/// `PlacesMapView` has consumed it.
final selectedPlaceIdProvider = StateProvider<String?>((ref) => null);

/// List <-> map toggle on the Places tab, session-scoped. "View on map"
/// flips this to true from anywhere a place row appears.
final placesMapModeProvider = StateProvider<bool>((ref) => false);
```

(This drops the now-unused `../../trips/domain/trip.dart` and `../../trips/presentation/trip_providers.dart` imports along with `placeStatsProvider` — `Trip`/`tripListProvider`/`daysTraveled` were only ever referenced by that provider in this file. `visitedStats` and `daysTraveled` themselves are untouched in their own domain files — see this plan's Design Decisions.)

- [ ] **Step 3: Remove the header from `PlacesScreen`**

In `lib/features/places/presentation/places_screen.dart`, replace the `build` method (lines 31-116):

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncPlaces = ref.watch(placeListProvider);
    final places = asyncPlaces.valueOrNull ?? const <Place>[];

    // Cross-task issue (final review): a filter chip only renders for
    // categories/countries actually present in `places`. If the last place
    // matching an active filter is edited or deleted, its chip disappears
    // but the stale selection lingered in state forever (StatefulShellRoute
    // keeps this State alive across navigation) — stranding the list empty
    // with no visible way to recover. Prune the selection against what's
    // still present every build, and write the pruned result back so the
    // filter bar's displayed selection never outlives its chip.
    final availableCategories = {
      for (final p in places)
        if (p.category != null) p.category!,
    };
    final availableCountries = {
      for (final p in places)
        if (p.country.trim().isNotEmpty) p.country,
    };
    final prunedCategories = _categoryFilter.intersection(availableCategories);
    final prunedCountries = _countryFilter.intersection(availableCountries);
    if (prunedCategories.length != _categoryFilter.length ||
        prunedCountries.length != _countryFilter.length) {
      // Mutating state synchronously inside build() throws — defer to
      // after this frame completes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _categoryFilter = prunedCategories;
          _countryFilter = prunedCountries;
        });
      });
    }
    final filtered = filterPlaces(
      places,
      categories: prunedCategories,
      countries: prunedCountries,
    );
    final trips = ref.watch(tripListProvider).valueOrNull ?? [];
    final tripNames = {for (final t in trips) t.id: t.name};
    final mapMode = ref.watch(placesMapModeProvider);

    final want = filtered.where((p) => !p.isVisited).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final been = sortForList(filtered).where((p) => p.isVisited).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabPlaces),
        actions: [
          if (places.isNotEmpty)
            IconButton(
              icon: Icon(
                mapMode ? Icons.view_list_outlined : Icons.map_outlined,
                color: colors.inkSecondary,
              ),
              tooltip: mapMode ? l10n.listViewToggle : l10n.mapViewToggle,
              onPressed: () =>
                  ref.read(placesMapModeProvider.notifier).state = !mapMode,
            ),
          IconButton(
            icon: Icon(Icons.add, color: colors.accent),
            tooltip: l10n.placesEmptyCta,
            onPressed: () => AddPlaceScreen.open(context),
          ),
        ],
      ),
      body: _body(
        context,
        l10n,
        asyncPlaces,
        places,
        filtered,
        want,
        been,
        tripNames,
        mapMode,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<Place>> asyncPlaces,
    List<Place> places,
    List<Place> filtered,
    List<Place> want,
    List<Place> been,
    Map<String, String> tripNames,
    bool mapMode,
  ) {
    // M4.2 — states audit: same gap as trips/vault — a stream failure used
    // to fall straight through to an unexplained empty screen.
    if (asyncPlaces.hasError) {
      return ErrorState(onRetry: () => ref.invalidate(placeListProvider));
    }
    if (asyncPlaces.hasValue && places.isEmpty) {
      return EmptyState(
        icon: Icons.place_outlined,
        title: l10n.placesEmptyTitle,
        body: l10n.placesEmptyBody,
        ctaLabel: l10n.placesEmptyCta,
        onCta: () => AddPlaceScreen.open(context),
      );
    }
    if (mapMode) {
      return PlacesMapView(
        places: filtered,
        focusPlaceId: ref.watch(selectedPlaceIdProvider),
        onFocusHandled: () =>
            ref.read(selectedPlaceIdProvider.notifier).state = null,
        onPlaceTap: (place) => showPlaceActionsSheet(context, ref, place),
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        PlaceFilterBar(
          places: places,
          selectedCategories: _categoryFilter,
          selectedCountries: _countryFilter,
          onCategoriesChanged: (v) => setState(() => _categoryFilter = v),
          onCountriesChanged: (v) => setState(() => _countryFilter = v),
        ),
        if (want.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: SectionLabel(
              '${l10n.placesWantSection} · ${want.length}',
              accent: true,
            ),
          ),
          for (final place in want) _row(context, place, tripNames),
        ],
        if (been.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: SectionLabel(
              '${l10n.placesBeenSection} · ${been.length}',
            ),
          ),
          for (final place in been) _row(context, place, tripNames),
        ],
      ],
    );
  }
```

(`_row` below this, and the rest of the file, is unchanged.)

- [ ] **Step 4: Update `places_screen_test.dart`**

In `test/widget/places/places_screen_test.dart`, remove the now-unused import:

```dart
import 'package:tripper/features/places/presentation/place_widgets.dart';
```

Replace the `'sections split wishlist and visited, stats count up'` test (lines 66-95) — dropping the stats-header assertions, keeping the section-count and visited-date assertions (both come from `PlaceRowCard`/`SectionLabel`, not the removed header):

```dart
  testWidgets('sections split wishlist and visited', (tester) async {
    await tester.pumpWidget(
      _app([
        _p('Railay viewpoint', city: 'Krabi', country: 'Thailand'),
        _p(
          'Phi Phi lagoon',
          visited: true,
          visitedAt: DateTime(2026, 7, 18),
          country: 'Thailand',
        ),
        _p(
          'Ein Gedi waterfall',
          visited: true,
          visitedAt: DateTime(2026, 4, 2),
          country: 'Israel',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('WANT TO GO · 1'), findsOneWidget);
    expect(find.text('BEEN THERE · 2'), findsOneWidget);
    expect(find.textContaining('VISITED 18 JUL 2026'), findsOneWidget);
  });
```

Delete the `'days-away stat counts finished and in-progress trips only'` test entirely (originally lines 97-136 — it existed solely to exercise the removed header's third stat).

Delete the `'stat labels stay centered even when the longest one wraps to two lines'` test entirely (originally lines 308-331 — it constructed `PlaceStatsHeader` directly, which no longer exists).

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `flutter test test/widget/places/places_screen_test.dart`
Expected: PASS (all remaining tests).

- [ ] **Step 6: Run the full places test folder plus accessibility**

Run: `flutter test test/unit/places test/widget/places test/widget/accessibility_test.dart`
Expected: PASS — `accessibility_test.dart`'s "places meets tap target and contrast guidelines" (light + dark) tests re-verify the screen's remaining contents without the header.

- [ ] **Step 7: Commit**

```bash
git add lib/features/places/presentation/place_widgets.dart lib/features/places/presentation/place_providers.dart lib/features/places/presentation/places_screen.dart test/widget/places/places_screen_test.dart
git commit -m "feat(places): remove the stats header"
```

---

### Task 4: Filter chips move into a glass-chrome modal bottom sheet

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/features/places/presentation/place_widgets.dart`
- Modify: `lib/features/places/presentation/places_screen.dart`
- Modify: `lib/features/places/presentation/trip_places_tab.dart`
- Modify: `test/widget/places/places_screen_test.dart`
- Modify: `test/widget/places/trip_places_tab_test.dart`

**Interfaces:**
- Consumes: `GlassChrome` (Phase 1), Task 3's version of `PlacesScreen.build()`/`_body()`.
- Produces: `PlaceFilterButton({required bool active, required VoidCallback onPressed})` and `showPlaceFilterSheet(BuildContext, {required ProviderListenable<AsyncValue<List<Place>>> placesProvider, required Set<PlaceCategory> selectedCategories, required Set<String> selectedCountries, required ValueChanged<Set<PlaceCategory>> onCategoriesChanged, required ValueChanged<Set<String>> onCountriesChanged})`, both in `place_widgets.dart`, used by both `PlacesScreen` and `TripPlacesTab`.

- [ ] **Step 1: Add the ARB strings**

In `lib/l10n/app_en.arb`, add after line 215 (`"listViewToggle": "List view",`):

```json
  "placesFilterButton": "Filter",
  "placesFilterSheetTitle": "Filters",
```

- [ ] **Step 2: Write the failing widget tests**

In `test/widget/places/places_screen_test.dart`, replace the `'category filter narrows the visible list'` test:

```dart
  testWidgets('category filter narrows the visible list', (tester) async {
    await tester.pumpWidget(
      _app([
        const Place(id: 'a', name: 'Hotel A', category: PlaceCategory.hotel),
        const Place(
          id: 'b',
          name: 'Cafe B',
          category: PlaceCategory.coffeeShop,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);
  });
```

Replace the `'stale category selection is pruned...'` test:

```dart
  testWidgets(
      'stale category selection is pruned once its only match is edited '
      'away, so the list recovers without a restart', (tester) async {
    final repo = FakePlaceRepository([
      const Place(id: 'a', name: 'Hotel A', category: PlaceCategory.hotel),
      const Place(
        id: 'b',
        name: 'Cafe B',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeRepositoryProvider.overrideWithValue(repo),
          tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
          clockProvider.overrideWithValue(() => _today),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PlacesScreen(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Filter down to Hotel — Cafe B drops out of the list.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);

    // Simulate the underlying data changing so no place is a Hotel
    // anymore — the Hotel chip disappears, but without the fix the stale
    // selection would keep the list stuck empty forever. The sheet is
    // still open here (never dismissed) — it must reflect this live, not
    // just the snapshot it opened with.
    repo.emit([
      const Place(
        id: 'a',
        name: 'Hotel A',
        category: PlaceCategory.restaurant,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpAndSettle();

    // The now-absent "Hotel" chip is gone, and both places are visible
    // again — the stale selection was pruned, not left stranding the list.
    expect(find.text('Hotel'), findsNothing);
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);
  });
```

Replace the `'country filter narrows the visible list'` test:

```dart
  testWidgets('country filter narrows the visible list', (tester) async {
    await tester.pumpWidget(
      _app([
        _p('Thai spot', country: 'Thailand'),
        _p('Japan spot', country: 'Japan'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japan'));
    await tester.pumpAndSettle();

    expect(find.text('Thai spot'), findsNothing);
    expect(find.text('Japan spot'), findsOneWidget);
  });
```

Append a new test after the `'500+ places render without overflow or exceptions (M4.2)'` test:

```dart
  testWidgets(
      'filter sheet renders many categories and countries without '
      'overflow', (tester) async {
    final many = [
      for (var i = 0; i < 40; i++)
        Place(
          id: 'p$i',
          name: 'Place $i',
          country: 'Country $i',
          category: PlaceCategory.values[i % PlaceCategory.values.length],
        ),
    ];
    await tester.pumpWidget(_app(many));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.fling(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -2000),
      3000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
```

In `test/widget/places/trip_places_tab_test.dart`, replace both existing tests:

```dart
  testWidgets('category filter narrows this trip\'s visible list',
      (tester) async {
    final repo = FakePlaceRepository([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        category: PlaceCategory.hotel,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
        tripId: 't1',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);
  });

  testWidgets(
      'stale category selection is pruned once its only match is edited '
      'away, so the list recovers without a restart', (tester) async {
    final repo = FakePlaceRepository([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        category: PlaceCategory.hotel,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
        tripId: 't1',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsNothing);

    repo.emit([
      const Place(
        id: 'a',
        name: 'Hotel A',
        tripId: 't1',
        category: PlaceCategory.restaurant,
      ),
      const Place(
        id: 'b',
        name: 'Cafe B',
        tripId: 't1',
        category: PlaceCategory.coffeeShop,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Hotel'), findsNothing);
    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Cafe B'), findsOneWidget);
  });
```

- [ ] **Step 3: Run the tests to confirm they fail**

Run: `flutter test test/widget/places/places_screen_test.dart test/widget/places/trip_places_tab_test.dart`
Expected: FAIL — `Icons.tune` doesn't exist anywhere in either screen yet, and the inline `PlaceFilterBar` chips are still directly tappable without opening anything.

- [ ] **Step 4: Add `PlaceFilterButton`, `showPlaceFilterSheet`, and `_PlaceFilterSheet` to `place_widgets.dart`**

In `lib/features/places/presentation/place_widgets.dart`, replace the import block (lines 1-11):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/glass_chrome.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';
```

Append at the end of the file (after `RowSettleAnimation`, which is now the last class since Task 3 deleted `PlaceStatsHeader`):

```dart

/// Small trigger for [showPlaceFilterSheet] — a plain icon button with a
/// coral dot badge when a category or country filter is active, so the
/// filter state stays visible even while the sheet itself is closed.
class PlaceFilterButton extends StatelessWidget {
  const PlaceFilterButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.tune, color: colors.inkSecondary),
          tooltip: l10n.placesFilterButton,
          onPressed: onPressed,
        ),
        if (active)
          PositionedDirectional(
            top: 8,
            end: 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 8, height: 8),
              ),
            ),
          ),
      ],
    );
  }
}

/// Opens [PlaceFilterBar]'s chips in a glass-chrome modal bottom sheet
/// (redesign spec §5: "glass filter chips on a bottom sheet") instead of
/// always-visible inline — the same GlassChrome-over-content idiom
/// phase2a's trip detail screen used for its floating tab bar.
/// [placesProvider] is watched *inside* the sheet (not passed as a static
/// list) so a chip whose last matching place is edited/deleted away while
/// the sheet is open still disappears live — the same guarantee the
/// pre-sheet inline chips had via the parent screens' own pruning logic.
Future<void> showPlaceFilterSheet(
  BuildContext context, {
  required ProviderListenable<AsyncValue<List<Place>>> placesProvider,
  required Set<PlaceCategory> selectedCategories,
  required Set<String> selectedCountries,
  required ValueChanged<Set<PlaceCategory>> onCategoriesChanged,
  required ValueChanged<Set<String>> onCountriesChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _PlaceFilterSheet(
      placesProvider: placesProvider,
      initialCategories: selectedCategories,
      initialCountries: selectedCountries,
      onCategoriesChanged: onCategoriesChanged,
      onCountriesChanged: onCountriesChanged,
    ),
  );
}

class _PlaceFilterSheet extends ConsumerStatefulWidget {
  const _PlaceFilterSheet({
    required this.placesProvider,
    required this.initialCategories,
    required this.initialCountries,
    required this.onCategoriesChanged,
    required this.onCountriesChanged,
  });

  final ProviderListenable<AsyncValue<List<Place>>> placesProvider;
  final Set<PlaceCategory> initialCategories;
  final Set<String> initialCountries;
  final ValueChanged<Set<PlaceCategory>> onCategoriesChanged;
  final ValueChanged<Set<String>> onCountriesChanged;

  @override
  ConsumerState<_PlaceFilterSheet> createState() => _PlaceFilterSheetState();
}

class _PlaceFilterSheetState extends ConsumerState<_PlaceFilterSheet> {
  late Set<PlaceCategory> _categories = widget.initialCategories;
  late Set<String> _countries = widget.initialCountries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final places =
        ref.watch(widget.placesProvider).valueOrNull ?? const <Place>[];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassChrome(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppShape.radius),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(l10n.placesFilterSheetTitle),
                  const SizedBox(height: AppSpacing.md),
                  PlaceFilterBar(
                    places: places,
                    selectedCategories: _categories,
                    selectedCountries: _countries,
                    onCategoriesChanged: (v) {
                      setState(() => _categories = v);
                      widget.onCategoriesChanged(v);
                    },
                    onCountriesChanged: (v) {
                      setState(() => _countries = v);
                      widget.onCountriesChanged(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Wire the button into `PlacesScreen`**

In `lib/features/places/presentation/places_screen.dart`, replace the `build` method's `return Scaffold(...)` (the block written in Task 3, Step 3):

```dart
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabPlaces),
        actions: [
          if (places.isNotEmpty)
            IconButton(
              icon: Icon(
                mapMode ? Icons.view_list_outlined : Icons.map_outlined,
                color: colors.inkSecondary,
              ),
              tooltip: mapMode ? l10n.listViewToggle : l10n.mapViewToggle,
              onPressed: () =>
                  ref.read(placesMapModeProvider.notifier).state = !mapMode,
            ),
          if (availableCategories.isNotEmpty || availableCountries.isNotEmpty)
            PlaceFilterButton(
              active:
                  prunedCategories.isNotEmpty || prunedCountries.isNotEmpty,
              onPressed: () => showPlaceFilterSheet(
                context,
                placesProvider: placeListProvider,
                selectedCategories: _categoryFilter,
                selectedCountries: _countryFilter,
                onCategoriesChanged: (v) =>
                    setState(() => _categoryFilter = v),
                onCountriesChanged: (v) => setState(() => _countryFilter = v),
              ),
            ),
          IconButton(
            icon: Icon(Icons.add, color: colors.accent),
            tooltip: l10n.placesEmptyCta,
            onPressed: () => AddPlaceScreen.open(context),
          ),
        ],
      ),
      body: _body(
        context,
        l10n,
        asyncPlaces,
        places,
        filtered,
        want,
        been,
        tripNames,
        mapMode,
      ),
    );
```

And in `_body`, remove the now-redundant inline `PlaceFilterBar` from the `ListView`'s `children` — replace:

```dart
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        PlaceFilterBar(
          places: places,
          selectedCategories: _categoryFilter,
          selectedCountries: _countryFilter,
          onCategoriesChanged: (v) => setState(() => _categoryFilter = v),
          onCountriesChanged: (v) => setState(() => _countryFilter = v),
        ),
        if (want.isNotEmpty) ...[
```

with:

```dart
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        if (want.isNotEmpty) ...[
```

- [ ] **Step 6: Wire the button into `TripPlacesTab`**

In `lib/features/places/presentation/trip_places_tab.dart`, add to the imports (`PlaceFilterButton`/`showPlaceFilterSheet` come from the already-imported `place_widgets.dart`, no new import needed).

Replace the `ListView`'s opening (lines 84-100):

```dart
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: SectionLabel(
                  l10n.tripPlacesProgress(visitedCount, places.length),
                ),
              ),
              if (availableCategories.isNotEmpty ||
                  availableCountries.isNotEmpty)
                PlaceFilterButton(
                  active: prunedCategories.isNotEmpty ||
                      prunedCountries.isNotEmpty,
                  onPressed: () => showPlaceFilterSheet(
                    context,
                    placesProvider: tripPlacesProvider(widget.trip.id),
                    selectedCategories: _categoryFilter,
                    selectedCountries: _countryFilter,
                    onCategoriesChanged: (v) =>
                        setState(() => _categoryFilter = v),
                    onCountriesChanged: (v) =>
                        setState(() => _countryFilter = v),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
```

(The `for (final place in sorted)` loop and the trailing "add place" button below this are unchanged — this replaces only the old `SectionLabel` `Padding` block and the `PlaceFilterBar` widget that used to follow it.)

- [ ] **Step 7: Run the tests again to confirm they pass**

Run: `flutter test test/widget/places/places_screen_test.dart test/widget/places/trip_places_tab_test.dart`
Expected: PASS (all tests, including the new overflow test).

- [ ] **Step 8: Run the full places test folder plus accessibility**

Run: `flutter test test/unit/places test/widget/places test/widget/accessibility_test.dart`
Expected: PASS — the accessibility tests re-verify tap targets/contrast on both screens with the new `PlaceFilterButton` in place (its `IconButton` is a standard 48dp target with a `tooltip:`, same shape as the map/list toggle it sits beside).

- [ ] **Step 9: Run the whole suite**

Run: `flutter test`
Expected: PASS — this is the last task in the plan; confirm nothing anywhere else regressed.

- [ ] **Step 10: Commit**

```bash
git add lib/l10n/app_en.arb lib/features/places/presentation/place_widgets.dart lib/features/places/presentation/places_screen.dart lib/features/places/presentation/trip_places_tab.dart test/widget/places/places_screen_test.dart test/widget/places/trip_places_tab_test.dart
git commit -m "feat(places): move filter chips into a glass bottom sheet"
```
