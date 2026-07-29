# Bundled fonts

Fonts are bundled as assets (never fetched at runtime — offline rule). All are OFL-licensed; keep the license files alongside.

Download and place here:

| Family | Files needed | Source |
|---|---|---|
| Fraunces | `Fraunces-Regular.ttf`, `Fraunces-SemiBold.ttf` (Google's static export has no Medium — we map styles to 400/600 instead) | https://fonts.google.com/specimen/Fraunces |
| IBM Plex Sans | `IBMPlexSans-Regular.ttf`, `IBMPlexSans-Medium.ttf`, `IBMPlexSans-SemiBold.ttf` | https://fonts.google.com/specimen/IBM+Plex+Sans |
| IBM Plex Mono | `IBMPlexMono-Regular.ttf`, `IBMPlexMono-Medium.ttf` | https://fonts.google.com/specimen/IBM+Plex+Mono |

These are declared in the `fonts:` block of `pubspec.yaml`. Adding or renaming a file means updating that block too.
