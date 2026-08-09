# Globe tiered zoom texture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Swap the globe's surface texture to a higher-resolution asset once the user zooms in past a threshold, instead of shipping one texture sized for the deepest zoom level.

**Architecture:** `journal_globe.dart`'s existing `_handleZoomChanged` callback gains one more responsibility — the first time `zoom` crosses a threshold, call `FlutterEarthGlobeController.loadSurface` with a second, higher-res `AssetImage`. No changes to the vendored `flutter_earth_globe` package are needed; this reuses the same `loadSurface`/`notifyListeners` path the initial texture load already goes through.

**Tech Stack:** Flutter, `flutter_earth_globe` (vendored, `third_party/flutter_earth_globe`), `package:meta` (`@visibleForTesting`).

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart` (n/a to this feature — no new colors).
- No `DateTime.now()` in domain code (n/a — no domain code touched).
- Local data is always the source of truth; the texture asset is bundled, never fetched over the network (already true of the base texture — this feature keeps that property for the second tier).
- Tests land in the same commit as the feature.
- Widget/GPU-dependent code stays manual-verification-only, same as every other `flutter_earth_globe`-rendering change in this file — pull the decision logic into a plain, unit-testable function instead of trying to test the GPU path itself.

---

### Task 1: Downscale the high-res texture asset and drop unused candidates

**Files:**
- Modify (overwrite in place, downscaled): `assets/globe/earth_day_high.jpg` (currently untracked, 21600×10800)
- Delete: `assets/globe/earth_day_low.jpg` (untracked, unused candidate)
- Delete: `assets/globe/A1.jpg` (untracked, wrong aspect ratio, unused)

**Interfaces:**
- Produces: `assets/globe/earth_day_high.jpg` at exactly 8000×4000, committed to git, ready for Task 3 to reference via `AssetImage('assets/globe/earth_day_high.jpg')`.

- [ ] **Step 1: Downscale `earth_day_high.jpg` to 8000x4000**

Run (PowerShell, from repo root):

```powershell
Add-Type -AssemblyName System.Drawing
$src = "assets\globe\earth_day_high.jpg"
$dst = "assets\globe\earth_day_high.jpg"
$tmp = "assets\globe\earth_day_high_resized_tmp.jpg"

$original = [System.Drawing.Image]::FromFile((Resolve-Path $src))
$targetWidth = 8000
$targetHeight = 4000

$resized = New-Object System.Drawing.Bitmap $targetWidth, $targetHeight
$graphics = [System.Drawing.Graphics]::FromImage($resized)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.DrawImage($original, 0, 0, $targetWidth, $targetHeight)
$graphics.Dispose()

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters 1
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, 90L)
$resized.Save($tmp, $jpegCodec, $encoderParams)

$resized.Dispose()
$original.Dispose()

Move-Item -Force $tmp $dst
```

- [ ] **Step 2: Verify the resized dimensions**

Run:

```powershell
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile((Resolve-Path "assets\globe\earth_day_high.jpg"))
"$($img.Width)x$($img.Height)"
$img.Dispose()
```

Expected: `8000x4000`

- [ ] **Step 3: Delete the unused candidate files**

```bash
rm assets/globe/earth_day_low.jpg assets/globe/A1.jpg
```

- [ ] **Step 4: Stage and verify the asset changes**

```bash
git add assets/globe/earth_day_high.jpg
git status --short assets/globe/
```

Expected: `earth_day_high.jpg` shows as a new tracked file (added); `earth_day_low.jpg` and `A1.jpg` no longer appear (deleted, untracked so they just vanish rather than showing as `D`).

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(journal): add downscaled high-res globe texture tier

8000x4000 (~32MP), downscaled from the 21600x10800 source that caused
the earlier decode-never-finishes incident. Not yet wired up to any
zoom logic — that's the next task."
```

---

### Task 2: Zoom-threshold decision logic (TDD, no GPU dependency)

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart` (add a new top-level constant and function; do not wire it into `_handleZoomChanged` yet — that's Task 3)
- Test: Create `test/unit/journal/journal_globe_zoom_test.dart`

**Interfaces:**
- Produces: `const double highResGlobeZoomThreshold = 1.5;` and
  ```dart
  @visibleForTesting
  bool shouldRequestHighResGlobeSurface({
    required double zoom,
    required bool alreadyRequested,
  })
  ```
  both top-level (not inside any class), in `journal_globe.dart`. Task 3 consumes both by name.

- [ ] **Step 1: Write the failing unit test**

Create `test/unit/journal/journal_globe_zoom_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/journal/presentation/journal_globe.dart';

void main() {
  group('shouldRequestHighResGlobeSurface', () {
    test('false below the threshold', () {
      expect(
        shouldRequestHighResGlobeSurface(zoom: 1.0, alreadyRequested: false),
        isFalse,
      );
    });

    test('false exactly at the threshold', () {
      expect(
        shouldRequestHighResGlobeSurface(
          zoom: highResGlobeZoomThreshold,
          alreadyRequested: false,
        ),
        isFalse,
      );
    });

    test('true just above the threshold, not yet requested', () {
      expect(
        shouldRequestHighResGlobeSurface(
          zoom: highResGlobeZoomThreshold + 0.1,
          alreadyRequested: false,
        ),
        isTrue,
      );
    });

    test('false above the threshold if already requested', () {
      expect(
        shouldRequestHighResGlobeSurface(
          zoom: highResGlobeZoomThreshold + 0.1,
          alreadyRequested: true,
        ),
        isFalse,
      );
    });

    test('false well above the threshold if already requested', () {
      expect(
        shouldRequestHighResGlobeSurface(zoom: 3.5, alreadyRequested: true),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/journal/journal_globe_zoom_test.dart`
Expected: FAIL — `shouldRequestHighResGlobeSurface` and `highResGlobeZoomThreshold` are undefined.

- [ ] **Step 3: Add the constant and function to `journal_globe.dart`**

In `lib/features/journal/presentation/journal_globe.dart`, add near the existing top-level constants (alongside `_arcCurveScale` at line 50):

```dart
// Globe.GL-style arcs default the curve height (via the point_connection
// package's own curveScale=1.5 default) to something that reads as a
// steep, ballistic arc — closer to a flight path than a route line on the
// same globe you're standing on. This flattens the arc noticeably closer
// to the sphere's surface.
const _arcCurveScale = 0.4;

// The zoom level past which the globe swaps to a higher-resolution
// surface texture (see _buildController's maxZoom comment for why the
// base texture softens at high zoom — this routes more real detail into
// view instead of just resampling the same fixed-resolution source
// larger). zoom's range is [minZoom (-1.0 default), maxZoom (3.5)]; 1.5
// is partway through the zoom-in range, chosen so the swap happens
// before the softening becomes very visible rather than only at the
// very top of the range.
const highResGlobeZoomThreshold = 1.5;

/// Whether [JournalGlobe] should request the higher-resolution surface
/// texture — true exactly once, the first time [zoom] crosses
/// [highResGlobeZoomThreshold], given the caller already tracks whether
/// that request has been made ([alreadyRequested]) so it isn't repeated
/// on every subsequent zoom-changed callback above the threshold. A
/// top-level, GPU-independent function so this decision is unit-testable
/// without a real FlutterEarthGlobeController — see
/// test/unit/journal/journal_globe_zoom_test.dart.
@visibleForTesting
bool shouldRequestHighResGlobeSurface({
  required double zoom,
  required bool alreadyRequested,
}) {
  return !alreadyRequested && zoom > highResGlobeZoomThreshold;
}
```

No new import needed — `@visibleForTesting` is already available transitively through the existing `package:flutter/material.dart` import (adding a separate explicit import for it would trigger the `unnecessary_import` lint from `flutter_lints`).

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/journal/journal_globe_zoom_test.dart`
Expected: PASS — all 5 cases.

- [ ] **Step 5: Run `flutter analyze` to confirm no lint issues**

Run: `flutter analyze lib/features/journal/presentation/journal_globe.dart test/unit/journal/journal_globe_zoom_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart test/unit/journal/journal_globe_zoom_test.dart
git commit -m "feat(journal): add zoom-threshold decision logic for high-res globe texture

Pure, unit-tested function — not yet wired into _handleZoomChanged.
Kept separate from the GPU-dependent wiring (next commit) so the actual
decision logic has real test coverage, matching the renderGlobe:false
seam's philosophy of keeping GPU dependency out of anything that can be
tested without it."
```

---

### Task 3: Wire the threshold check into `_handleZoomChanged`

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart:95-98` (add `_highResRequested` field), `:321-339` (`_handleZoomChanged`)

**Interfaces:**
- Consumes: `highResGlobeZoomThreshold` and `shouldRequestHighResGlobeSurface` from Task 2; `FlutterEarthGlobeController.loadSurface(ImageProvider)` (existing package API, already used in `_buildController` for the initial `surface:` load — see `flutter_earth_globe_controller.dart`'s `loadSurface`, patched earlier this session to report decode errors via `onError` instead of swallowing them silently).
- Produces: no new public interface — this is the integration endpoint, consumed only by the running app.

- [ ] **Step 1: Add the `_highResRequested` field**

In `lib/features/journal/presentation/journal_globe.dart`, in `_JournalGlobeState` (around line 98, alongside `_focusedEntryId`):

```dart
class _JournalGlobeState extends State<JournalGlobe> {
  FlutterEarthGlobeController? _controller;
  bool _initialized = false;
  String? _focusedEntryId;

  /// Set once _handleZoomChanged has requested the higher-res surface
  /// texture (see shouldRequestHighResGlobeSurface) — guards against
  /// re-requesting it on every subsequent zoom-changed callback past
  /// highResGlobeZoomThreshold. Deliberately never reset: once loaded,
  /// the higher-res texture stays active for the rest of the session
  /// even if the user zooms back out (approved design: avoids repeated
  /// ~32MP decodes from ordinary zoom in/out fiddling).
  bool _highResRequested = false;
```

- [ ] **Step 2: Call `loadSurface` from `_handleZoomChanged`**

Replace the existing `_handleZoomChanged` (lines 321-339):

```dart
  void _handleZoomChanged(double zoom) {
    final controller = _controller;
    if (controller == null) return;
    if (shouldRequestHighResGlobeSurface(
      zoom: zoom,
      alreadyRequested: _highResRequested,
    )) {
      _highResRequested = true;
      controller.loadSurface(const AssetImage('assets/globe/earth_day_high.jpg'));
    }
    final compensation = 1 / math.pow(2, zoom);
    for (final entry in widget.entries) {
      if (!entry.hasLocation) continue;
      final haloBase = entry.hasPhotos ? _photoHaloDotSize : _haloDotSize;
      final borderBase = entry.hasPhotos ? _photoBorderSize : _plainBorderSize;
      _rescalePoint(controller, '${entry.id}-halo', haloBase * compensation);
      _rescalePoint(
        controller,
        '${entry.id}-border',
        borderBase * compensation,
      );
      if (!entry.hasPhotos) {
        _rescalePoint(controller, entry.id, _plainDotSize * compensation);
      }
    }
  }
```

(Only the new `if (shouldRequestHighResGlobeSurface(...))` block at the top is new — the rest of the method is unchanged, reproduced here so the diff is unambiguous.)

- [ ] **Step 3: Run the full existing widget test suite for this file**

Run: `flutter test test/widget/journal/journal_globe_test.dart`
Expected: PASS — this change doesn't touch the `renderGlobe: false` path these tests exercise, so nothing here should regress.

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze lib/features/journal/presentation/journal_globe.dart`
Expected: No issues found.

- [ ] **Step 5: Manual on-device verification**

This step is GPU-rendering-dependent and cannot be automated or verified by Claude directly (see CLAUDE.md's Verification section) — run `flutter run` on a real device, open a trip's Journal tab, and pinch-zoom in on the globe past roughly the midpoint of the zoom range. Confirm:
- The globe keeps rendering throughout (no blank/frozen frame during the swap).
- The texture looks at least as sharp after the swap as before (a visible detail improvement is the point, but the key regression to rule out is any flash-to-blank or crash).
- Zooming back out and back in again does not re-trigger a second decode (no visible stutter on repeated threshold crossings) — this confirms `_highResRequested` is doing its job.

Report back the observed behavior before proceeding to commit.

- [ ] **Step 6: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart
git commit -m "feat(journal): swap to the high-res globe texture past the zoom threshold

Wires shouldRequestHighResGlobeSurface into _handleZoomChanged —
manually verified on-device per docs/superpowers/plans/2026-08-09-globe-tiered-zoom-texture.md."
```

---

## Self-Review Notes

- **Spec coverage:** Trigger/load-path/state (Task 3), asset pipeline (Task 1), error handling (already implemented this session in `loadSurface`'s `onError`, reused as-is — no new task needed), testing (Task 2), out-of-scope items (crossfade, third tier, vendored-package changes) — none introduced. All spec sections covered.
- **Placeholder scan:** No TBD/TODO; every step has real, complete code.
- **Type consistency:** `shouldRequestHighResGlobeSurface({required double zoom, required bool alreadyRequested})` defined in Task 2 and consumed with the same named parameters in Task 3. `highResGlobeZoomThreshold` used identically in both. `controller.loadSurface(ImageProvider)` matches the existing, unmodified package signature (verified against `flutter_earth_globe_controller.dart` during planning).
