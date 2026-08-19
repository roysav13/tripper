# Google Maps List Share Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend Google Maps link sharing so a shared **list** (not just a single place) imports all of its places into Tripper, via both the existing Android share-intent flow and a new manual paste entry point.

**Architecture:** `MapsLinkService.expand()` now returns a sealed `MapsShareResult` (`MapsPlaceShare` | `MapsListShare`) instead of a bare `MapsLink?`. A list share can't be parsed from a URL alone — it's an opaque Google share token — so a new `MapsListScraper` interface (real impl: a headless `webview_flutter` WebView that scrolls Google's rendered list panel and reads place names back via injected JS) resolves it into place names. Those get deduplicated, geocoded through the existing `Geocoder`, and turned into `Place` rows grouped into a new `PlaceCollection`, via a new review screen (`MapsListImportScreen`). A small shared routing helper (`openMapsShareResult`) keeps the share-intent listener and the new manual-paste dialog from duplicating the place-vs-list branching.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, `webview_flutter` (new dependency), existing `http`/Nominatim/Google Places geocoding.

**Spec:** `docs/superpowers/specs/2026-08-19-google-maps-list-share-design.md`

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`; coral (`AppColors.accent`) is the only accent (CLAUDE.md rule 1).
- No `DateTime.now()` in domain code — inject via `clockProvider` (CLAUDE.md rule 2).
- Every user-facing string goes through ARB — **both** `lib/l10n/app_en.arb` and `lib/l10n/app_he.arb` (this repo already ships a real Hebrew translation, not just English — CLAUDE.md rule 3 predates that and is superseded by `docs/superpowers/specs/2026-08-11-hebrew-rtl-support-design.md`).
- Local data is always the source of truth; network calls enhance, never gate, and must degrade visibly — never a hanging spinner or hard error (CLAUDE.md rule 4).
- Tests land in the same commit as the feature; widget tests mock at the repository boundary (CLAUDE.md rule 5).
- Reuse `PaperCard`/`SectionLabel`/`MonoText`/`EmptyState`/`ErrorState`/`GlassChrome` primitives from `lib/core/widgets/` — no new primitives (CLAUDE.md rule 6).
- Verification: this plan's author (Claude) cannot run Flutter in this sandbox — the SDK download is network-blocked. Every task below still lists exact `flutter`/`dart` commands; whoever executes each step (the user locally, or CI) must actually run them and report real output before a step is marked done. Never mark a step complete on the basis of "this should work."
- After `pubspec.yaml` or any `.arb` file changes, `flutter pub get` / `flutter gen-l10n` must run before `flutter analyze`/`flutter test` will pass — `./scripts/verify.ps1` (no `-Quick`) runs the full sequence in one command.

---

## File Structure

**Create:**
- `lib/core/sharing/maps_list_scraper.dart` — `MapsListScraper` interface, `ScrapedMapsList`, pure title-cleaning helper, the real `WebViewMapsListScraper`, its provider.
- `lib/core/sharing/maps_share_routing.dart` — `openMapsShareResult()`, the single place-vs-list routing decision shared by the share-intent listener and the manual paste dialog.
- `lib/features/places/presentation/maps_list_import_screen.dart` — the review/import screen.
- `lib/features/places/presentation/import_maps_list_dialog.dart` — the manual "paste a link" dialog.
- `test/unit/places/maps_list_scraper_test.dart`
- `test/widget/places/maps_list_import_screen_test.dart`
- `test/widget/core/app_shell_test.dart`

**Modify:**
- `lib/core/sharing/maps_link.dart` — add `isMapsListShareUrl`, the sealed `MapsShareResult` hierarchy, change `MapsLinkService.expand()`'s return type and logic.
- `lib/core/widgets/app_shell.dart` — route through the sealed result via `openMapsShareResult`.
- `lib/core/routing/app_router.dart` — add `rootNavigatorKey`, needed by `WebViewMapsListScraper` to host its invisible WebView.
- `lib/features/places/presentation/places_screen.dart` — "+" button becomes a two-item menu (Add place / Import Google Maps list…).
- `pubspec.yaml` — add `webview_flutter`.
- `lib/l10n/app_en.arb`, `lib/l10n/app_he.arb` — new strings (generated `app_localizations*.dart` files are regenerated via `flutter gen-l10n`, never hand-edited).
- `test/unit/places/maps_link_test.dart` — update for the new return type; add list-share cases.
- `test/widget/places/places_screen_test.dart` — add menu/dialog coverage.

---

## Task 1: List-share detection and the sealed `MapsShareResult`

**Files:**
- Modify: `lib/core/sharing/maps_link.dart`
- Test: `test/unit/places/maps_link_test.dart`

**Interfaces:**
- Produces: `bool isMapsListShareUrl(String url)`; `sealed class MapsShareResult`; `class MapsPlaceShare extends MapsShareResult { MapsPlaceShare(this.link); final MapsLink link; }`; `class MapsListShare extends MapsShareResult { MapsListShare({required this.url, this.nameGuess}); final String url; final String? nameGuess; }`; `MapsLinkService.expand(String text) -> Future<MapsShareResult?>` (was `Future<MapsLink?>`).

- [ ] **Step 1: Write the failing tests**

Replace the two existing `expand()`-related assertions and add new list-detection/list-share cases. Edit `test/unit/places/maps_link_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/core/sharing/maps_link.dart';

void main() {
  group('parseMapsShare', () {
    test('full place URL with @coords and name', () {
      final link = parseMapsShare(
        'https://www.google.com/maps/place/Railay+Beach/@8.0119,98.8378,15z',
      );
      expect(link, isNotNull);
      expect(link!.name, 'Railay Beach');
      expect(link.lat, closeTo(8.0119, 0.0001));
      expect(link.lng, closeTo(98.8378, 0.0001));
    });

    test('q=lat,lng URL', () {
      final link =
          parseMapsShare('https://maps.google.com/maps?q=41.8902,12.4922');
      expect(link!.hasCoordinates, isTrue);
      expect(link.lat, closeTo(41.8902, 0.0001));
    });

    test('short link keeps surrounding text as name guess', () {
      final link = parseMapsShare(
        'Colosseum https://maps.app.goo.gl/AbCdEf123',
      );
      expect(link, isNotNull);
      expect(link!.hasCoordinates, isFalse);
      expect(link.name, 'Colosseum');
      expect(isShortMapsLink(link.url), isTrue);
    });

    test('non-maps URLs and plain text return null', () {
      expect(parseMapsShare('https://example.com/foo'), isNull);
      expect(parseMapsShare('just some text'), isNull);
    });
  });

  group('isMapsListShareUrl', () {
    test('matches a real captured list-share redirect target', () {
      expect(
        isMapsListShareUrl(
          'https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2'
          '!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3?entry=tts',
        ),
        isTrue,
      );
    });

    test('a single-place URL is not a list', () {
      expect(
        isMapsListShareUrl(
          'https://www.google.com/maps/place/Colosseum/@41.8902,12.4922,17z',
        ),
        isFalse,
      );
    });

    test('a non-maps URL is not a list', () {
      expect(isMapsListShareUrl('https://example.com/maps/@/data=x'), isFalse);
    });

    test('an unparseable URL is not a list', () {
      expect(isMapsListShareUrl('not a url at all'), isFalse);
    });
  });

  group('MapsLinkService.expand — place shares', () {
    test('short link resolves through redirect to coordinates', () async {
      final client = MockClient.streaming((request, _) async {
        if (request.url.host == 'maps.app.goo.gl') {
          return http.StreamedResponse(
            const Stream.empty(),
            302,
            headers: {
              'location':
                  'https://www.google.com/maps/place/Colosseum/@41.8902,12.4922,17z',
            },
          );
        }
        return http.StreamedResponse(const Stream.empty(), 200);
      });
      final service = MapsLinkService(client);
      final result =
          await service.expand('Colosseum https://maps.app.goo.gl/AbC');
      final share = result as MapsPlaceShare;
      expect(share.link.hasCoordinates, isTrue);
      expect(share.link.name, 'Colosseum');
      expect(share.link.lat, closeTo(41.8902, 0.0001));
    });

    test('network failure falls back to partial parse (offline)', () async {
      final client = MockClient.streaming(
        (request, _) async => throw Exception('offline'),
      );
      final service = MapsLinkService(client);
      final result =
          await service.expand('Colosseum https://maps.app.goo.gl/AbC');
      expect(result, isNotNull);
      final share = result as MapsPlaceShare;
      expect(share.link.hasCoordinates, isFalse);
      expect(share.link.name, 'Colosseum');
    });

    test('a full (non-short) URL never touches the network', () async {
      final client = MockClient.streaming(
        (request, _) async => fail('unexpected request to ${request.url}'),
      );
      final service = MapsLinkService(client);
      final result = await service.expand(
        'https://www.google.com/maps/place/Colosseum/@41.8902,12.4922,17z',
      );
      final share = result as MapsPlaceShare;
      expect(share.link.hasCoordinates, isTrue);
    });
  });

  group('MapsLinkService.expand — list shares', () {
    test('a directly-pasted list URL returns MapsListShare, no network call',
        () async {
      final client = MockClient.streaming(
        (request, _) async => fail('unexpected request to ${request.url}'),
      );
      final service = MapsLinkService(client);
      final result = await service.expand(
        'Japan https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2'
        '!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3',
      );
      expect(result, isA<MapsListShare>());
      final share = result as MapsListShare;
      expect(share.url, contains('!11m2!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3'));
      expect(share.nameGuess, 'Japan');
    });

    test('a short link resolving to a list-share URL returns MapsListShare '
        'without fetching the resolved page body', () async {
      final client = MockClient.streaming((request, _) async {
        if (request.url.host == 'maps.app.goo.gl') {
          return http.StreamedResponse(
            const Stream.empty(),
            302,
            headers: {
              'location': 'https://www.google.com/maps/@/data=!3m1!4b1!4m3'
                  '!11m2!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3?entry=tts',
            },
          );
        }
        fail('unexpected second request to ${request.url}');
      });
      final service = MapsLinkService(client);
      final result = await service
          .expand('Japan https://maps.app.goo.gl/gSpd52y9RYFDAspHA');
      expect(result, isA<MapsListShare>());
      final share = result as MapsListShare;
      expect(share.url, contains('!11m2!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3'));
      expect(share.nameGuess, 'Japan');
    });
  });

  group('googleMapsUri', () {
    test('builds a maps.google.com search URL from coordinates', () {
      final uri = googleMapsUri(8.0119, 98.8378);
      expect(
        uri.toString(),
        'https://www.google.com/maps/search/?api=1&query=8.0119,98.8378',
      );
    });

    test('handles negative coordinates', () {
      final uri = googleMapsUri(-33.8688, 151.2093);
      expect(uri.queryParameters['query'], '-33.8688,151.2093');
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/places/maps_link_test.dart`
Expected: compile errors (`isMapsListShareUrl`, `MapsPlaceShare`, `MapsListShare` undefined; `expand()` return type mismatch).

- [ ] **Step 3: Implement — rewrite `lib/core/sharing/maps_link.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Parsed Google Maps share: whatever we could extract.
@immutable
class MapsLink {
  const MapsLink({required this.url, this.name, this.lat, this.lng});

  final String url;
  final String? name;
  final double? lat;
  final double? lng;

  bool get hasCoordinates => lat != null && lng != null;
}

/// What [MapsLinkService.expand] resolves a share to: either one place, or
/// a whole list (Google Maps List share — see the design spec). Callers
/// (`app_shell.dart`'s share listener, the manual paste dialog) branch on
/// this via `openMapsShareResult` rather than duplicating the decision.
sealed class MapsShareResult {}

class MapsPlaceShare extends MapsShareResult {
  MapsPlaceShare(this.link);
  final MapsLink link;
}

class MapsListShare extends MapsShareResult {
  MapsListShare({required this.url, this.nameGuess});

  /// Resolved list URL — handed to `MapsListScraper.scrape`.
  final String url;

  /// Best-effort name from surrounding share text (e.g. "Check out my
  /// list! <link>") — often null; the scraper's own title takes priority.
  final String? nameGuess;
}

final _urlPattern = RegExp(r'https?://\S+');
final _atCoords = RegExp(r'@(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)');
final _qCoords = RegExp(r'^(-?\d{1,3}\.\d+),\s*(-?\d{1,3}\.\d+)$');

bool _isMapsHost(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == 'maps.app.goo.gl' ||
      host == 'goo.gl' ||
      host == 'maps.google.com' ||
      (host.contains('google.') && uri.path.contains('/maps'));
}

bool isShortMapsLink(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'maps.app.goo.gl' || host == 'goo.gl';
}

/// A Google Maps **list** share (Maps' "Share list") resolves to an opaque
/// share token, not coordinates — `/maps/@/data=!...!11m2!2s<id>!3e3!...`,
/// with no `/place/` segment. Confirmed against a real captured list link
/// during design (see the spec) — no rendering needed to tell these apart
/// from a single-place share, just the resolved URL shape.
bool isMapsListShareUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return uri.path.startsWith('/maps/@/data=') &&
      uri.path.contains('!11m2!2s') &&
      uri.path.contains('!3e3');
}

/// Pure parser (unit-tested): pulls a Maps URL out of shared text and
/// extracts coordinates + place name where the URL embeds them.
/// Returns null when the text contains no Maps link at all.
MapsLink? parseMapsShare(String text) {
  final urlMatch = _urlPattern.firstMatch(text);
  if (urlMatch == null) return null;
  final url = urlMatch.group(0)!;
  final uri = Uri.tryParse(url);
  if (uri == null || !_isMapsHost(uri)) return null;

  double? lat;
  double? lng;
  final at = _atCoords.firstMatch(url);
  if (at != null) {
    lat = double.tryParse(at.group(1)!);
    lng = double.tryParse(at.group(2)!);
  } else {
    final q = uri.queryParameters['q'] ?? uri.queryParameters['query'];
    final qMatch = q == null ? null : _qCoords.firstMatch(q.trim());
    if (qMatch != null) {
      lat = double.tryParse(qMatch.group(1)!);
      lng = double.tryParse(qMatch.group(2)!);
    }
  }

  String? name;
  final segments = uri.pathSegments;
  final placeIndex = segments.indexOf('place');
  if (placeIndex != -1 && placeIndex + 1 < segments.length) {
    name = Uri.decodeComponent(segments[placeIndex + 1])
        .replaceAll('+', ' ')
        .trim();
    if (name.isEmpty || _atCoords.hasMatch(name)) name = null;
  }
  // Shared text often reads "Check out <name>! <url>" — fall back to it.
  name ??= text.replaceAll(url, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (name.isEmpty) name = null;

  return MapsLink(url: url, name: name, lat: lat, lng: lng);
}

/// Expands short links (maps.app.goo.gl) by following redirects — the only
/// other network call in the app (SPEC §3.1.2). Offline or on any failure
/// it returns the partial parse so the flow never dead-ends.
class MapsLinkService {
  MapsLinkService(this._client);

  final http.Client _client;

  Future<MapsShareResult?> expand(String text) async {
    final link = parseMapsShare(text);
    if (link == null) return null;
    // A pasted/shared list link is recognizable before any resolution —
    // check it first so a directly-pasted (non-short) list URL never
    // falls through to place parsing.
    if (isMapsListShareUrl(link.url)) {
      return MapsListShare(url: link.url, nameGuess: link.name);
    }
    if (link.hasCoordinates || !isShortMapsLink(link.url)) {
      return MapsPlaceShare(link);
    }
    try {
      final resolved = await _resolveRedirects(link.url);
      if (isMapsListShareUrl(resolved)) {
        return MapsListShare(url: resolved, nameGuess: link.name);
      }
      final expanded = parseMapsShare(resolved);
      if (expanded == null) return MapsPlaceShare(link);
      return MapsPlaceShare(
        MapsLink(
          url: link.url,
          name: expanded.name ?? link.name,
          lat: expanded.lat,
          lng: expanded.lng,
        ),
      );
    } catch (_) {
      return MapsPlaceShare(link); // offline fallback: name + url only, "locate later"
    }
  }

  /// Follows redirects; when the chain ends on an HTML page (Google often
  /// serves one instead of a final 302) the body is scanned for the real
  /// maps URL or a coordinate pair.
  Future<String> _resolveRedirects(String url) async {
    var current = url;
    for (var i = 0; i < 6; i++) {
      final request = http.Request('GET', Uri.parse(current))
        ..followRedirects = false
        ..headers['User-Agent'] = 'Mozilla/5.0 (Android) tripper/0.1';
      final response =
          await _client.send(request).timeout(const Duration(seconds: 8));
      final location = response.headers['location'];
      if (location != null) {
        current = Uri.parse(current).resolve(location).toString();
        // Already carries coordinates, or is a list share (nothing useful
        // to read from the body either way) — stop early.
        if (_atCoords.hasMatch(current) || isMapsListShareUrl(current)) {
          return current;
        }
        continue;
      }
      final body = await response.stream.bytesToString();
      return _extractFromBody(body) ?? current;
    }
    return current;
  }

  /// Pulls the first embedded maps URL or @lat,lng out of an HTML body.
  static String? _extractFromBody(String body) {
    final urlMatch = RegExp(
      r'https://www\.google\.com/maps[^"\\\s<]+',
    ).firstMatch(body);
    if (urlMatch != null) {
      return urlMatch.group(0)!.replaceAll(r'&', '&');
    }
    final coords = _atCoords.firstMatch(body);
    if (coords != null) {
      return 'https://www.google.com/maps/@${coords.group(1)},'
          '${coords.group(2)},15z';
    }
    return null;
  }
}

final mapsLinkServiceProvider =
    Provider<MapsLinkService>((ref) => MapsLinkService(http.Client()));

/// Builds a Google Maps URL that opens [lat],[lng] directly — the
/// opposite direction from [parseMapsShare]: this app already HAS
/// coordinates and wants to hand off to the real Maps app/website, not
/// parse an incoming link. Always the same well-known URL shape, never
/// fetched or cached.
Uri googleMapsUri(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/places/maps_link_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/core/sharing/maps_link.dart test/unit/places/maps_link_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/core/sharing/maps_link.dart test/unit/places/maps_link_test.dart
git commit -m "feat(sharing): detect Google Maps list shares

MapsLinkService.expand() now returns a sealed MapsShareResult
(MapsPlaceShare | MapsListShare) instead of a bare MapsLink?, so a
shared Google Maps list can be told apart from a single place right
after redirect resolution -- no rendering needed."
```

---

## Task 2: Add l10n strings for the import flow

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_he.arb`
- (generated) `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_he.dart` — regenerated, never hand-edited.

**Interfaces:**
- Produces (as generated `AppLocalizations` getters/methods, used by Tasks 4–6): `placesAddButtonTooltip`, `placesMenuAddPlace`, `placesMenuImportList`, `importListDialogTitle`, `importListDialogHint`, `importListDialogImport`, `importListDialogInvalidLink`, `mapsListImportTitle`, `mapsListImportScraping`, `mapsListImportFailedBody`, `String mapsListImportSelectedCount(int n)`, `String mapsListImportButton(int n)`, `String mapsListImportProgress(int done, int total)`.

- [ ] **Step 1: Add the English strings**

Edit `lib/l10n/app_en.arb` — insert before the final closing `}` (after `"journalNewLocation": "New location"`):

```json
  "journalNewLocation": "New location",
  "placesAddButtonTooltip": "Add",
  "placesMenuAddPlace": "Add place",
  "placesMenuImportList": "Import Google Maps list…",
  "importListDialogTitle": "Import Google Maps list",
  "importListDialogHint": "Paste a Google Maps list link",
  "importListDialogImport": "Import",
  "importListDialogInvalidLink": "That doesn't look like a Google Maps link",
  "mapsListImportTitle": "Import list",
  "mapsListImportScraping": "Reading list…",
  "mapsListImportFailedBody": "Couldn't read this list from Google Maps — try sharing individual places instead",
  "mapsListImportSelectedCount": "{n} selected",
  "@mapsListImportSelectedCount": {
    "placeholders": {
      "n": { "type": "int" }
    }
  },
  "mapsListImportButton": "Import {n} places",
  "@mapsListImportButton": {
    "placeholders": {
      "n": { "type": "int" }
    }
  },
  "mapsListImportProgress": "{done} / {total} located",
  "@mapsListImportProgress": {
    "placeholders": {
      "done": { "type": "int" },
      "total": { "type": "int" }
    }
  }
}
```

- [ ] **Step 2: Add the Hebrew strings**

Edit `lib/l10n/app_he.arb` — same insertion point (after `"journalNewLocation": "מיקום חדש"`):

```json
  "journalNewLocation": "מיקום חדש",
  "placesAddButtonTooltip": "הוספה",
  "placesMenuAddPlace": "הוספת מקום",
  "placesMenuImportList": "ייבוא רשימת Google Maps…",
  "importListDialogTitle": "ייבוא רשימת Google Maps",
  "importListDialogHint": "הדבקת קישור לרשימת Google Maps",
  "importListDialogImport": "ייבוא",
  "importListDialogInvalidLink": "זה לא נראה כמו קישור של Google Maps",
  "mapsListImportTitle": "ייבוא רשימה",
  "mapsListImportScraping": "קוראים את הרשימה…",
  "mapsListImportFailedBody": "לא הצלחנו לקרוא את הרשימה הזו מ-Google Maps. אפשר לנסות לשתף מקומות בנפרד",
  "mapsListImportSelectedCount": "{n} נבחרו",
  "@mapsListImportSelectedCount": {
    "placeholders": {
      "n": { "type": "int" }
    }
  },
  "mapsListImportButton": "ייבוא {n} מקומות",
  "@mapsListImportButton": {
    "placeholders": {
      "n": { "type": "int" }
    }
  },
  "mapsListImportProgress": "{done} מתוך {total} אותרו",
  "@mapsListImportProgress": {
    "placeholders": {
      "done": { "type": "int" },
      "total": { "type": "int" }
    }
  }
}
```

- [ ] **Step 3: Regenerate the localization Dart files**

Run: `flutter gen-l10n`
Expected: completes with no errors; `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_he.dart` are rewritten with the 13 new members.

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/l10n`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add strings for Google Maps list import"
```

---

## Task 3: `MapsListScraper` — interface, WebView implementation, and wiring

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/routing/app_router.dart`
- Create: `lib/core/sharing/maps_list_scraper.dart`
- Test: `test/unit/places/maps_list_scraper_test.dart`

**Interfaces:**
- Consumes: `rootNavigatorKey` (from `app_router.dart`, this task).
- Produces: `abstract interface class MapsListScraper { Future<ScrapedMapsList?> scrape(String listUrl); }`; `class ScrapedMapsList { final String? title; final List<String> placeNames; }`; `String? cleanScrapedListTitle(String? documentTitle)`; `class WebViewMapsListScraper implements MapsListScraper`; `final mapsListScraperProvider = Provider<MapsListScraper>(...)`.

- [ ] **Step 1: Add the dependency**

Edit `pubspec.yaml` — add after the `geolocator` line:

```yaml
  geolocator: ^13.0.2
  webview_flutter: ^4.14.1
```

Run: `flutter pub get`
Expected: resolves successfully.

- [ ] **Step 2: Add a root navigator key**

`WebViewMapsListScraper` needs to host an invisible `WebViewWidget` somewhere in the tree (Android/Flutter can't run a WebView off-tree), without the `MapsListScraper.scrape(String)` interface taking a `BuildContext` — that would make it impossible to fake cleanly and awkward to call from deep async flows. A `GlobalKey<NavigatorState>` on the app's root navigator solves this. Edit `lib/core/routing/app_router.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/places/presentation/places_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/trips/domain/trip.dart';
import '../../features/trips/presentation/trip_detail_screen.dart';
import '../../features/trips/presentation/trip_form_screen.dart';
import '../../features/trips/presentation/trip_list_screen.dart';
import '../../features/vault/presentation/vault_screen.dart';
import '../widgets/app_shell.dart';

/// Lets code with no BuildContext of its own (`WebViewMapsListScraper`)
/// push a route on the app's real navigator.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/trips',
    routes: [
```

(Everything else in the file — the routes list — is unchanged; only the `import 'package:flutter/widgets.dart';` import, the `rootNavigatorKey` top-level field, and the `navigatorKey: rootNavigatorKey,` line are new.)

- [ ] **Step 3: Write the failing test for the pure title helper**

Create `test/unit/places/maps_list_scraper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/sharing/maps_list_scraper.dart';

void main() {
  group('cleanScrapedListTitle', () {
    test('strips the Google Maps suffix', () {
      expect(cleanScrapedListTitle('Japan - Google Maps'), 'Japan');
    });

    test('returns the title unchanged when there is no suffix', () {
      expect(cleanScrapedListTitle('Japan'), 'Japan');
    });

    test('null input returns null', () {
      expect(cleanScrapedListTitle(null), isNull);
    });

    test('empty or suffix-only title returns null', () {
      expect(cleanScrapedListTitle(''), isNull);
      expect(cleanScrapedListTitle(' - Google Maps'), isNull);
    });
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/unit/places/maps_list_scraper_test.dart`
Expected: FAIL — `maps_list_scraper.dart` does not exist yet.

- [ ] **Step 5: Implement — create `lib/core/sharing/maps_list_scraper.dart`**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../routing/app_router.dart';

/// What a shared Google Maps list scrapes down to: a title guess and the
/// place names found in its (virtualized) list panel. No coordinates —
/// Google's DOM never carries them, only names/ratings/category text
/// (confirmed during design against a real shared list — see the spec).
@immutable
class ScrapedMapsList {
  const ScrapedMapsList({required this.title, required this.placeNames});

  final String? title;
  final List<String> placeNames;
}

/// Widget/unit tests fake at this boundary — the real implementation talks
/// to a live Google Maps page via a WebView and cannot itself be
/// unit-tested (see the design spec's Testing section).
abstract interface class MapsListScraper {
  /// Returns null on any failure (timeout, offline, unreadable page) —
  /// never throws. [listUrl] is the resolved `MapsListShare.url`.
  Future<ScrapedMapsList?> scrape(String listUrl);
}

/// Strips Google's known " - Google Maps" document-title suffix (present
/// because [WebViewMapsListScraper] forces `hl=en`). Pure, unit-tested
/// separately from the WebView plumbing around it.
String? cleanScrapedListTitle(String? documentTitle) {
  if (documentTitle == null) return null;
  var title = documentTitle.trim();
  const suffix = ' - Google Maps';
  if (title.endsWith(suffix)) {
    title = title.substring(0, title.length - suffix.length).trim();
  }
  return title.isEmpty ? null : title;
}

/// Forces English UI locale on a Google Maps URL — scraped text stays in
/// Latin script regardless of the sharer's Google account locale.
Uri _withEnglishLocale(String url) {
  final uri = Uri.parse(url);
  return uri.replace(
    queryParameters: {...uri.queryParameters, 'hl': 'en'},
  );
}

const _maxScrollIterations = 30;
const _scrapeTimeout = Duration(seconds: 20);

/// Google's list panel — verified during design against a real shared
/// list, but this is exactly the "unstable, obfuscated DOM" the spec
/// flags as this feature's most fragile piece. If a future Maps layout
/// change breaks this selector, `_readVisibleNames` returns an empty
/// batch (not a crash) and `scrape()` degrades to `null` — adjust this
/// constant against a real shared list link if that happens.
const _feedSelector = '[role="feed"]';
const _placeNameSelector =
    '$_feedSelector [role="button"] > div > div:first-child';

/// Scrolls a shared Google Maps list's place panel and reads back place
/// names via an injected JS loop. Every failure mode here (timeout,
/// missing elements, malformed result) degrades to `null`, never a crash
/// or a hang (CLAUDE.md hard rule 4) — this class is explicitly not
/// unit-testable; see the spec's Testing section.
class WebViewMapsListScraper implements MapsListScraper {
  @override
  Future<ScrapedMapsList?> scrape(String listUrl) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return null;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    final completer = Completer<ScrapedMapsList?>();
    var settled = false;
    void complete(ScrapedMapsList? result) {
      if (settled) return;
      settled = true;
      completer.complete(result);
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) async {
          try {
            complete(await _collect(controller));
          } catch (_) {
            complete(null);
          }
        },
        onWebResourceError: (_) => complete(null),
      ),
    );

    final route = PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, __, ___) => IgnorePointer(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: WebViewWidget(controller: controller),
            ),
          ),
        ),
      ),
    );
    unawaited(navigator.push(route));

    final overallTimeout = Timer(_scrapeTimeout, () => complete(null));
    unawaited(
      controller.loadRequest(_withEnglishLocale(listUrl)).catchError((_) {
        complete(null);
      }),
    );

    final result = await completer.future;
    overallTimeout.cancel();
    if (navigator.canPop()) navigator.pop();
    return result;
  }

  Future<ScrapedMapsList?> _collect(WebViewController controller) async {
    final rawTitle = await controller.getTitle();
    final names = <String>{};
    for (var i = 0; i < _maxScrollIterations; i++) {
      final before = names.length;
      names.addAll(await _readVisibleNames(controller));
      if (names.length == before && i > 0) break;
      await controller.runJavaScript(
        "document.querySelector('$_feedSelector')?.scrollBy(0, 800);",
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (names.isEmpty) return null;
    return ScrapedMapsList(
      title: cleanScrapedListTitle(rawTitle),
      placeNames: names.toList(),
    );
  }

  Future<List<String>> _readVisibleNames(WebViewController controller) async {
    try {
      final raw = await controller.runJavaScriptReturningResult(
        "JSON.stringify(Array.from(document.querySelectorAll("
        "'$_placeNameSelector')).map(e => e.textContent.trim())"
        ".filter(t => t.length > 0))",
      );
      // Android's WebView can return a JSON-encoded *string literal*
      // (quotes escaped) rather than raw JSON for a runJavaScript result —
      // decode twice when that's the shape.
      var value = raw is String ? raw : raw.toString();
      try {
        final once = jsonDecode(value);
        if (once is String) value = once;
      } catch (_) {
        // Already the right shape.
      }
      final list = jsonDecode(value);
      if (list is List) return list.whereType<String>().toList();
    } catch (_) {
      // Malformed/unexpected JS result — treat as "found nothing this
      // pass", not a fatal error (the loop's stability check handles it).
    }
    return const [];
  }
}

final mapsListScraperProvider = Provider<MapsListScraper>(
  (ref) => WebViewMapsListScraper(),
);
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/unit/places/maps_list_scraper_test.dart`
Expected: PASS.

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/core/sharing/maps_list_scraper.dart lib/core/routing/app_router.dart`
Expected: No issues found.

- [ ] **Step 8: Manual verification note (cannot be automated)**

`WebViewMapsListScraper`'s actual scraping behavior against a live Google Maps page is not unit-testable (no fake platform channel for a real, rendered Google product). Before relying on this in production, manually verify by sharing a real Google Maps list into a debug build and confirming `_placeNameSelector` still matches — adjust the constant in `maps_list_scraper.dart` if Google's markup has moved. Record the outcome in the PR/commit description; do not claim this task "works end-to-end" without having done this.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/routing/app_router.dart \
  lib/core/sharing/maps_list_scraper.dart test/unit/places/maps_list_scraper_test.dart
git commit -m "feat(sharing): add MapsListScraper and its WebView implementation

Adds webview_flutter to headlessly render a shared Google Maps list
and scrape its place names back out via injected JS -- the list's
contents aren't reachable any other way (see the design spec's
Problem section). Behind an interface so everything downstream of it
stays unit/widget-testable without a real WebView."
```

---

## Task 4: `MapsListImportScreen` — review UI and import action

**Files:**
- Create: `lib/features/places/presentation/maps_list_import_screen.dart`
- Test: `test/widget/places/maps_list_import_screen_test.dart`

**Interfaces:**
- Consumes: `MapsListScraper`/`mapsListScraperProvider` (Task 3); `Geocoder`/`GeoResult`/`geocoderProvider` (`lib/features/places/data/geocoding_service.dart`, existing); `PlaceRepository`/`placeRepositoryProvider` (existing); `PlaceCollectionRepository`/`placeCollectionRepositoryProvider` (existing); `tripListProvider` (existing).
- Produces: `class MapsListImportScreen extends ConsumerStatefulWidget { const MapsListImportScreen({super.key, required this.url, this.nameGuess}); final String url; final String? nameGuess; static Future<void> open(BuildContext context, {required String url, String? nameGuess}); }`.

- [ ] **Step 1: Write the failing widget tests**

Create `test/widget/places/maps_list_import_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/sharing/maps_list_scraper.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/presentation/maps_list_import_screen.dart';
import 'package:tripper/features/places/presentation/place_collection_providers.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_collection_repository.dart';
import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';

class _FakeScraper implements MapsListScraper {
  _FakeScraper(this.result);
  final ScrapedMapsList? result;
  int callCount = 0;

  @override
  Future<ScrapedMapsList?> scrape(String listUrl) async {
    callCount++;
    return result;
  }
}

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder(this.hits);
  final Map<String, GeoResult> hits;
  final List<String> queries = [];

  @override
  Future<List<GeoResult>> search(String query) async {
    queries.add(query);
    final hit = hits[query];
    return hit == null ? const [] : [hit];
  }

  @override
  Future<GeoResult?> reverse(double lat, double lon) async => null;

  @override
  Future<GeoResult?> details(String placeId) async => null;
}

const _senso = GeoResult(
  name: 'Sensō-ji',
  displayName: 'Sensō-ji, Tokyo, Japan',
  lat: 35.7148,
  lon: 139.7967,
  country: 'Japan',
  city: 'Tokyo',
);

const _fuji = GeoResult(
  name: 'Mt. Fuji',
  displayName: 'Mt. Fuji, Japan',
  lat: 35.3606,
  lon: 138.7274,
  country: 'Japan',
  city: '',
);

Widget _app({
  required MapsListScraper scraper,
  required Geocoder geocoder,
  FakePlaceRepository? placeRepo,
  FakePlaceCollectionRepository? collectionRepo,
  List<Trip> trips = const [],
  String url = 'https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2!2sX!3e3',
  String? nameGuess,
}) =>
    ProviderScope(
      overrides: [
        mapsListScraperProvider.overrideWithValue(scraper),
        geocoderProvider.overrideWithValue(geocoder),
        placeRepositoryProvider
            .overrideWithValue(placeRepo ?? FakePlaceRepository([])),
        placeCollectionRepositoryProvider.overrideWithValue(
          collectionRepo ?? FakePlaceCollectionRepository([]),
        ),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository(trips)),
        clockProvider.overrideWithValue(() => DateTime(2026, 8, 20)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MapsListImportScreen(url: url, nameGuess: nameGuess),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('scraping state shows progress copy', (tester) async {
    final scraper = _FakeScraper(null); // never resolves during this pump
    await tester.pumpWidget(
      _app(scraper: scraper, geocoder: _FakeGeocoder(const {})),
    );
    await tester.pump();
    expect(find.text('Reading list…'), findsOneWidget);
  });

  testWidgets('scrape failure shows the failure message', (tester) async {
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(null),
        geocoder: _FakeGeocoder(const {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Couldn't read this list from Google Maps — try sharing individual "
        'places instead',
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty scrape result is treated as failure', (tester) async {
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(title: 'Japan', placeNames: []),
        ),
        geocoder: _FakeGeocoder(const {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't read this list from Google Maps — try sharing individual places instead"),
        findsOneWidget);
  });

  testWidgets('successful scrape shows the checklist, all checked by default',
      (tester) async {
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Mt. Fuji'],
          ),
        ),
        geocoder: _FakeGeocoder(const {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sensō-ji'), findsOneWidget);
    expect(find.text('Mt. Fuji'), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'List name'), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget); // prefilled title
  });

  testWidgets('unchecking a place updates the selected count and import label',
      (tester) async {
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Mt. Fuji'],
          ),
        ),
        geocoder: _FakeGeocoder(const {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Mt. Fuji'));
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Import 1 places'), findsOneWidget);
  });

  testWidgets(
      'importing geocodes selected names, creates places + a collection, '
      'then closes the screen', (tester) async {
    final geocoder = _FakeGeocoder({
      'Sensō-ji': _senso,
      'Mt. Fuji': _fuji,
    });
    final placeRepo = FakePlaceRepository([]);
    final collectionRepo = FakePlaceCollectionRepository([]);
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Mt. Fuji'],
          ),
        ),
        geocoder: geocoder,
        placeRepo: placeRepo,
        collectionRepo: collectionRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 2 places'));
    await tester.pump();
    // Two unique names geocoded sequentially with a rate-limit delay
    // between calls.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(placeRepo.watchAll(), emits(hasLength(2)));
    final created = await placeRepo.watchAll().first;
    final byName = {for (final p in created) p.name: p};
    expect(byName['Sensō-ji']!.lat, closeTo(35.7148, 0.0001));
    expect(byName['Mt. Fuji']!.city, '');
    final collections = await collectionRepo.watchAll().first;
    expect(collections, hasLength(1));
    expect(collections.single.name, 'Japan');
    final memberships = await collectionRepo.watchMembershipsByPlace().first;
    expect(memberships[byName['Sensō-ji']!.id], {collections.single.id});
    expect(memberships[byName['Mt. Fuji']!.id], {collections.single.id});
    // Screen closed itself.
    expect(find.byType(MapsListImportScreen), findsNothing);
  });

  testWidgets('a name that fails to geocode still imports, name-only',
      (tester) async {
    final placeRepo = FakePlaceRepository([]);
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(title: 'Japan', placeNames: ['Nowhereville']),
        ),
        geocoder: _FakeGeocoder(const {}), // no hits at all
        placeRepo: placeRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 1 places'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    final created = await placeRepo.watchAll().first;
    expect(created.single.name, 'Nowhereville');
    expect(created.single.lat, isNull);
  });

  testWidgets('duplicate names are geocoded only once', (tester) async {
    final geocoder = _FakeGeocoder({'Sensō-ji': _senso});
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Sensō-ji', ' sensō-ji '],
          ),
        ),
        geocoder: geocoder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 3 places'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(geocoder.queries, hasLength(1));
  });

  testWidgets('cancelling during review writes nothing', (tester) async {
    final placeRepo = FakePlaceRepository([]);
    final collectionRepo = FakePlaceCollectionRepository([]);
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(title: 'Japan', placeNames: ['Sensō-ji']),
        ),
        geocoder: _FakeGeocoder(const {}),
        placeRepo: placeRepo,
        collectionRepo: collectionRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(await placeRepo.watchAll().first, isEmpty);
    expect(await collectionRepo.watchAll().first, isEmpty);
  });

  testWidgets('an available trip can be picked and is applied to every place',
      (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Japan trip',
      destinations: const ['Japan'],
    );
    final placeRepo = FakePlaceRepository([]);
    await tester.pumpWidget(
      _app(
        scraper: _FakeScraper(
          const ScrapedMapsList(
            title: 'Japan',
            placeNames: ['Sensō-ji', 'Mt. Fuji'],
          ),
        ),
        geocoder: _FakeGeocoder({'Sensō-ji': _senso, 'Mt. Fuji': _fuji}),
        placeRepo: placeRepo,
        trips: [trip],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Japan trip'));
    await tester.pump();
    await tester.tap(find.text('Import 2 places'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    final created = await placeRepo.watchAll().first;
    expect(created.every((p) => p.tripId == 't1'), isTrue);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/widget/places/maps_list_import_screen_test.dart`
Expected: FAIL — `maps_list_import_screen.dart` does not exist yet.

- [ ] **Step 3: Implement — create `lib/features/places/presentation/maps_list_import_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sharing/maps_list_scraper.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/presentation/trip_providers.dart';
import '../data/geocoding_service.dart';
import 'place_collection_providers.dart';
import 'place_providers.dart';

enum _Stage { scraping, failed, review, importing }

/// Reviews a scraped Google Maps list and imports the selected places, all
/// grouped into one new [PlaceCollection] named after the list (SPEC:
/// docs/superpowers/specs/2026-08-19-google-maps-list-share-design.md §4).
class MapsListImportScreen extends ConsumerStatefulWidget {
  const MapsListImportScreen({super.key, required this.url, this.nameGuess});

  final String url;
  final String? nameGuess;

  static Future<void> open(
    BuildContext context, {
    required String url,
    String? nameGuess,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) =>
            MapsListImportScreen(url: url, nameGuess: nameGuess),
      ),
    );
  }

  @override
  ConsumerState<MapsListImportScreen> createState() =>
      _MapsListImportScreenState();
}

class _MapsListImportScreenState extends ConsumerState<MapsListImportScreen> {
  _Stage _stage = _Stage.scraping;
  final _title = TextEditingController();
  bool _titleError = false;
  List<String> _names = const [];
  // Indices into _names, not names themselves -- a Set<String> would
  // collapse two literally-identical place names in the same list into
  // one togglable row, which is wrong (they're still two separate places
  // to import). Index-based selection keeps every row independently
  // checkable regardless of name collisions.
  final Set<int> _checked = {};
  String? _tripId;
  int _geocoded = 0;
  int _geocodeTotal = 0;

  @override
  void initState() {
    super.initState();
    _scrape();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _scrape() async {
    final result = await ref.read(mapsListScraperProvider).scrape(widget.url);
    if (!mounted) return;
    if (result == null || result.placeNames.isEmpty) {
      setState(() => _stage = _Stage.failed);
      return;
    }
    setState(() {
      _title.text = result.title ?? widget.nameGuess ?? '';
      _names = result.placeNames;
      _checked
        ..clear()
        ..addAll(List.generate(_names.length, (i) => i));
      _stage = _Stage.review;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapsListImportTitle)),
      body: switch (_stage) {
        _Stage.scraping => _progress(l10n.mapsListImportScraping),
        _Stage.failed => ErrorState(body: l10n.mapsListImportFailedBody),
        _Stage.review => _reviewBody(l10n),
        _Stage.importing => _progress(
            l10n.mapsListImportProgress(_geocoded, _geocodeTotal),
          ),
      },
    );
  }

  Widget _progress(String label) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(label),
          ],
        ),
      );

  Widget _reviewBody(AppLocalizations l10n) {
    final trips = (ref.watch(tripListProvider).valueOrNull ?? [])
        .where((t) => !t.archived)
        .toList();
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.newListDialogNameLabel,
            errorText: _titleError ? l10n.errNameRequired : null,
          ),
        ),
        if (trips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding:
                      const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(l10n.placeFormNoTrip),
                    selected: _tripId == null,
                    onSelected: (_) => setState(() => _tripId = null),
                  ),
                ),
                for (final trip in trips)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(trip.name),
                      selected: _tripId == trip.id,
                      onSelected: (_) => setState(() => _tripId = trip.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        MonoText(
          l10n.mapsListImportSelectedCount(_checked.length),
          muted: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _names.length; i++)
          CheckboxListTile(
            value: _checked.contains(i),
            title: Text(_names[i]),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _checked.add(i);
              } else {
                _checked.remove(i);
              }
            }),
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _checked.isEmpty ? null : _import,
          child: Text(l10n.mapsListImportButton(_checked.length)),
        ),
      ],
    );
  }

  static String _dedupeKey(String name) => name.trim().toLowerCase();

  Future<void> _import() async {
    final selected = [
      for (var i = 0; i < _names.length; i++)
        if (_checked.contains(i)) _names[i],
    ];
    if (selected.isEmpty) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }

    final uniqueKeys = selected.map(_dedupeKey).toSet();
    setState(() {
      _stage = _Stage.importing;
      _geocoded = 0;
      _geocodeTotal = uniqueKeys.length;
    });

    final geocoder = ref.read(geocoderProvider);
    final placeRepo = ref.read(placeRepositoryProvider);
    final collectionRepo = ref.read(placeCollectionRepositoryProvider);
    final tripId = _tripId;

    // One geocode call per *unique* name (SPEC §3) — Nominatim's usage
    // policy forbids bursts, hence the delay between calls.
    final geocoded = <String, GeoResult?>{};
    for (final key in uniqueKeys) {
      if (!mounted) return;
      final name = selected.firstWhere((n) => _dedupeKey(n) == key);
      GeoResult? hit;
      try {
        final results = await geocoder.search(name);
        var first = results.isEmpty ? null : results.first;
        if (first != null && first.needsDetails) {
          first = await geocoder.details(first.placeId!) ?? first;
        }
        hit = (first != null && !first.needsDetails) ? first : null;
      } catch (_) {
        hit = null;
      }
      if (!mounted) return;
      geocoded[key] = hit;
      setState(() => _geocoded++);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }

    if (!mounted) return;
    final placeIds = <String>[];
    for (final name in selected) {
      final hit = geocoded[_dedupeKey(name)];
      final id = await placeRepo.createPlace(
        name: name,
        country: hit?.country ?? '',
        city: hit?.city ?? '',
        lat: hit?.lat,
        lng: hit?.lon,
        tripId: tripId,
      );
      if (!mounted) return;
      placeIds.add(id);
    }

    final collectionId = await collectionRepo.createCollection(name: title);
    for (final id in placeIds) {
      if (!mounted) return;
      await collectionRepo.setCollectionsForPlace(id, {collectionId});
    }
    if (mounted) Navigator.of(context).pop();
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/widget/places/maps_list_import_screen_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/places/presentation/maps_list_import_screen.dart test/widget/places/maps_list_import_screen_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/places/presentation/maps_list_import_screen.dart \
  test/widget/places/maps_list_import_screen_test.dart
git commit -m "feat(places): add MapsListImportScreen

Review-and-import screen for a scraped Google Maps list: editable
title, checklist of place names (checked by default), optional trip
picker. Confirming dedupes + geocodes the selected names through the
existing Geocoder, creates each as a Place, and groups them into one
new PlaceCollection named after the list."
```

---

## Task 5: Manual paste entry point

**Files:**
- Create: `lib/core/sharing/maps_share_routing.dart`
- Create: `lib/features/places/presentation/import_maps_list_dialog.dart`
- Modify: `lib/features/places/presentation/places_screen.dart`
- Test: `test/widget/places/places_screen_test.dart`

**Interfaces:**
- Consumes: `MapsShareResult`/`MapsPlaceShare`/`MapsListShare`/`mapsLinkServiceProvider` (Task 1); `AddPlaceScreen.open` (existing); `MapsListImportScreen.open` (Task 4); `enrichSharedPlace`/`geocoderProvider` (existing).
- Produces: `Future<void> openMapsShareResult(BuildContext context, WidgetRef ref, MapsShareResult result)`; `Future<MapsShareResult?> promptMapsListUrl(BuildContext context, WidgetRef ref)`.

- [ ] **Step 1: Create the shared routing helper**

Create `lib/core/sharing/maps_share_routing.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/places/data/geocoding_service.dart';
import '../../features/places/presentation/add_place_screen.dart';
import '../../features/places/presentation/maps_list_import_screen.dart';
import 'maps_link.dart';

/// Opens the right screen for a parsed Google Maps share — shared by the
/// share-intent listener (`app_shell.dart`) and the manual paste dialog
/// (`import_maps_list_dialog.dart`) so the place-vs-list routing decision
/// isn't duplicated between them.
Future<void> openMapsShareResult(
  BuildContext context,
  WidgetRef ref,
  MapsShareResult result,
) async {
  switch (result) {
    case MapsPlaceShare(:final link):
      final prefill = await enrichSharedPlace(
        geocoder: ref.read(geocoderProvider),
        name: link.name,
        lat: link.lat,
        lng: link.lng,
      );
      if (!context.mounted) return;
      await AddPlaceScreen.open(
        context,
        initialName: prefill.name,
        initialLat: prefill.lat,
        initialLng: prefill.lng,
        initialCountry: prefill.country,
        initialCity: prefill.city,
        initialNotes: prefill.lat == null ? link.url : '',
      );
    case MapsListShare(:final url, :final nameGuess):
      await MapsListImportScreen.open(context, url: url, nameGuess: nameGuess);
  }
}
```

- [ ] **Step 2: Create the paste dialog**

Create `lib/features/places/presentation/import_maps_list_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sharing/maps_link.dart';
import '../../../l10n/app_localizations.dart';

/// Paste-a-link entry point for Google Maps sharing (mirrors the
/// share-intent flow — same `MapsLinkService.expand()` parse, just
/// triggered by pasting instead of Android's share sheet). Returns the
/// parsed share result, or null if the user cancelled.
Future<MapsShareResult?> promptMapsListUrl(
  BuildContext context,
  WidgetRef ref,
) {
  final controller = TextEditingController();
  return showDialog<MapsShareResult>(
    context: context,
    builder: (context) => _MapsUrlDialog(controller: controller, ref: ref),
  );
}

class _MapsUrlDialog extends StatefulWidget {
  const _MapsUrlDialog({required this.controller, required this.ref});

  final TextEditingController controller;
  final WidgetRef ref;

  @override
  State<_MapsUrlDialog> createState() => _MapsUrlDialogState();
}

class _MapsUrlDialogState extends State<_MapsUrlDialog> {
  bool _invalid = false;
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.importListDialogTitle),
      content: TextField(
        controller: widget.controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.importListDialogHint,
          errorText: _invalid ? l10n.importListDialogInvalidLink : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _checking ? null : _submit,
          child: Text(l10n.importListDialogImport),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _checking = true;
      _invalid = false;
    });
    final result = await widget.ref.read(mapsLinkServiceProvider).expand(text);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _checking = false;
        _invalid = true;
      });
      return;
    }
    Navigator.of(context).pop(result);
  }
}
```

- [ ] **Step 3: Write the failing widget tests for `places_screen.dart`**

Edit `test/widget/places/places_screen_test.dart` — add these imports near the top (alongside the existing ones):

```dart
import 'package:http/testing.dart';
import 'package:tripper/core/sharing/maps_link.dart';
import 'package:tripper/core/sharing/maps_list_scraper.dart';
import 'package:tripper/features/places/presentation/add_place_screen.dart';
import 'package:tripper/features/places/presentation/maps_list_import_screen.dart';
```

Add a `_FakeMapsListScraper` class near the top-level helpers already in the file:

```dart
class _FakeMapsListScraper implements MapsListScraper {
  @override
  Future<ScrapedMapsList?> scrape(String listUrl) async =>
      const ScrapedMapsList(title: 'Japan', placeNames: ['Sensō-ji']);
}
```

Add `mapsLinkServiceProvider` and `mapsListScraperProvider` overrides to the `_app()` helper's `overrides` list (a client that fails any request proves the "full URL, no network" paths stay network-free):

```dart
        mapsLinkServiceProvider.overrideWithValue(
          MapsLinkService(
            MockClient((request) async =>
                throw Exception('unexpected request to ${request.url}')),
          ),
        ),
        mapsListScraperProvider.overrideWithValue(_FakeMapsListScraper()),
```

Add new test cases at the end of `main()`:

```dart
  testWidgets('add menu: "Add place" opens AddPlaceScreen', (tester) async {
    await tester.pumpWidget(_app([]));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add place'));
    await tester.pumpAndSettle();
    expect(find.byType(AddPlaceScreen), findsOneWidget);
  });

  testWidgets(
      'add menu: pasting a single-place link opens AddPlaceScreen prefilled',
      (tester) async {
    await tester.pumpWidget(_app([]));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import Google Maps list…'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://www.google.com/maps/place/Colosseum/@41.8902,12.4922,17z',
    );
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.byType(AddPlaceScreen), findsOneWidget);
  });

  testWidgets('add menu: pasting a list link opens MapsListImportScreen',
      (tester) async {
    await tester.pumpWidget(_app([]));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import Google Maps list…'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2!2sX!3e3',
    );
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.byType(MapsListImportScreen), findsOneWidget);
  });

  testWidgets('add menu: pasting garbage shows an inline error, no navigation',
      (tester) async {
    await tester.pumpWidget(_app([]));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import Google Maps list…'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not a link');
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text("That doesn't look like a Google Maps link"),
        findsOneWidget);
    expect(find.byType(AddPlaceScreen), findsNothing);
    expect(find.byType(MapsListImportScreen), findsNothing);
  });
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `flutter test test/widget/places/places_screen_test.dart`
Expected: FAIL — the "+" button still opens `AddPlaceScreen` directly (no menu), so `find.text('Add place')` etc. don't exist yet.

- [ ] **Step 5: Implement — modify `lib/features/places/presentation/places_screen.dart`**

Add these imports near the top of the file (alongside the existing `add_place_screen` import):

```dart
import '../../../core/sharing/maps_share_routing.dart';
import 'import_maps_list_dialog.dart';
```

Replace the single `IconButton` (the "+" action) with a `PopupMenuButton`:

```dart
          PopupMenuButton<_AddMenuAction>(
            icon: Icon(Icons.add, color: colors.accent),
            tooltip: l10n.placesAddButtonTooltip,
            onSelected: (action) => _onAddMenuAction(context, ref, action, l10n),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AddMenuAction.addPlace,
                child: Text(l10n.placesMenuAddPlace),
              ),
              PopupMenuItem(
                value: _AddMenuAction.importList,
                child: Text(l10n.placesMenuImportList),
              ),
            ],
          ),
```

Add the enum and handler as top-level (file-private) declarations, e.g. just above the `_PlacesScreenBody` class:

```dart
enum _AddMenuAction { addPlace, importList }

Future<void> _onAddMenuAction(
  BuildContext context,
  WidgetRef ref,
  _AddMenuAction action,
  AppLocalizations l10n,
) async {
  switch (action) {
    case _AddMenuAction.addPlace:
      await AddPlaceScreen.open(context);
    case _AddMenuAction.importList:
      final result = await promptMapsListUrl(context, ref);
      if (result == null || !context.mounted) return;
      await openMapsShareResult(context, ref, result);
  }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/widget/places/places_screen_test.dart`
Expected: PASS, all tests green (existing tests in this file still pass too — the map/nearby/filter buttons and empty-state CTA are unchanged).

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/core/sharing/maps_share_routing.dart lib/features/places/presentation/import_maps_list_dialog.dart lib/features/places/presentation/places_screen.dart test/widget/places/places_screen_test.dart`
Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
git add lib/core/sharing/maps_share_routing.dart \
  lib/features/places/presentation/import_maps_list_dialog.dart \
  lib/features/places/presentation/places_screen.dart \
  test/widget/places/places_screen_test.dart
git commit -m "feat(places): add manual 'paste a Google Maps list link' entry point

The Places tab's + button becomes a menu (Add place / Import Google
Maps list...). Both the share-intent listener and this new paste
dialog route through openMapsShareResult, so the place-vs-list
decision lives in exactly one place."
```

---

## Task 6: Wire the share-intent listener

**Files:**
- Modify: `lib/core/widgets/app_shell.dart`
- Test: `test/widget/core/app_shell_test.dart`

**Interfaces:**
- Consumes: `openMapsShareResult` (Task 5); `mapsLinkServiceProvider` (Task 1); `mapsListScraperProvider` (Task 3).

- [ ] **Step 1: Write the failing test**

Create `test/widget/core/app_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:tripper/core/sharing/maps_link.dart';
import 'package:tripper/core/sharing/maps_list_scraper.dart';
import 'package:tripper/core/sharing/share_intent_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/app_shell.dart';
import 'package:tripper/features/places/presentation/maps_list_import_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

class _FakeMapsListScraper implements MapsListScraper {
  @override
  Future<ScrapedMapsList?> scrape(String listUrl) async =>
      const ScrapedMapsList(title: 'Japan', placeNames: ['Sensō-ji']);
}

GoRouter _router() => GoRouter(
      initialLocation: '/trips',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trips',
                  builder: (context, state) =>
                      const Scaffold(body: Text('trips-tab')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/vault',
                  builder: (context, state) =>
                      const Scaffold(body: Text('vault-tab')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/places',
                  builder: (context, state) =>
                      const Scaffold(body: Text('places-tab')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

Widget _app(Stream<IncomingShare> shares) => ProviderScope(
      overrides: [
        incomingSharesProvider.overrideWith((ref) => shares),
        // A client that throws on any request proves these tests' shares
        // (full, non-short URLs) never touch the network — see Task 1.
        mapsLinkServiceProvider.overrideWithValue(
          MapsLinkService(
            MockClient((request) async =>
                throw Exception('unexpected request to ${request.url}')),
          ),
        ),
        mapsListScraperProvider.overrideWithValue(_FakeMapsListScraper()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  // A single-place share's routing (openMapsShareResult -> AddPlaceScreen)
  // is exercised by maps_share_routing's own call sites in
  // places_screen_test.dart. It's not repeated here: app_shell.dart's
  // production AddPlaceScreen.open() call doesn't set renderMap: false,
  // so a real GoogleMap platform view would try to mount in this test —
  // exactly what AddPlaceScreen's own widget test avoids by using
  // renderMap: false (see add_place_screen.dart's doc comment). This test
  // file sticks to the genuinely new behavior instead.
  testWidgets('a list share opens MapsListImportScreen on the Places tab',
      (tester) async {
    await tester.pumpWidget(
      _app(
        Stream.value(
          const IncomingShare(
            texts: [
              'https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2!2sX!3e3',
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('places-tab'), findsOneWidget);
    expect(find.byType(MapsListImportScreen), findsOneWidget);
  });

  testWidgets('a file share still opens the vault sheet on the Vault tab '
      '(regression — untouched by this change)', (tester) async {
    await tester.pumpWidget(
      _app(
        Stream.value(
          const IncomingShare(
            files: [IncomingSharedFile('/tmp/ticket.pdf')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('vault-tab'), findsOneWidget);
  });

  testWidgets('non-maps text is ignored — stays on the trips tab',
      (tester) async {
    await tester.pumpWidget(
      _app(Stream.value(const IncomingShare(texts: ['just some text']))),
    );
    await tester.pumpAndSettle();

    expect(find.text('trips-tab'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/core/app_shell_test.dart`
Expected: FAIL — `app_shell.dart` still calls `AddPlaceScreen.open` directly for every text share, so a list share currently ends up on the Places tab without a `MapsListImportScreen` pushed (it'll try to treat the list URL as a place instead).

- [ ] **Step 3: Implement — modify `lib/core/widgets/app_shell.dart`**

Replace the two now-unneeded imports:

```dart
import '../../features/places/data/geocoding_service.dart';
import '../../features/places/presentation/add_place_screen.dart';
```

with:

```dart
import '../sharing/maps_share_routing.dart';
```

Replace the `ref.listen` block's text-share branch:

```dart
      // Text share: a Google Maps link becomes a place, or — for a shared
      // list — opens the bulk-import review screen (SPEC §3.1,
      // docs/superpowers/specs/2026-08-19-google-maps-list-share-design.md).
      final result =
          await ref.read(mapsLinkServiceProvider).expand(share.texts.first);
      if (result == null) return;
      if (!context.mounted) return;
      navigationShell.goBranch(2);
      await openMapsShareResult(context, ref, result);
    });
```

(This replaces everything from the old `final link = await ref.read(mapsLinkServiceProvider).expand(...)` line through the old `await AddPlaceScreen.open(...)` call — the `showDocumentFormSheet` file-share branch above it is unchanged.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget/core/app_shell_test.dart`
Expected: PASS, all three tests green.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS — no regressions in any other test file (in particular `test/widget/vault/*`, which exercises the unchanged file-share branch).

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 7: Format**

Run: `dart format lib test`
Expected: formats cleanly (0 or reported-and-fixed changes).

- [ ] **Step 8: Commit**

```bash
git add lib/core/widgets/app_shell.dart test/widget/core/app_shell_test.dart
git commit -m "feat(sharing): route Google Maps list shares to MapsListImportScreen

The share-intent listener now switches on the sealed MapsShareResult
via openMapsShareResult instead of always assuming a single place --
completes the Google Maps list share feature end to end."
```

- [ ] **Step 9: Full verification**

Run: `./scripts/verify.ps1`
Expected: `All checks passed.` — this runs `pub get`, `gen-l10n`, `dart format`, `flutter analyze`, and `flutter test` in sequence, per CLAUDE.md's Verification section. Report the actual output; do not report this plan as complete without having run it.

---

## Self-Review Notes

- **Spec coverage:** §1 Detection → Task 1. §2 Scraping → Task 3. §3 Geocoding (incl. the dedupe optimization from the follow-up discussion) → Task 4. §4 Import UI → Task 4. §5 Manual entry point → Task 5. §6 Wiring → Task 6. Error handling (scrape failure/empty, per-item geocode failure, cancel-writes-nothing, offline) → covered by Task 4's tests. l10n (implied by CLAUDE.md rule 3, not a spec section) → Task 2. Every spec section has a task.
- **Deliberate deviation from the spec's literal Testing wording:** the spec says app_shell's `MapsPlaceShare` routing gets "regression coverage." Task 6's test file instead documents (in a comment) why that specific path isn't re-exercised there: `AddPlaceScreen.open()` as called from `app_shell.dart` doesn't pass `renderMap: false`, and `add_place_screen_test.dart` already establishes that rendering the real `GoogleMap` platform view in a widget test is the reason that parameter exists. Forcing it through `app_shell_test.dart` would risk a flaky/crashing test for coverage that's already implied by Task 1 (the parsing logic) plus the unchanged `AddPlaceScreen.open` call site.
- **Placeholder scan:** no TBD/TODO markers; the one open-ended item (Task 3 Step 8, verifying the WebView scraper's CSS selectors against a real device) is flagged explicitly as manual/non-automatable, matching the spec's own Testing section rather than glossing over it.
- **Type consistency:** `MapsShareResult`/`MapsPlaceShare`/`MapsListShare` (Task 1) match their usage in `maps_share_routing.dart` (Task 5) and `app_shell.dart` (Task 6). `MapsListScraper`/`ScrapedMapsList` (Task 3) match their usage in `MapsListImportScreen` (Task 4) and both test files that fake them (Tasks 4, 5, 6). `MapsListImportScreen.open(context, {required url, nameGuess})` (Task 4) matches its call in `maps_share_routing.dart` (Task 5).
