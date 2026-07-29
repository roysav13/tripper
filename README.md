# Tripper

Local-first Android travel companion: trips, document vault, wishlist & visited places.
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

## Rules (short version)

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`
- No `DateTime.now()` in domain code — inject `clockProvider`
- No hardcoded user-facing strings — ARB via `AppLocalizations`
- RTL-safe layouts only (`EdgeInsetsDirectional`, start/end)
- No core flow may block on the network (SPEC §3.1.2)
- Tests land in the same commit as the feature
