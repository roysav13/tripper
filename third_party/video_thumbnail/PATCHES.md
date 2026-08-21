# Patches to video_thumbnail 0.5.6

Vendored from `pub.dev` (was `video_thumbnail-0.5.6` in the pub cache)
because upstream can't be waited on for this fix. Overridden via
`dependency_overrides` in the app's `pubspec.yaml`.

## Fix: Android build fails outright — `jcenter()` and an ancient AGP classpath

**File:** `android/build.gradle`.

**What was wrong:** the package's Android module declared its own
`buildscript` block pinning a very old Android Gradle Plugin
(`com.android.tools.build:gradle:4.1.0`, released 2020) and resolved
dependencies from `jcenter()` — a repository that's been shut down and
whose Gradle DSL method (`jcenter()`) no longer exists on the version of
Gradle/AGP this app uses (AGP 9.0.1, `android/settings.gradle.kts`). The
real build failure:

```
Could not find method jcenter() for arguments [] on repository container
of type org.gradle.api.internal.artifacts.dsl.DefaultRepositoryHandler.
```

cascaded into a second, more confusing one — because the `buildscript`
block crashed before the module's `apply plugin: 'com.android.library'`
line ever ran, Gradle never had an Android Gradle Plugin properly applied
to the module, so its `kotlin-android` plugin config then failed too:

```
'kotlin-android' plugin requires one of the Android Gradle plugins.
```

Both traced back to the same root cause: an old-style Flutter plugin
module declaring its own ancient, self-contained Android toolchain
instead of deferring to the app's.

**The fix:** replaced `jcenter()` with `mavenCentral()` in both
`repositories` blocks, and bumped the pinned AGP classpath from `4.1.0`
to `8.7.3` — the same version `sqlite3_flutter_libs` (an existing,
already-working dependency of this app, also using the same old-style
`buildscript`/`apply plugin: "com.android.library"` shape) pins in its
own `android/build.gradle`, i.e. a version already proven to coexist with
this app's AGP 9.0.1 root configuration rather than a guess. Nothing else
in the module (its `compileSdkVersion`/`minSdkVersion`/plugin
registration) was touched — only what the reported failure required.

## Re-applying after a version bump

If `video_thumbnail` is ever upgraded, re-apply this change to the new
version's `android/build.gradle`:

1. `jcenter()` → `mavenCentral()`, both occurrences (the `buildscript`
   block's `repositories` and the top-level `rootProject.allprojects`
   `repositories`).
2. `classpath 'com.android.tools.build:gradle:4.1.0'` →
   `classpath 'com.android.tools.build:gradle:8.7.3'` (or whatever
   version this app's other vendored/pinned Android plugins are using by
   then — check `sqlite3_flutter_libs`'s `android/build.gradle` for the
   current baseline).

Then remove this vendored copy and the `dependency_overrides` entry in
the app's `pubspec.yaml` once upstream ships an equivalent fix (or an
actively-maintained fork/replacement is adopted instead — this package's
GitHub has had open issues about the `jcenter()` removal for a while with
no release cutting a fix as of this writing).
