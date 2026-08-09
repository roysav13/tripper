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

## Re-applying after a version bump

If `flutter_earth_globe` is ever upgraded, re-apply both of these
changes to the new version's `rotating_globe.dart`:

1. `Future.delayed` → `addPostFrameCallback` (with a `mounted` guard) in
   the recentering logic inside `RotatingGlobeState.build()`.
2. Stop `genericAnimationController` in `onInteractionStart`, alongside
   `_decelerationController` and `_zoomAnimationController`.

Then remove this vendored copy and the `dependency_overrides` entry in
the app's `pubspec.yaml` once upstream ships equivalent fixes.
