# Patches to flutter_earth_globe 2.2.1

Vendored from `pub.dev` (was `flutter_earth_globe-2.2.1` in the pub cache)
because upstream can't be waited on for this fix. Overridden via
`dependency_overrides` in the app's `pubspec.yaml`.

## Fix: use `addPostFrameCallback` instead of `Future.delayed(Duration.zero)`

**File:** `lib/rotating_globe.dart`, inside `RotatingGlobeState.build()`'s
innermost `LayoutBuilder`.

**What was wrong:** `RotatingGlobeState.build()` grows its own internal
canvas (`maxWidth`/`maxHeight`) beyond whatever box its parent gave it
whenever the current zoomed sphere radius (`convertedRadius() * 2`)
exceeds that box — which, for a globe sized to nearly fill its box at
rest (the normal, expected look), starts happening almost immediately on
*any* zoom-in, not just at extreme zoom. Every time this happens, the
widget needs to re-center itself, and it did that via:

```dart
if (updatedCenter != center) {
  Future.delayed(Duration.zero, () {
    setState(() {
      center = updatedCenter;
    });
  });
}
```

`Future.delayed(Duration.zero, ...)` schedules a real `Timer`/microtask —
it does not resolve at a predictable point in the frame pipeline, and
under load (e.g. during an active pinch-zoom gesture, where this branch
re-triggers on nearly every frame while the canvas keeps growing) it can
take an unpredictable number of extra frames to fire, stacking up
redundant rebuild cycles on top of the gesture's own per-frame
`setState()` calls.

**The fix:** `WidgetsBinding.instance.addPostFrameCallback` is the
correct idiom for a `setState()` that needs to be deferred because it was
triggered from inside `build()` — it always resolves at the end of the
*current* frame, not an arbitrary later one. This closes off one
concrete, confirmed source of extra out-of-band rendering work
specifically correlated with zooming.

## Fix: stop `genericAnimationController` on a new drag gesture

**File:** `lib/rotating_globe.dart`, `RotatingGlobeState`'s
`InteractiveViewer.onInteractionStart`.

**What was wrong:** `onInteractionStart` explicitly stops
`_decelerationController` and `_zoomAnimationController` if either is
still animating when a new drag/pinch gesture begins — but never stopped
`genericAnimationController`, the controller `focusOnCoordinates()` drives
for every programmatic focus (tap-to-entry, live-follow on gallery
scroll, initial/latest-entry focus). If a user starts dragging the globe
while a `focusOnCoordinates` call is still resolving — even a nominally
"instant" `Duration.zero` one, which can still take a frame to settle
under load — that stale controller's listener stays free to keep
overwriting `rotationX`/`rotationY`/`rotationZ` on top of the drag's own
input. This is the same class of stale-animation-controller bug the app
already worked around for its own `animate: true`-vs-`false` call
pattern (see the app's `journal_globe.dart`), but at a transition point
that fix didn't cover: a gallery-scroll-driven live-follow snap
immediately followed by a manual drag on the globe itself.

**The fix:** stop `genericAnimationController` too, in the same place and
the same way as the other two controllers, before the gesture's own
`setState()`.

## Fix: surface `buildSphere()` errors instead of swallowing them

**File:** `lib/rotating_globe.dart`, the `FutureBuilder` in
`_buildSphereContent`'s CPU-rendering fallback path.

**What was wrong:** on devices/emulators where the GPU shader path isn't
available (`_useGpuRendering` false, or shader compilation failed),
`_buildSphereContent` falls back to a `FutureBuilder` wrapping the
synchronous, per-pixel `buildSphere()`. Its `builder` only ever branched
on `snapshot.hasData`:

```dart
if (snapshot.hasData) {
  ...
} else {
  return Container();
}
```

If `buildSphere()` throws — for any reason, on any input — `FutureBuilder`
captures that into `snapshot.error` exactly like any other Future error
(this is standard, correct `FutureBuilder` behavior: it never lets an
error become an *unhandled* exception). But this `builder` never checked
`snapshot.hasError`, so a genuine crash inside `buildSphere()` fell into
the exact same `Container()` branch as "still loading" — a permanently
blank sphere, with nothing printed to the console, indistinguishable from
a slow decode.

**The fix:** `debugPrint` the error and stack trace when
`snapshot.hasError`, before falling through to the existing
`Container()` — purely diagnostic, no rendering-path change when there's
no error.

## Fix: surface `SphereShaderPainter.paint()`'s silent validity guards

**File:** `lib/sphere_shader_painter.dart`, `SphereShaderPainter.paint()`.

**What was wrong:** the same investigation above found a second silent
path, on the GPU side this time. `paint()` guards against non-finite/
non-positive `radius`, `size`, and `rotationX`/`rotationZ` by calling
`onPaintError?.call()` and returning — silently. `onPaintError` (wired to
`RotatingGlobeState._handleSphereShaderPaintError`) just increments an
error counter with no logging of its own; only after
`_maxShaderErrors` repeats does it fall back to CPU rendering (which has
its own silent-failure history, see above) — so a genuinely invalid
radius/size/rotation reaching the painter produced no console output at
any point, on either the GPU or CPU path.

**The fix:** `debugPrint` which specific guard tripped, and with what
value, before calling `onPaintError?.call()` — purely diagnostic.

## Fix: add `onSphereReady`, distinct from `onLoaded`

**Files:** `lib/flutter_earth_globe_controller.dart` (new
`onSphereReady` field, and an `onError` handler on `loadSurface`'s
`ImageStreamListener` — previously a failed resolve left `surface`/
`surfaceProcessed` null forever with zero signal) and
`lib/rotating_globe.dart` (`_notifySphereReady`, called from both the
GPU and CPU render paths).

**What was wrong:** `journal_globe.dart` covers the sphere with a loading
indicator until `FlutterEarthGlobeController.onLoaded` fires, on the
assumption that this meant the surface texture was ready. It doesn't —
`onLoaded` fires from `load()`, called unconditionally via
`Future.delayed(Duration.zero, ...)` in `initState()`, completely
independent of surface-load state (a real async gap: `ImageProvider`
resolution + `convertImageToUint32List`). So the loading indicator faded
out almost immediately on every run, well before the sphere had anything
to paint.

**The fix:** a new `onSphereReady` controller callback that fires once,
the first time the sphere actually has something to paint — when
`_buildGpuSphere` returns a real widget, or (CPU fallback) when
`buildSphere`'s `ui.decodeImageFromPixels` callback completes. The app
now gates its loading indicator on this instead of `onLoaded`, which
keeps `onLoaded`'s existing behavior (point placement, initial focus —
neither of which needs the texture) unchanged.

The GPU call site (`_buildSphereContent`) fires this from inside
`build()` (the widget tree's outer `LayoutBuilder`), and the app's
`onSphereReady` listener calls `setState()` on the *ancestor*
`JournalGlobe` widget — doing that synchronously mid-build throws
`setState() or markNeedsBuild() called during build`, since that
ancestor had already finished building earlier in the same frame.
`_notifySphereReady` defers the actual call through
`WidgetsBinding.instance.addPostFrameCallback` (same idiom, and same
reasoning, as the `Future.delayed`→`addPostFrameCallback` fix above —
just triggered from a new call site introduced by this patch), guarded
by `mounted` like every other deferred callback in this file.

**Note:** this fix alone does not make the globe render — see the app-side
root cause below. It's a real, independent bug (the loading indicator was
timed wrong) that was masking the actual one.

## The actual root cause (app-side, not this package)

Fixing everything above still left the globe permanently invisible, with
every diagnostic (surface decoded, shader compiled and bound, `paint()`
called repeatedly with correct non-zero size/radius/center — even a
`git bisect` across the app's commit history and a blunt "paint a solid
color" test) reporting complete success and nothing on screen. The actual
bug turned out to be a **layout constraint collapse**, entirely in the
app's `journal_globe.dart`, not in this package — but it only manifests
*because of* how `RotatingGlobeState.build()` (this package, unchanged)
is structured, so it's documented here too.

`RotatingGlobeState.build()`'s root widget is a bare `Stack` whose only
non-`Positioned` child is a hardcoded `SizedBox.shrink()` (its unused
"background" layer — nothing in this app ever sets
`controller.background`). A bare `Stack` gives non-`Positioned` children
**loosened** constraints (0..max) regardless of what constraints the
`Stack` itself received, and sizes *itself* to the largest
non-`Positioned` child. Under **tight** constraints, that doesn't matter
— the tight min/max forces the Stack's size regardless of its children.
But the app's `journal_globe.dart` wrapped `FlutterEarthGlobe` in its
*own* new `Stack` (to overlay the loading indicator), and that wrapping
Stack — like all Stacks — gives its own non-`Positioned` children
*loosened* constraints. `FlutterEarthGlobe` was one such child, unwrapped
in a `Positioned`, so it received loose constraints for the first time —
and its internal Stack then collapsed to the size of its largest
non-positioned child: the zero-sized `SizedBox.shrink()`. The actual
sphere content lives in a `Positioned` child, which doesn't count toward
sizing. Result: the whole globe subtree sized itself to 0x0 and got
clipped away entirely by the Stack's default `clipBehavior: Clip.hardEdge`
— even though everything painted *inside* it kept computing and executing
with perfectly valid non-zero values throughout, exactly matching every
diagnostic observed.

**The fix (in `lib/features/journal/presentation/journal_globe.dart`,
not this package):** wrap the `FlutterEarthGlobe` child (and the loading
indicator, for consistency) in `Positioned.fill`, forcing tight
constraints again — restoring the behavior it had before that wrapping
Stack was introduced.

## Re-applying after a version bump

If `flutter_earth_globe` is ever upgraded, re-apply all of these changes
to the new version's `rotating_globe.dart`:

1. `Future.delayed` → `addPostFrameCallback` (with a `mounted` guard) in
   the recentering logic inside `RotatingGlobeState.build()`.
2. Stop `genericAnimationController` in `onInteractionStart`, alongside
   `_decelerationController` and `_zoomAnimationController`.
3. `debugPrint` on `snapshot.hasError` in the CPU-fallback `FutureBuilder`
   inside `_buildSphereContent`, before its existing `Container()` branch.
4. `debugPrint` before each silent `onPaintError?.call()` guard in
   `SphereShaderPainter.paint()` (`sphere_shader_painter.dart`).
5. Add `onSphereReady` to `FlutterEarthGlobeController` (alongside
   `onLoaded`) and call it once from `RotatingGlobeState` the first time
   the sphere is actually paintable (GPU widget built, or CPU
   `decodeImageFromPixels` callback fires) — see `_notifySphereReady`.
   Fire it via `addPostFrameCallback` (with a `mounted` guard), not
   inline — the GPU call site runs from inside `build()`. Also add the
   `onError` handler to `loadSurface`'s `ImageStreamListener`.
6. Not a change to this package, but a reminder for the app side: any
   widget wrapping `FlutterEarthGlobe` in a `Stack` (or any other widget
   that hands out loosened constraints) MUST wrap it in `Positioned.fill`
   (or equivalent) — `RotatingGlobeState`'s root widget is a bare `Stack`
   whose sizing depends on receiving tight constraints (see "The actual
   root cause" above). This is easy to reintroduce by accident with any
   future overlay added on top of the globe.

Then remove this vendored copy and the `dependency_overrides` entry in
the app's `pubspec.yaml` once upstream ships equivalent fixes.
