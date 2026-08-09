# Globe tiered zoom texture: swap to a higher-res surface past a zoom threshold

Status: approved, not yet implemented. Follows the same-day globe-rendering
investigation (`third_party/flutter_earth_globe/PATCHES.md` — the
`Positioned.fill` layout-collapse fix, and the `onSphereReady` /
`loadSurface` `onError` fixes it builds on).

## Problem

The globe's surface texture (`assets/globe/earth_day.jpg`, 4000×2000) is
sized for a good look at rest and moderate zoom, but softens visibly at
higher zoom levels since the sphere is rasterized by resampling that
fixed-resolution texture — zooming past its native texel density just
blurs existing pixels larger rather than revealing anything sharper (this
tradeoff is already documented in `journal_globe.dart`'s `maxZoom: 3.5`
comment). Bumping the single bundled texture's resolution directly is
what caused the earlier incident documented in `PATCHES.md` and
`07e3ea5`'s commit message: a 21600×10800 (233MP) texture that never
finishes decoding on-device, making the globe silently never render.

Researched industry practice for zoomable globes (Cesium, Google Earth,
NASA WorldWind — see chat log for sources) uses quadtree tile pyramids
streamed on demand. That doesn't fit this app for two structural reasons:
this globe always shows the whole sphere at once (unlike a pannable 2D
map or a low-altitude camera, tile culling saves little when you can see
half the planet at any zoom level), and the app is offline-only (SPEC
§3.1.2) — tiles can't be streamed, only bundled up front, which erases
the main cost advantage of tiling. The practical version of the same
underlying idea (routing more detail into view as you zoom, without
shipping one texture large enough to cover every zoom level) is a small
number of discrete resolution tiers, swapped in based on `zoom`.

## Design

**Trigger.** `journal_globe.dart`'s `_handleZoomChanged(double zoom)` —
already wired to `FlutterEarthGlobe.onZoomChanged`, currently used only
to rescale native dot/halo sizes against the package's built-in
zoom-scaling — gets one more responsibility: the first time `zoom`
crosses `1.5` (globe's zoom range is `minZoom: -1.0` default to
`maxZoom: 3.5`), request the higher-res texture.

**Load path.** Reuses `FlutterEarthGlobeController.loadSurface(ImageProvider)`
unchanged — the same method the initial `surface:` constructor param
resolves through, already patched this session to report decode failures
via `onError` instead of silently leaving `surface`/`surfaceProcessed`
null forever. Calling it a second time with a different `ImageProvider`
re-resolves, re-decodes, and — on success — calls `notifyListeners()`,
which is the exact mechanism `RotatingGlobeState` already listens to
(`widget.controller.addListener(_update)`) to rebuild with whatever
`controller.surface` currently holds. No changes to the vendored package
are needed for this feature.

**State.** One new field on `_JournalGlobeState`: `bool
_highResRequested = false`. `_handleZoomChanged` checks `zoom > 1.5 &&
!_highResRequested` before calling `loadSurface`, and sets the flag
immediately (not after the decode completes) so a rapid sequence of
zoom-changed callbacks while crossing the threshold can't fire the load
more than once. Per the approved design, there is no reverse transition
— once loaded, the high-res texture stays active for the rest of the
session, even if the user zooms back out below 1.5. This trades a small
amount of held memory (one extra decoded `ui.Image` +
`Uint32List`-processed copy, freed only when `JournalGlobeController` is
disposed) for avoiding a repeated ~32MP decode on every threshold
crossing during normal zoom-in/zoom-out fiddling.

**Transition.** Instant swap, no crossfade. The jump is a resolution
increase on the same image content (not a different image), so a
one-frame pop is expected to be subtle in practice; a crossfade would
require holding both surfaces simultaneously and blending in the
shader/painter, a meaningfully larger change to code this session has
already had to fight hard to stabilize. Revisit only if the pop proves
objectionable on-device.

**Asset.** `assets/globe/earth_day_high.jpg` (currently an untracked
21600×10800 / 233MP file — the same resolution that caused the original
crash) gets downscaled to 8000×4000 (~32MP, 4x the base tier's pixel
count, matching the "double resolution per level" convention from
quadtree LOD systems) and committed at that size. `assets/globe/earth_day_low.jpg`
(5400×2700, an alternate candidate not used by this design) and
`assets/globe/A1.jpg` (21600×21600 — wrong aspect ratio for an
equirectangular sphere texture entirely, never usable as-is) are deleted
as unreferenced, matching the precedent set by `2c6ef57`'s "drop
unreferenced oversized globe texture files" cleanup. No `pubspec.yaml`
change is needed — `assets/globe/` is already bundled as a whole
directory.

## Error handling

If the high-res decode fails (corrupt asset, extreme memory pressure),
`loadSurface`'s `onError` (already wired) logs it via `debugPrint` and
the globe keeps rendering whatever `controller.surface` it already has —
`surface`/`surfaceProcessed` are only overwritten on a *successful*
decode, so a failed high-res load is invisible to the user, not a
regression from the base-texture experience they already had.

## Testing

The swap condition (`zoom > 1.5 && !_highResRequested`) is extracted into
a small pure method/property on `_JournalGlobeState` (or a standalone
function) that a unit test can exercise directly, without needing a real
GPU-backed `FlutterEarthGlobeController` — verifying it evaluates true
exactly once as `zoom` crosses the threshold from below, and false on
every call at or above it afterward, and false for any call before the
threshold is first crossed. This mirrors the existing `renderGlobe: false`
test seam's philosophy (SPEC: no GPU/platform dependency in tests) by
testing the decision logic in isolation rather than the actual texture
swap, which is manual-verification-only like every other GPU-rendering
change in this file.

## Out of scope

- Crossfade transition (see "Transition" above — revisit only if needed).
- A third tier / further zoom-dependent resolution steps beyond the one
  swap.
- Any change to `flutter_earth_globe`'s vendored source — this feature is
  implemented entirely in `journal_globe.dart` using the existing
  `loadSurface` API.
