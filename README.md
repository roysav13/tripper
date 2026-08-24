# Tripper

Local-first travel companion: trips, document vault, wishlist & visited places.
Android is the primary target; an installable web build (below) covers iOS,
which has no native build here.
Spec: [`docs/SPEC.md`](docs/SPEC.md) · Plans: [`docs/plans/`](docs/plans/)

## Bootstrap (one-time)

Requires Flutter (stable channel) with Android toolchain.

```bash
# 1. Generate Android platform folder around the existing code
flutter create . --org dev.roysav --platforms android --project-name tripper

# 2. Dependencies + codegen
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs

# 3. Verify
flutter analyze
flutter test

# 4. Run (device or emulator)
flutter run
```

Note: `flutter create .` may drop a default `test/widget_test.dart` — delete it if it appears; `test/smoke_test.dart` replaces it. Set `minSdk = 26` in `android/app/build.gradle` after generation.

Fonts: see [`assets/fonts/README.md`](assets/fonts/README.md).

## Development loop

- `.\tool\run.ps1` — live app with hot reload, **and** wires `MAPS_API_KEY` from
  `android/local.properties` into the Dart search code via `--dart-define`.
  Plain `flutter run` will build and the map tiles will still render (Gradle
  reads the key straight from `local.properties` for the native SDK), but
  in-app place search silently falls back to the keyless Nominatim geocoder
  and reports `mapSearchOffline` ("Search needs a connection") on any hiccup,
  which is misleading if you *do* have a Maps key configured.
- `flutter test` — unit + widget tests (must stay green; CI enforces)
- CI: `.github/workflows/ci.yaml` — format, codegen check, analyze, test on every push/PR

## Web / PWA build

The web build exists so the app can be installed to an iOS home screen and
used offline without an Apple developer account. Build it with
`.\tool\build_web.ps1` — never a bare `flutter build web`, which would miss
two things that silently break offline use:

- `--no-web-resources-cdn`, without which CanvasKit is fetched from
  `gstatic.com` at runtime and the first flight-mode launch renders nothing.
- Stamping the service worker's cache id, without which a deploy keeps
  serving the previous build's files.

Serve `build/web` over https (or `http://localhost`). Without a secure origin
there is no service worker, so no offline support and no "Add to Home Screen".
On iOS, install via Safari → Share → Add to Home Screen.

Things to know when working on it:

- **Offline caching is ours.** Flutter's generated `flutter_service_worker.js`
  is a deprecated stub that only unregisters itself, so `web/sw.js` and the
  custom `web/flutter_bootstrap.js` that registers it are hand-written.
- **`web/sqlite3.wasm` and `web/drift_worker.js` are version-locked** to the
  resolved `sqlite3` and `drift` packages. A mismatch does not fail the build —
  it throws at database open, i.e. a blank page. Re-run
  `.\tool\update_web_db_assets.ps1` after any `pub upgrade` that moves either.
- **`web/pdfjs/` is vendored** rather than loaded from the CDN that
  `pdfx:install_web` configures, so boarding passes still render at a gate
  with no signal.
- **The Maps browser key** goes in `web/config.js` (gitignored); the build
  script writes it from `android/local.properties`, same as `tool/run.ps1`.
- Anything Android-only degrades visibly rather than silently: reminders,
  biometric vault lock, share-into-Tripper, on-device OCR, and backup
  export/import are unavailable on web and say so in Settings.
- Icons: `.\tool\generate_web_icons.ps1` regenerates `web/icons` from the app
  palette and Fraunces.

## Rules (short version)

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`
- No `DateTime.now()` in domain code — inject `clockProvider`
- No hardcoded user-facing strings — ARB via `AppLocalizations`
- RTL-safe layouts only (`EdgeInsetsDirectional`, start/end)
- No core flow may block on the network (SPEC §3.1.2)
- Tests land in the same commit as the feature
