# Globe texture

`journal_globe.dart` expects an equirectangular Earth texture at
`assets/globe/earth_day.jpg` (bundled locally — never fetched at runtime,
per SPEC §3.1.2 offline rule). Source: NASA's public-domain "Blue Marble"
(https://visibleearth.nasa.gov/collection/1484/blue-marble), later
swapped for a version with real bathymetry/terrain shading (closer to a
satellite-imagery look).

Currently 4000x2000, upscaled 2x from a 2000x1000 source via high-quality
bicubic interpolation (no new detail added — this smooths the source's
own texel blockiness into a softer blur under the renderer's per-pixel
sampling at high zoom, rather than eliminating it; genuinely sharper
detail at high zoom needs a higher-resolution source image, which this
environment has no way to fetch). `journal_globe.dart`'s own comments
document the exact tradeoff between `maxZoom` and this texture's
resolution.

`flutter analyze`/`flutter run` will fail if this file goes missing,
since `journal_globe.dart` references this exact path.

## `earth_day_high.jpg`

8000x4000, downscaled via high-quality bicubic interpolation from a
21600x10800 source file that was already present in the working tree
before this feature was built. That source file's own provenance/license
wasn't tracked before this session, but 21600x10800 matches NASA's
published "Blue Marble Next Generation" tile resolution, so it's very
likely sourced from the same NASA Blue Marble public-domain collection
cited above for `earth_day.jpg` — this is a reasonable inference, not a
confirmed fact, since the chain of custody before this session isn't
recorded.

Loaded by `journal_globe.dart` as the "tier 2" / zoomed-in texture once
`highResGlobeZoomThreshold` (currently `zoom > 1.5`) is crossed — via
`FlutterEarthGlobeController.loadSurface` at runtime, not as the initial
`surface:` texture the controller is constructed with.
