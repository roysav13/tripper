# Globe texture

`journal_globe.dart` expects an equirectangular Earth texture at
`assets/globe/earth_day.jpg` (bundled locally — never fetched at runtime,
per SPEC §3.1.2 offline rule).

This file is not included yet. Add a redistributable equirectangular
Earth image here before running the app — e.g. NASA's public-domain
"Blue Marble" (https://visibleearth.nasa.gov/collection/1484/blue-marble).
`flutter analyze`/`flutter run` will fail once `journal_globe.dart`
references this path if the image is missing.
