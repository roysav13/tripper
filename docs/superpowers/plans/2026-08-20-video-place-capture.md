# Video Place Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Share a TikTok video into Tripper, pick a frame with on-screen text, OCR it, resolve it to a place (Wikipedia first, Google Places fills only what Wikipedia didn't have), review, and save it through the app's existing place-save path.

**Architecture:** A new share-intent branch detects TikTok links and opens a capture screen that fetches the video (isolated, fragile-by-design extraction service), lets the user scrub/pause/capture a still frame, runs on-device OCR on it, resolves the recognized text into a place candidate (Wikipedia-then-Places), and hands the result to a review screen that opens the existing `AddPlaceScreen` prefilled.

**Tech Stack:** Flutter/Dart, Riverpod, `http` (video fetch), `google_mlkit_text_recognition` (already a dependency — OCR), `video_player` + `video_thumbnail` (new dependencies — scrub UI + frame rasterization).

**Spec:** `docs/superpowers/specs/2026-08-20-video-place-capture-design.md`

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`; one accent (coral) for actions/active states (CLAUDE.md hard rule 1).
- No `DateTime.now()` in domain code — inject via `clockProvider` (hard rule 2).
- Every user-facing string goes through ARB (`lib/l10n/app_en.arb`), English only, RTL-safe layouts (hard rule 3).
- Local data is always the source of truth; every network step is enhancement, never a gate, and degrades visibly (never a hanging spinner/hard error) with a tested offline fallback (hard rule 4).
- Tests land in the same commit as the feature (hard rule 5). Widget tests mock at the repository/service boundary — never a real plugin or network call.
- Follow the codebase's established plugin-wrapping convention: every third-party plugin/network boundary sits behind a small `abstract interface class` seam (`DocumentTextRecognizer`, `PdfPageRasterizer`, `NotificationScheduler` are the existing examples) so callers and tests never touch the real plugin directly.
- Where a concrete implementation only calls a platform plugin with no branching logic of its own (e.g. `PdfxPageRasterizer` today), it is **not** unit tested directly — verified on-device instead, per existing precedent. Its interface's *consumers* are tested against fakes.

---

## Task 1: TikTok share-link detection

**Files:**
- Create: `lib/core/sharing/tiktok_link.dart`
- Test: `test/unit/sharing/tiktok_link_test.dart`

**Interfaces:**
- Produces: `String? parseTikTokShare(String text)` — returns the TikTok URL found in shared text, or `null` if none. Used by Task 10 (share-intent routing) to decide whether to route into the video-capture flow instead of the existing Maps-link flow.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/sharing/tiktok_link_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/sharing/tiktok_link.dart';

void main() {
  group('parseTikTokShare', () {
    test('extracts a full tiktok.com video URL from shared text', () {
      const text = 'Check this out https://www.tiktok.com/@user/video/12345 ';
      expect(
        parseTikTokShare(text),
        'https://www.tiktok.com/@user/video/12345',
      );
    });

    test('extracts a vt.tiktok.com short link', () {
      const text = 'https://vt.tiktok.com/ZS6abcDEF/';
      expect(parseTikTokShare(text), 'https://vt.tiktok.com/ZS6abcDEF/');
    });

    test('extracts a vm.tiktok.com short link', () {
      const text = 'https://vm.tiktok.com/ZM6abcDEF/';
      expect(parseTikTokShare(text), 'https://vm.tiktok.com/ZM6abcDEF/');
    });

    test('non-TikTok URL yields null', () {
      expect(
        parseTikTokShare('https://www.instagram.com/reel/abc123/'),
        isNull,
      );
    });

    test('plain text with no URL yields null', () {
      expect(parseTikTokShare('just some text, no link'), isNull);
    });

    test('garbage input never throws', () {
      expect(parseTikTokShare(''), isNull);
      expect(parseTikTokShare('http://'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/sharing/tiktok_link_test.dart`
Expected: FAIL — `tiktok_link.dart` doesn't exist yet (import error).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/sharing/tiktok_link.dart

final _urlPattern = RegExp(r'https?://\S+');

/// Pure parser (unit-tested): pulls a TikTok URL out of shared text.
/// Mirrors `maps_link.dart`'s `parseMapsShare` — same "find the first URL,
/// check its host" shape. Returns null when the text contains no TikTok
/// link at all.
String? parseTikTokShare(String text) {
  final match = _urlPattern.firstMatch(text);
  if (match == null) return null;
  final url = match.group(0)!;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  final isTikTok = host == 'tiktok.com' || host.endsWith('.tiktok.com');
  return isTikTok ? url : null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/sharing/tiktok_link_test.dart`
Expected: PASS, all 6 cases.

- [ ] **Step 5: Commit**

```bash
git add lib/core/sharing/tiktok_link.dart test/unit/sharing/tiktok_link_test.dart
git commit -m "feat(sharing): detect TikTok links in shared text"
```

---

## Task 2: TikTok video URL extraction service

**Files:**
- Create: `lib/core/sharing/tiktok_video_link_service.dart`
- Test: `test/unit/sharing/tiktok_video_link_service_test.dart`

**Interfaces:**
- Consumes: `parseTikTokShare` (Task 1).
- Produces: `TikTokVideoLinkService.resolveVideoUrl(String sharedText) -> Future<Uri?>` — the one fragile boundary in this feature (spec §5.2 — never throws, `null` on any failure). Consumed by Task 7 (`VideoFrameCaptureScreen`) via `tikTokVideoLinkServiceProvider` (never constructed ad hoc — Task 7's widget tests override this provider so they never touch the real network).
- Produces: `String? extractTikTokVideoUrl(String html)` — pure parser, exported for direct testing.
- Produces: `tikTokVideoLinkServiceProvider` — same shape as the existing `mapsLinkServiceProvider` in `maps_link.dart`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/unit/sharing/tiktok_video_link_service_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/core/sharing/tiktok_video_link_service.dart';

String _pageWithVideo(String playAddr) {
  final json = jsonEncode({
    'default-scope': {
      'webapp.video-detail': {
        'itemInfo': {
          'itemStruct': {
            'video': {'playAddr': playAddr},
          },
        },
      },
    },
  });
  return '<html><body>'
      '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'
      '$json'
      '</script>'
      '</body></html>';
}

void main() {
  group('extractTikTokVideoUrl', () {
    test('finds playAddr nested in the rehydration JSON', () {
      final html = _pageWithVideo('https://v.tiktokcdn.com/abc.mp4');
      expect(
        extractTikTokVideoUrl(html),
        'https://v.tiktokcdn.com/abc.mp4',
      );
    });

    test('unescapes \\u002F-encoded slashes', () {
      const html = '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
          'type="application/json">'
          '{"video":{"playAddr":"https:\\u002F\\u002Fv.tiktokcdn.com\\u002Fabc.mp4"}}'
          '</script>';
      expect(
        extractTikTokVideoUrl(html),
        'https://v.tiktokcdn.com/abc.mp4',
      );
    });

    test('missing script tag yields null', () {
      expect(extractTikTokVideoUrl('<html><body>nothing here</body></html>'),
          isNull);
    });

    test('malformed JSON yields null, never throws', () {
      const html = '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
          'type="application/json">{not json</script>';
      expect(extractTikTokVideoUrl(html), isNull);
    });

    test('JSON with no playAddr/downloadAddr field yields null', () {
      const html = '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
          'type="application/json">{"foo":"bar"}</script>';
      expect(extractTikTokVideoUrl(html), isNull);
    });

    test('falls back to downloadAddr when playAddr is absent', () {
      const html = '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
          'type="application/json">'
          '{"video":{"downloadAddr":"https://v.tiktokcdn.com/dl.mp4"}}'
          '</script>';
      expect(extractTikTokVideoUrl(html), 'https://v.tiktokcdn.com/dl.mp4');
    });
  });

  group('TikTokVideoLinkService.resolveVideoUrl', () {
    test('follows a short-link redirect then extracts the video URL',
        () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.host == 'vt.tiktok.com') {
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://www.tiktok.com/@user/video/12345',
            },
          );
        }
        if (request.url.host == 'www.tiktok.com') {
          return http.Response(_pageWithVideo('https://v.tiktokcdn.com/x.mp4'),
              200);
        }
        return http.Response('', 404);
      });
      final service = TikTokVideoLinkService(client);

      final result =
          await service.resolveVideoUrl('https://vt.tiktok.com/ZS6abcDEF/');

      expect(result, Uri.parse('https://v.tiktokcdn.com/x.mp4'));
    });

    test('non-TikTok text yields null without any network call', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('', 200);
      });
      final service = TikTokVideoLinkService(client);

      expect(await service.resolveVideoUrl('no link here'), isNull);
      expect(called, isFalse);
    });

    test('page fetch failure degrades to null, never throws', () async {
      final client = MockClient((request) async => http.Response('', 500));
      final service = TikTokVideoLinkService(client);

      expect(
        await service.resolveVideoUrl('https://www.tiktok.com/@u/video/1'),
        isNull,
      );
    });

    test('transport failure degrades to null, never throws', () async {
      final client = MockClient((request) async => throw Exception('down'));
      final service = TikTokVideoLinkService(client);

      expect(
        await service.resolveVideoUrl('https://www.tiktok.com/@u/video/1'),
        isNull,
      );
    });

    test('page with no extractable video yields null', () async {
      final client = MockClient(
        (request) async => http.Response('<html></html>', 200),
      );
      final service = TikTokVideoLinkService(client);

      expect(
        await service.resolveVideoUrl('https://www.tiktok.com/@u/video/1'),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/sharing/tiktok_video_link_service_test.dart`
Expected: FAIL — file doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/sharing/tiktok_video_link_service.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'tiktok_link.dart';

/// Resolves a shared TikTok link to a direct, downloadable video URL.
///
/// This is the one deliberately fragile, isolated boundary named in the
/// design spec (§5.2) — it scrapes TikTok's page markup, which is
/// undocumented and will break whenever TikTok changes it. The contract
/// that keeps that risk contained: one method, never throws, `null` on
/// any failure. No other component in this feature knows *why* a
/// resolution failed, only that it did.
class TikTokVideoLinkService {
  TikTokVideoLinkService(this._client);

  final http.Client _client;

  static const _userAgent = 'Mozilla/5.0 (Linux; Android 13) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

  Future<Uri?> resolveVideoUrl(String sharedText) async {
    final link = parseTikTokShare(sharedText);
    if (link == null) return null;
    try {
      final pageUrl = await _resolveRedirects(link);
      final response = await _client.get(
        Uri.parse(pageUrl),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final videoUrl = extractTikTokVideoUrl(response.body);
      return videoUrl == null ? null : Uri.tryParse(videoUrl);
    } catch (_) {
      return null;
    }
  }

  /// Same technique as `MapsLinkService._resolveRedirects` — TikTok's
  /// short links (`vt.tiktok.com`/`vm.tiktok.com`) 302 to the real page.
  Future<String> _resolveRedirects(String url) async {
    var current = url;
    for (var i = 0; i < 6; i++) {
      final request = http.Request('GET', Uri.parse(current))
        ..followRedirects = false
        ..headers['User-Agent'] = _userAgent;
      final response =
          await _client.send(request).timeout(const Duration(seconds: 8));
      final location = response.headers['location'];
      if (location == null) return current;
      current = Uri.parse(current).resolve(location).toString();
    }
    return current;
  }
}

/// Real `http.Client` by default, same pattern as `mapsLinkServiceProvider`
/// — overridden with a fake in Task 7's widget tests so nothing there
/// touches the real network.
final tikTokVideoLinkServiceProvider = Provider<TikTokVideoLinkService>(
  (ref) => TikTokVideoLinkService(http.Client()),
);

/// Pure parser (unit-tested against fixture HTML) — pulls the direct
/// playable video URL out of TikTok's embedded
/// `__UNIVERSAL_DATA_FOR_REHYDRATION__` JSON blob. Searches by field name
/// (`playAddr`/`downloadAddr`) rather than a fixed JSON path, since
/// TikTok has changed the nesting before and will again — returns null on
/// any shape mismatch rather than throwing.
String? extractTikTokVideoUrl(String html) {
  final scriptMatch = RegExp(
    r'<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>',
    dotAll: true,
  ).firstMatch(html);
  if (scriptMatch == null) return null;
  try {
    final decoded = jsonDecode(scriptMatch.group(1)!);
    final videoUrl = _findPlayAddr(decoded);
    return videoUrl?.replaceAll(r'/', '/');
  } catch (_) {
    return null;
  }
}

String? _findPlayAddr(Object? node) {
  if (node is Map<String, dynamic>) {
    for (final key in ['playAddr', 'downloadAddr']) {
      final value = node[key];
      if (value is String && value.startsWith('http')) return value;
    }
    for (final value in node.values) {
      final found = _findPlayAddr(value);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final item in node) {
      final found = _findPlayAddr(item);
      if (found != null) return found;
    }
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/sharing/tiktok_video_link_service_test.dart`
Expected: PASS, all cases.

- [ ] **Step 5: Commit**

```bash
git add lib/core/sharing/tiktok_video_link_service.dart test/unit/sharing/tiktok_video_link_service_test.dart
git commit -m "feat(sharing): resolve TikTok share links to direct video URLs"
```

**Note for whoever verifies on-device (per spec §3, §9):** the exact JSON shape (`_findPlayAddr`'s field names, the script tag id) is a best-effort guess at TikTok's real page structure as of writing. Confirm against a real captured TikTok share link before relying on this in the field, and expect to need to adjust `extractTikTokVideoUrl` — that is the accepted, named risk from the spec, not a sign this task was done wrong.

---

## Task 3: Wikipedia lookup with coordinates

**Files:**
- Modify: `lib/features/places/data/place_summary_service.dart`
- Test: `test/unit/places/place_summary_service_test.dart` (add cases; existing cases must keep passing untouched)

**Interfaces:**
- Produces: `WikipediaLookup` (`{String? summary, double? lat, double? lng}`), `abstract interface class PlaceLocationSummaryFetcher { Future<WikipediaLookup?> lookup({required String name, String city, String country, double? lat, double? lng}); }`, and `parseWikipediaCoordinates(String body) -> ({double lat, double lng})?`. `WikipediaPlaceSummaryFetcher` and `NoopPlaceSummaryFetcher` both implement the new interface alongside the existing `PlaceSummaryFetcher`. Consumed by Task 4 (`PlaceCandidateResolver`).
- **Does not change** `PlaceSummaryFetcher.fetchSummary`'s signature or behavior — this is purely additive. The three existing test fakes (`_FakeSummaryFetcher`, `_FixedSummaryFetcher`, `_FixedFetcher`) that `implements PlaceSummaryFetcher` only are untouched and keep compiling.

- [ ] **Step 1: Write the failing tests**

Add to `test/unit/places/place_summary_service_test.dart` (inside `main()`, alongside the existing groups):

```dart
  group('parseWikipediaCoordinates', () {
    test('reads lat/lon off a page that has them', () {
      const body = '''
{"type": "standard", "coordinates": {"lat": 8.0119, "lon": 98.8378}}
''';
      final result = parseWikipediaCoordinates(body);
      expect(result, isNotNull);
      expect(result!.lat, 8.0119);
      expect(result.lng, 98.8378);
    });

    test('page with no coordinates field yields null', () {
      expect(
        parseWikipediaCoordinates('{"type": "standard", "extract": "x"}'),
        isNull,
      );
    });

    test('garbage input never throws', () {
      expect(parseWikipediaCoordinates('{}'), isNull);
      expect(parseWikipediaCoordinates('not json'), isNull);
    });
  });

  group('WikipediaPlaceSummaryFetcher.lookup', () {
    test('returns both summary and coordinates when the page has both',
        () async {
      final client = MockClient((request) async {
        if (request.url.path == '/w/api.php') {
          return http.Response(
            '{"query": {"search": [{"title": "Railay Beach"}]}}',
            200,
          );
        }
        return http.Response(
          '{"type": "standard", "extract": "A limestone cove.", '
          '"coordinates": {"lat": 8.0119, "lon": 98.8378}}',
          200,
        );
      });
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      final result = await fetcher.lookup(name: 'Railay Beach');

      expect(result, isNotNull);
      expect(result!.summary, 'A limestone cove.');
      expect(result.lat, 8.0119);
      expect(result.lng, 98.8378);
      expect(result.hasCoordinates, isTrue);
    });

    test('summary-only page yields a result with null coordinates',
        () async {
      final client = MockClient((request) async {
        if (request.url.path == '/w/api.php') {
          return http.Response(
            '{"query": {"search": [{"title": "Corner Store"}]}}',
            200,
          );
        }
        return http.Response('{"type": "standard", "extract": "A shop."}', 200);
      });
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      final result = await fetcher.lookup(name: 'Corner Store');

      expect(result!.summary, 'A shop.');
      expect(result.hasCoordinates, isFalse);
    });

    test('no match at all degrades to null', () async {
      final client = MockClient(
        (request) async => http.Response('{"query": {"search": []}}', 200),
      );
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      expect(await fetcher.lookup(name: 'Zzzzznotaplace'), isNull);
    });

    test('transport failure degrades to null, never throws', () async {
      final client = MockClient((request) async => throw Exception('down'));
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      expect(await fetcher.lookup(name: 'Railay Beach'), isNull);
    });

    test('blank name is never even sent to the network', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      expect(await fetcher.lookup(name: '   '), isNull);
      expect(called, isFalse);
    });
  });

  test('NoopPlaceSummaryFetcher.lookup always returns null', () async {
    const fetcher = NoopPlaceSummaryFetcher();
    expect(await fetcher.lookup(name: 'Anywhere'), isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/places/place_summary_service_test.dart`
Expected: FAIL — `parseWikipediaCoordinates`, `WikipediaLookup`, and `.lookup(...)` don't exist yet.

- [ ] **Step 3: Write the implementation**

Modify `lib/features/places/data/place_summary_service.dart`:

```dart
// Add near the top, after the imports:

/// Wikipedia summary + coordinates for one resolved article — richer than
/// [PlaceSummaryFetcher.fetchSummary]'s plain `String?`, used by the video
/// place-capture flow (design spec §5.6), which needs a location hint
/// before falling back to Google Places.
@immutable
class WikipediaLookup {
  const WikipediaLookup({this.summary, this.lat, this.lng});

  final String? summary;
  final double? lat;
  final double? lng;

  bool get hasCoordinates => lat != null && lng != null;
}

/// A second, additive interface — deliberately separate from
/// [PlaceSummaryFetcher] rather than adding a method to it, so every
/// existing implementer/fake of [PlaceSummaryFetcher] (there are several
/// in tests) keeps compiling unchanged.
abstract interface class PlaceLocationSummaryFetcher {
  /// Best-effort — never throws. Null means no article resolved, or the
  /// resolved article had neither a usable summary nor coordinates.
  Future<WikipediaLookup?> lookup({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  });
}
```

Update `NoopPlaceSummaryFetcher`'s class declaration and add the method:

```dart
class NoopPlaceSummaryFetcher
    implements PlaceSummaryFetcher, PlaceLocationSummaryFetcher {
  const NoopPlaceSummaryFetcher();

  @override
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async =>
      null;

  @override
  Future<WikipediaLookup?> lookup({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async =>
      null;
}
```

Update `WikipediaPlaceSummaryFetcher`'s class declaration, refactor
`_fetchSummaryForTitle` to share a body-fetch helper, and add `lookup`:

```dart
class WikipediaPlaceSummaryFetcher
    implements PlaceSummaryFetcher, PlaceLocationSummaryFetcher {
  WikipediaPlaceSummaryFetcher(this._client);

  // ... existing fields/constants/fetchSummary/_resolveTitle/_geosearch/
  // _textSearch unchanged ...

  Future<String?> _fetchSummaryForTitle(String title) async {
    final body = await _fetchPageBody(title);
    return body == null ? null : parseWikipediaSummary(body);
  }

  /// Shared by [_fetchSummaryForTitle] and [lookup] — one GET, both
  /// callers parse whatever fields they need out of the same body.
  Future<String?> _fetchPageBody(String title) async {
    final encodedTitle = Uri.encodeComponent(title.replaceAll(' ', '_'));
    final response = await _client.get(
      Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/$encodedTitle',
      ),
      headers: {'User-Agent': _userAgent},
    ).timeout(const Duration(seconds: 8));
    return response.statusCode == 200 ? response.body : null;
  }

  @override
  Future<WikipediaLookup?> lookup({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async {
    if (name.trim().isEmpty) return null;
    try {
      final title = await _resolveTitle(
        name: name,
        city: city,
        country: country,
        lat: lat,
        lng: lng,
      );
      if (title == null) return null;
      final body = await _fetchPageBody(title);
      if (body == null) return null;
      final summary = parseWikipediaSummary(body);
      final coords = parseWikipediaCoordinates(body);
      if (summary == null && coords == null) return null;
      return WikipediaLookup(
        summary: summary,
        lat: coords?.lat,
        lng: coords?.lng,
      );
    } catch (e) {
      debugPrint('[places] wikipedia lookup failed: $e');
      return null;
    }
  }
}
```

Add the new pure parser near `parseWikipediaSummary`:

```dart
/// Pure parser — unit-tested against fixture JSON, no network. The REST
/// summary endpoint carries a top-level `coordinates` object when the
/// article has one; most articles don't, and that's a normal null, not
/// a failure.
({double lat, double lng})? parseWikipediaCoordinates(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return null;
  final coords = decoded['coordinates'];
  if (coords is! Map<String, dynamic>) return null;
  final lat = (coords['lat'] as num?)?.toDouble();
  final lon = (coords['lon'] as num?)?.toDouble();
  if (lat == null || lon == null) return null;
  return (lat: lat, lng: lon);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/places/place_summary_service_test.dart`
Expected: PASS — every pre-existing test in this file plus all new ones. Also run `flutter test test/widget/places/add_place_screen_test.dart test/widget/places/nearby_place_detail_sheet_test.dart` to confirm the untouched `implements PlaceSummaryFetcher`-only fakes still compile.

- [ ] **Step 5: Commit**

```bash
git add lib/features/places/data/place_summary_service.dart test/unit/places/place_summary_service_test.dart
git commit -m "feat(places): add coordinate-aware Wikipedia lookup alongside summary fetch"
```

---

## Task 4: Place candidate resolver

**Files:**
- Create: `lib/features/places/data/place_candidate_resolver.dart`
- Test: `test/unit/places/place_candidate_resolver_test.dart`

**Interfaces:**
- Consumes: `PlaceLocationSummaryFetcher.lookup` (Task 3), `Geocoder.search`/`.details`/`.reverse` (`lib/features/places/data/geocoding_service.dart`, existing).
- Produces: `ResolvedPlaceCandidate` (`{name, summary, lat, lng, country, city}`, `hasLocation` getter) and `Future<ResolvedPlaceCandidate> resolvePlaceCandidate({required PlaceLocationSummaryFetcher wikipedia, required Geocoder geocoder, required String name})`. Consumed by Task 8 (`PlaceCandidateReviewScreen`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/unit/places/place_candidate_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/place_candidate_resolver.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';

class _FakeWikipedia implements PlaceLocationSummaryFetcher {
  _FakeWikipedia(this.result, {this.fail = false});
  final WikipediaLookup? result;
  final bool fail;

  @override
  Future<WikipediaLookup?> lookup({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async {
    if (fail) throw Exception('down');
    return result;
  }
}

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder({
    this.searchResults = const [],
    this.reverseHit,
    this.detailsHit,
    this.fail = false,
  });
  final List<GeoResult> searchResults;
  final GeoResult? reverseHit;
  final GeoResult? detailsHit;
  final bool fail;
  int reverseCalls = 0;
  int searchCalls = 0;

  @override
  Future<List<GeoResult>> search(String query) async {
    searchCalls++;
    if (fail) throw const GeocodingException();
    return searchResults;
  }

  @override
  Future<GeoResult?> reverse(double lat, double lon) async {
    reverseCalls++;
    if (fail) throw const GeocodingException();
    return reverseHit;
  }

  @override
  Future<GeoResult?> details(String placeId) async {
    if (fail) throw const GeocodingException();
    return detailsHit;
  }
}

void main() {
  group('resolvePlaceCandidate', () {
    test(
        'Wikipedia has coordinates: Places is only used to reverse-geocode '
        'city/country, never a forward search', () async {
      final wikipedia = _FakeWikipedia(
        const WikipediaLookup(
          summary: 'A limestone cove.',
          lat: 8.0119,
          lng: 98.8378,
        ),
      );
      final geocoder = _FakeGeocoder(
        reverseHit: const GeoResult(
          name: 'Railay Beach',
          displayName: 'Railay Beach, Ao Nang, Krabi, Thailand',
          lat: 8.0119,
          lon: 98.8378,
          country: 'Thailand',
          city: 'Ao Nang',
        ),
      );

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Railay Beach',
      );

      expect(result.summary, 'A limestone cove.');
      expect(result.lat, 8.0119);
      expect(result.lng, 98.8378);
      expect(result.country, 'Thailand');
      expect(result.city, 'Ao Nang');
      expect(geocoder.searchCalls, 0);
      expect(geocoder.reverseCalls, 1);
    });

    test(
        'Wikipedia has no coordinates: Places forward-search fills '
        'location, reverse is never called', () async {
      final wikipedia = _FakeWikipedia(
        const WikipediaLookup(summary: 'A jungle lookout.'),
      );
      final geocoder = _FakeGeocoder(
        searchResults: const [
          GeoResult(
            name: 'Railay Viewpoint',
            displayName: 'Railay Viewpoint, Krabi, Thailand',
            lat: 8.02,
            lon: 98.84,
            country: 'Thailand',
            city: 'Krabi',
          ),
        ],
      );

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Railay Viewpoint',
      );

      expect(result.summary, 'A jungle lookout.');
      expect(result.lat, 8.02);
      expect(result.lng, 98.84);
      expect(result.city, 'Krabi');
      expect(geocoder.reverseCalls, 0);
      expect(geocoder.searchCalls, 1);
    });

    test('Wikipedia finds nothing: Places is the sole source', () async {
      final wikipedia = _FakeWikipedia(null);
      final geocoder = _FakeGeocoder(
        searchResults: const [
          GeoResult(
            name: 'Corner Store',
            displayName: 'Corner Store, Somewhere',
            lat: 1,
            lon: 2,
            country: 'Nowhere',
            city: 'Somewhere',
          ),
        ],
      );

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Corner Store',
      );

      expect(result.summary, isNull);
      expect(result.lat, 1);
      expect(result.city, 'Somewhere');
    });

    test('Google autocomplete result needing details resolves them',
        () async {
      final wikipedia = _FakeWikipedia(null);
      final geocoder = _FakeGeocoder(
        searchResults: const [
          GeoResult(
            name: 'Railay',
            displayName: 'Railay, Thailand',
            lat: 0,
            lon: 0,
            placeId: 'abc',
          ),
        ],
        detailsHit: const GeoResult(
          name: 'Railay',
          displayName: 'Railay, Thailand',
          lat: 8.0,
          lon: 98.8,
          country: 'Thailand',
          city: 'Krabi',
        ),
      );

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Railay',
      );

      expect(result.lat, 8.0);
      expect(result.city, 'Krabi');
    });

    test('everything fails: still returns a name-only candidate, never '
        'throws', () async {
      final wikipedia = _FakeWikipedia(null, fail: true);
      final geocoder = _FakeGeocoder(fail: true);

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Somewhere',
      );

      expect(result.name, 'Somewhere');
      expect(result.hasLocation, isFalse);
      expect(result.summary, isNull);
    });

    test('Wikipedia has coordinates but Places reverse-geocode fails: '
        'coordinates and summary survive, city/country stay empty',
        () async {
      final wikipedia = _FakeWikipedia(
        const WikipediaLookup(summary: 'A cove.', lat: 8.0, lng: 98.8),
      );
      final geocoder = _FakeGeocoder(fail: true);

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Railay Beach',
      );

      expect(result.summary, 'A cove.');
      expect(result.lat, 8.0);
      expect(result.country, '');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/places/place_candidate_resolver_test.dart`
Expected: FAIL — file doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/places/data/place_candidate_resolver.dart
import 'package:flutter/foundation.dart';

import 'geocoding_service.dart';
import 'place_summary_service.dart';

/// A place candidate resolved from a name — the output of Wikipedia-then-
/// Places resolution (design spec §5.6). Shown on the review screen before
/// the user decides whether to add it.
@immutable
class ResolvedPlaceCandidate {
  const ResolvedPlaceCandidate({
    required this.name,
    this.summary,
    this.lat,
    this.lng,
    this.country = '',
    this.city = '',
  });

  final String name;
  final String? summary;
  final double? lat;
  final double? lng;
  final String country;
  final String city;

  bool get hasLocation => lat != null && lng != null;
}

/// Wikipedia first; Google Places fills only whatever Wikipedia didn't
/// supply (design spec §4 step 2 / §5.6):
/// - Wikipedia had coordinates → reverse-geocode them for city/country only
/// - Wikipedia had no coordinates → forward-search Places by name
/// - Wikipedia found nothing → Places is the sole source
/// Every branch degrades to whatever was already resolved on failure —
/// never throws, never blocks (CLAUDE.md hard rule 4).
Future<ResolvedPlaceCandidate> resolvePlaceCandidate({
  required PlaceLocationSummaryFetcher wikipedia,
  required Geocoder geocoder,
  required String name,
}) async {
  final wiki = await wikipedia.lookup(name: name);

  if (wiki != null && wiki.hasCoordinates) {
    try {
      final hit = await geocoder.reverse(wiki.lat!, wiki.lng!);
      return ResolvedPlaceCandidate(
        name: name,
        summary: wiki.summary,
        lat: wiki.lat,
        lng: wiki.lng,
        country: hit?.country ?? '',
        city: hit?.city ?? '',
      );
    } catch (_) {
      return ResolvedPlaceCandidate(
        name: name,
        summary: wiki.summary,
        lat: wiki.lat,
        lng: wiki.lng,
      );
    }
  }

  try {
    final results = await geocoder.search(name);
    if (results.isEmpty) {
      return ResolvedPlaceCandidate(name: name, summary: wiki?.summary);
    }
    var hit = results.first;
    if (hit.needsDetails) {
      hit = await geocoder.details(hit.placeId!) ?? hit;
    }
    if (hit.needsDetails) {
      return ResolvedPlaceCandidate(name: name, summary: wiki?.summary);
    }
    return ResolvedPlaceCandidate(
      name: name,
      summary: wiki?.summary,
      lat: hit.lat,
      lng: hit.lon,
      country: hit.country,
      city: hit.city,
    );
  } catch (_) {
    return ResolvedPlaceCandidate(name: name, summary: wiki?.summary);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/places/place_candidate_resolver_test.dart`
Expected: PASS, all 6 cases.

- [ ] **Step 5: Commit**

```bash
git add lib/features/places/data/place_candidate_resolver.dart test/unit/places/place_candidate_resolver_test.dart
git commit -m "feat(places): resolve OCR'd text into a place via Wikipedia-then-Places"
```

---

## Task 5: Video download and frame capture services

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/places/data/video_capture_service.dart`

**Interfaces:**
- Produces: `abstract interface class VideoDownloader { Future<String?> download(Uri videoUrl); }`, `HttpVideoDownloader`, `abstract interface class VideoFrameCapturer { Future<String?> captureFrame(String videoPath, Duration position); }`, `VideoThumbnailFrameCapturer`, plus `videoDownloaderProvider`/`videoFrameCapturerProvider`. Consumed by Task 7 (`VideoFrameCaptureScreen`), which mocks both interfaces in its widget tests.
- **No dedicated unit test for this task** — both real implementations are thin plugin/network calls with no branching logic of their own (same shape as `PdfxPageRasterizer`, which the codebase already treats as on-device-verify-only, not unit tested). Task 7's widget tests cover everything that sits above these interfaces, against fakes.

- [ ] **Step 1: Add the new dependencies**

Edit `pubspec.yaml`, adding two lines to the `dependencies:` block (alphabetically near the other media/plugin deps, after `url_launcher`):

```yaml
  video_player: ^2.9.2
  video_thumbnail: ^0.5.3
```

(Versions unverified against pub.dev — this sandbox has no network access; confirm on `flutter pub get`, matching the existing convention noted throughout `docs/plans/M5-phase2a.md`.)

- [ ] **Step 2: Run `flutter pub get` to confirm resolution**

Run: `flutter pub get`
Expected: dependencies resolve cleanly. If either version doesn't resolve, bump to the latest compatible version pub.dev reports and note the change here.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/places/data/video_capture_service.dart
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Downloads a resolved TikTok video URL to a temp file. Seam for
/// testability, same pattern as `DocumentTextRecognizer`/
/// `PdfPageRasterizer` — nothing outside this file touches `http` for
/// video bytes.
abstract interface class VideoDownloader {
  /// Temp file path, or null on any failure (offline, non-200, timeout).
  /// Caller owns cleanup of the returned file.
  Future<String?> download(Uri videoUrl);
}

class HttpVideoDownloader implements VideoDownloader {
  HttpVideoDownloader(this._client);

  final http.Client _client;

  @override
  Future<String?> download(Uri videoUrl) async {
    try {
      final response =
          await _client.get(videoUrl).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final tempDir = await getTemporaryDirectory();
      final file = File(
        p.join(
          tempDir.path,
          'tripper_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        ),
      );
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('[video] download failed: $e');
      return null;
    }
  }
}

final videoDownloaderProvider =
    Provider<VideoDownloader>((ref) => HttpVideoDownloader(http.Client()));

/// Rasterizes a single still frame from a local video file at a given
/// position — `video_player` (used for the live scrub preview, Task 7)
/// has no frame-grab API of its own, so "capture" re-derives the frame
/// from the file directly via `video_thumbnail`.
abstract interface class VideoFrameCapturer {
  /// Temp PNG path, or null on any failure. Caller owns cleanup.
  Future<String?> captureFrame(String videoPath, Duration position);
}

class VideoThumbnailFrameCapturer implements VideoFrameCapturer {
  @override
  Future<String?> captureFrame(String videoPath, Duration position) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.PNG,
        timeMs: position.inMilliseconds,
        quality: 100,
      );
      return path;
    } catch (e) {
      if (kDebugMode) debugPrint('[video] frame capture failed: $e');
      return null;
    }
  }
}

final videoFrameCapturerProvider =
    Provider<VideoFrameCapturer>((ref) => VideoThumbnailFrameCapturer());
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/features/places/data/video_capture_service.dart`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/places/data/video_capture_service.dart
git commit -m "feat(places): add video download and frame capture services"
```

---

## Task 6: ARB strings for the capture and review screens

**Files:**
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Produces: the ARB keys listed below, generated into `AppLocalizations` by `flutter gen-l10n` (runs automatically as part of `flutter analyze`/`flutter test` via `generate: true` in `pubspec.yaml`). Consumed by Tasks 7–8.

- [ ] **Step 1: Add the new keys**

Add to `lib/l10n/app_en.arb` (anywhere alongside the other `places*`-prefixed keys, matching existing naming style):

```json
  "videoCaptureTitle": "Capture place from video",
  "videoCaptureFetching": "Fetching video…",
  "videoCaptureFetchFailedTitle": "Couldn't fetch this video",
  "videoCaptureFetchFailedBody": "Try sharing the link again, or add the place manually from the Places tab.",
  "videoCaptureButton": "Capture this frame",
  "videoCaptureRecapture": "Try another frame",
  "videoCaptureRecognizedLabel": "Recognized text",
  "videoCaptureRecognizedHint": "Edit before continuing — check it's right",
  "videoCaptureNoTextFound": "No text found in this frame — you can type it in",
  "videoCaptureLookUp": "Look up",
  "placeCandidateReviewTitle": "Review place",
  "placeCandidateReviewLookingUp": "Looking up…",
  "placeCandidateReviewNoLocation": "No location found — you can add one manually next",
  "placeCandidateReviewConfirm": "Add this place",
  "placeCandidateReviewCancel": "Cancel"
```

- [ ] **Step 2: Verify localizations generate**

Run: `flutter gen-l10n`
Expected: succeeds, `AppLocalizations` gains the new getters (check `.dart_tool/flutter_gen/gen_l10n/app_localizations_en.dart` or just proceed — Task 7/8's code referencing `l10n.videoCaptureTitle` etc. will fail to compile if this step didn't work).

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/app_en.arb
git commit -m "feat(l10n): add strings for video place capture"
```

---

## Task 7: Video frame capture screen

**Files:**
- Create: `lib/features/places/presentation/video_frame_capture_screen.dart`
- Test: `test/widget/places/video_frame_capture_screen_test.dart`

**Interfaces:**
- Consumes: `tikTokVideoLinkServiceProvider` (Task 2), `VideoDownloader`/`VideoFrameCapturer` providers (Task 5), `DocumentTextRecognizer` (existing, `lib/features/vault/data/document_ocr_service.dart` — reused as-is for OCR, per design spec §5.5).
- Produces: `VideoFrameCaptureScreen.open(BuildContext context, {required String sharedText}) -> Future<String?>` — returns the confirmed/edited recognized text, or `null` if the user backed out at any point. Consumed by Task 10 (share-intent routing).

Widget-testability note: `video_player`'s controller cannot initialize inside the Flutter test VM (no real platform channel), so — consistent with the codebase's existing precedent for on-device-only plugin behavior (`pdfx` rendering, real ML-Kit accuracy) — the live scrub/playback UI itself is **not** exercised by widget tests and must be verified on a real device. What *is* unit-testable and must be tested: the fetch/download loading and error states (mocking `TikTokVideoLinkService`... — actually the service itself isn't injected as an interface, see below), the post-capture OCR flow, and the editable-text hand-off. To make that boundary fake-able without wrapping `video_player` itself, the screen takes its already-downloaded video path via a `debugVideoPathOverride` test hook and exposes a `debugCapture()` test hook that simulates tapping "Capture" without a real player — see Step 3.

- [ ] **Step 1: Write the failing tests**

```dart
// test/widget/places/video_frame_capture_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/sharing/tiktok_video_link_service.dart';
import 'package:tripper/features/places/data/video_capture_service.dart';
import 'package:tripper/features/places/presentation/video_frame_capture_screen.dart';
import 'package:tripper/features/vault/data/document_ocr_service.dart';
import 'package:tripper/l10n/app_localizations.dart';

class _FakeRecognizer implements DocumentTextRecognizer {
  _FakeRecognizer(this.result);
  final String result;

  @override
  Future<String> extractText(String imagePath) async => result;
}

class _FakeCapturer implements VideoFrameCapturer {
  _FakeCapturer(this.result);
  final String? result;

  @override
  Future<String?> captureFrame(String videoPath, Duration position) async =>
      result;
}

class _FailingDownloader implements VideoDownloader {
  @override
  Future<String?> download(Uri videoUrl) async => null;
}

class _FakeDownloader implements VideoDownloader {
  @override
  Future<String?> download(Uri videoUrl) async => '/tmp/fake_video.mp4';
}

/// Stands in for the real, network-touching `TikTokVideoLinkService` in
/// every test below — resolves to a fixed URL whenever the shared text
/// looks like a TikTok link at all, so these tests exercise the
/// downloader/capturer/OCR chain without ever reaching the network
/// (CLAUDE.md hard rule 5).
class _FakeTikTokVideoLinkService implements TikTokVideoLinkService {
  _FakeTikTokVideoLinkService({this.resolved = true});
  final bool resolved;

  @override
  Future<Uri?> resolveVideoUrl(String sharedText) async =>
      resolved ? Uri.parse('https://cdn.example.com/video.mp4') : null;
}

Widget _app({
  required VideoDownloader downloader,
  required VideoFrameCapturer capturer,
  required DocumentTextRecognizer recognizer,
  required String sharedText,
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return ProviderScope(
    overrides: [
      tikTokVideoLinkServiceProvider
          .overrideWithValue(_FakeTikTokVideoLinkService()),
      videoDownloaderProvider.overrideWithValue(downloader),
      videoFrameCapturerProvider.overrideWithValue(capturer),
      documentTextRecognizerProvider.overrideWithValue(recognizer),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () =>
              VideoFrameCaptureScreen.open(context, sharedText: sharedText),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('video fetch failure shows the error state, never a hang',
      (tester) async {
    await tester.pumpWidget(_app(
      downloader: _FailingDownloader(),
      capturer: _FakeCapturer(null),
      recognizer: _FakeRecognizer(''),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't fetch this video"), findsOneWidget);
  });

  testWidgets(
      'captured frame with recognized text pre-fills an editable field',
      (tester) async {
    await tester.pumpWidget(_app(
      downloader: _FakeDownloader(),
      capturer: _FakeCapturer('/tmp/frame.png'),
      recognizer: _FakeRecognizer('Railay Beach'),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Debug-only test hook (Step 3) stands in for tapping "Capture" on the
    // real (untestable in-VM) video player.
    final state = tester.state<VideoFrameCaptureScreenState>(
      find.byType(VideoFrameCaptureScreen),
    );
    await state.debugCapture();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Railay Beach'), findsOneWidget);
  });

  testWidgets('failed frame capture keeps the user on the scrub screen',
      (tester) async {
    await tester.pumpWidget(_app(
      downloader: _FakeDownloader(),
      capturer: _FakeCapturer(null),
      recognizer: _FakeRecognizer('should not be called'),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final state = tester.state<VideoFrameCaptureScreenState>(
      find.byType(VideoFrameCaptureScreen),
    );
    await state.debugCapture();
    await tester.pumpAndSettle();

    expect(find.text('Recognized text'), findsNothing);
  });

  testWidgets('no text recognized shows the empty-text hint, field stays '
      'editable', (tester) async {
    await tester.pumpWidget(_app(
      downloader: _FakeDownloader(),
      capturer: _FakeCapturer('/tmp/frame.png'),
      recognizer: _FakeRecognizer(''),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final state = tester.state<VideoFrameCaptureScreenState>(
      find.byType(VideoFrameCaptureScreen),
    );
    await state.debugCapture();
    await tester.pumpAndSettle();

    expect(
      find.text('No text found in this frame — you can type it in'),
      findsOneWidget,
    );
  });

  testWidgets('tapping "Look up" returns the edited text to the caller',
      (tester) async {
    late final Future<String?> result;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tikTokVideoLinkServiceProvider
            .overrideWithValue(_FakeTikTokVideoLinkService()),
        videoDownloaderProvider.overrideWithValue(_FakeDownloader()),
        videoFrameCapturerProvider
            .overrideWithValue(_FakeCapturer('/tmp/frame.png')),
        documentTextRecognizerProvider
            .overrideWithValue(_FakeRecognizer('Railay Beach')),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              result = VideoFrameCaptureScreen.open(
                context,
                sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final state = tester.state<VideoFrameCaptureScreenState>(
      find.byType(VideoFrameCaptureScreen),
    );
    await state.debugCapture();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Railay Beach Viewpoint');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(await result, 'Railay Beach Viewpoint');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/places/video_frame_capture_screen_test.dart`
Expected: FAIL — file doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/places/presentation/video_frame_capture_screen.dart
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/sharing/tiktok_video_link_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../vault/data/document_ocr_service.dart';
import '../data/video_capture_service.dart';

/// Fetch → scrub/pause → capture a frame → OCR it → editable review, per
/// design spec §4-5.4/5.5. Returns the confirmed text, or null if the
/// user backs out anywhere along the way. Pushed the same way
/// `AddPlaceScreen` is (`Navigator...push`, fullscreen dialog) — no named
/// route, matching the existing pattern.
class VideoFrameCaptureScreen extends ConsumerStatefulWidget {
  const VideoFrameCaptureScreen({super.key, required this.sharedText});

  final String sharedText;

  static Future<String?> open(
    BuildContext context, {
    required String sharedText,
  }) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            VideoFrameCaptureScreen(sharedText: sharedText),
      ),
    );
  }

  @override
  ConsumerState<VideoFrameCaptureScreen> createState() =>
      VideoFrameCaptureScreenState();
}

enum _Stage { fetching, fetchFailed, scrubbing, reviewingText }

class VideoFrameCaptureScreenState
    extends ConsumerState<VideoFrameCaptureScreen> {
  _Stage _stage = _Stage.fetching;
  String? _videoPath;
  VideoPlayerController? _controller;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final videoUrl = await ref
        .read(tikTokVideoLinkServiceProvider)
        .resolveVideoUrl(widget.sharedText);
    if (videoUrl == null) {
      if (mounted) setState(() => _stage = _Stage.fetchFailed);
      return;
    }
    final path = await ref.read(videoDownloaderProvider).download(videoUrl);
    if (path == null) {
      if (mounted) setState(() => _stage = _Stage.fetchFailed);
      return;
    }
    if (!mounted) return;
    final controller = VideoPlayerController.file(File(path));
    setState(() {
      _videoPath = path;
      _stage = _Stage.scrubbing;
      _controller = controller;
    });
    // Not awaited into the setState above — initialization can be slow,
    // and the scrub screen already shows a spinner via the
    // `isInitialized` check in build() until this resolves.
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      // Degrades to the same "spinner never resolves past this point"
      // state a real playback failure would show — on-device only, not
      // exercised by widget tests (see this task's testability note).
    });
  }

  Future<void> _capture() async {
    final path = _videoPath;
    if (path == null) return;
    final position = _controller?.value.position ?? Duration.zero;
    final framePath =
        await ref.read(videoFrameCapturerProvider).captureFrame(
              path,
              position,
            );
    if (framePath == null) return; // stays on the scrub screen, re-triable
    final text =
        await ref.read(documentTextRecognizerProvider).extractText(framePath);
    if (!mounted) return;
    _textController.text = text;
    setState(() => _stage = _Stage.reviewingText);
  }

  /// Test-only hook standing in for a real "Capture" tap — `video_player`
  /// cannot initialize inside the widget-test VM, so tests reach this
  /// directly instead of pumping a real player. See Task 7's testability
  /// note.
  @visibleForTesting
  Future<void> debugCapture() => _capture();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.videoCaptureTitle)),
      body: switch (_stage) {
        _Stage.fetching => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.videoCaptureFetching),
              ],
            ),
          ),
        _Stage.fetchFailed => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.videoCaptureFetchFailedTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.videoCaptureFetchFailedBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(MaterialLocalizations.of(context)
                        .cancelButtonLabel),
                  ),
                ],
              ),
            ),
          ),
        _Stage.scrubbing => Column(
            children: [
              Expanded(
                child: _controller != null &&
                        _controller!.value.isInitialized
                    ? VideoPlayer(_controller!)
                    : const Center(child: CircularProgressIndicator()),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton(
                  onPressed: _capture,
                  child: Text(l10n.videoCaptureButton),
                ),
              ),
            ],
          ),
        _Stage.reviewingText => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_textController.text.trim().isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(l10n.videoCaptureNoTextFound),
                  ),
                TextField(
                  controller: _textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.videoCaptureRecognizedLabel,
                    helperText: l10n.videoCaptureRecognizedHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _stage = _Stage.scrubbing),
                        child: Text(l10n.videoCaptureRecapture),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: _textController.text.trim().isEmpty
                            ? null
                            : () => Navigator.of(context)
                                .pop(_textController.text.trim()),
                        child: Text(l10n.videoCaptureLookUp),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/places/video_frame_capture_screen_test.dart`
Expected: PASS, all 5 cases. (`flutter analyze` separately — the real
`VideoPlayerController`/`VideoPlayer` widget usage in the `scrubbing`
branch won't execute inside these tests since they never reach a
`pumpAndSettle` past `_Stage.fetching`/`_Stage.scrubbing` far enough to
lay out a real player before calling `debugCapture()` directly; if
`flutter test` hangs on the scrubbing branch instead of settling, guard
the `VideoPlayer(_controller!)` build with the same
`_controller!.value.isInitialized` check already shown above so an
uninitialized-in-VM controller doesn't throw during layout.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/places/presentation/video_frame_capture_screen.dart test/widget/places/video_frame_capture_screen_test.dart
git commit -m "feat(places): add video frame capture and OCR review screen"
```

**On-device verification required (per spec §8):** the real scrub/pause/capture interaction through `video_player`/`video_thumbnail` against a real downloaded TikTok video is not exercised by any automated test — verify it manually before considering this feature done.

---

## Task 8: Place candidate review screen

**Files:**
- Create: `lib/features/places/presentation/place_candidate_review_screen.dart`
- Modify: `lib/features/places/presentation/place_providers.dart` (add `placeLocationSummaryFetcherProvider`)
- Test: `test/widget/places/place_candidate_review_screen_test.dart`

**Interfaces:**
- Consumes: `resolvePlaceCandidate`/`ResolvedPlaceCandidate` (Task 4), `PlaceLocationSummaryFetcher` (Task 3), `geocoderProvider` (existing).
- Produces: `PlaceCandidateReviewScreen.open(BuildContext context, {required String candidateName}) -> Future<ResolvedPlaceCandidate?>` — returns the candidate the user confirmed, or `null` if they cancelled. Consumed by Task 10. Also produces `placeLocationSummaryFetcherProvider` (`Provider<PlaceLocationSummaryFetcher>`) in `place_providers.dart`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/widget/places/place_candidate_review_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';
import 'package:tripper/features/places/presentation/place_candidate_review_screen.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

class _FakeWikipedia implements PlaceLocationSummaryFetcher {
  _FakeWikipedia(this.result);
  final WikipediaLookup? result;

  @override
  Future<WikipediaLookup?> lookup({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async =>
      result;
}

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder({this.reverseHit, this.searchResults = const []});
  final GeoResult? reverseHit;
  final List<GeoResult> searchResults;

  @override
  Future<List<GeoResult>> search(String query) async => searchResults;
  @override
  Future<GeoResult?> reverse(double lat, double lon) async => reverseHit;
  @override
  Future<GeoResult?> details(String placeId) async => null;
}

Future<ResolvedPlaceCandidate?> _openWith(
  WidgetTester tester, {
  required PlaceLocationSummaryFetcher wikipedia,
  required Geocoder geocoder,
  required String candidateName,
}) async {
  ResolvedPlaceCandidate? result;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      placeLocationSummaryFetcherProvider.overrideWithValue(wikipedia),
      geocoderProvider.overrideWithValue(geocoder),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await PlaceCandidateReviewScreen.open(
              context,
              candidateName: candidateName,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('shows a loading state while resolving', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        placeLocationSummaryFetcherProvider
            .overrideWithValue(_FakeWikipedia(null)),
        geocoderProvider.overrideWithValue(_FakeGeocoder()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => PlaceCandidateReviewScreen.open(
              context,
              candidateName: 'Railay Beach',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(); // one frame — resolution hasn't completed yet

    expect(find.text('Looking up…'), findsOneWidget);
  });

  testWidgets('fully resolved candidate shows name, summary, location',
      (tester) async {
    final result = await _openWith(
      tester,
      wikipedia: _FakeWikipedia(
        const WikipediaLookup(
          summary: 'A limestone cove.',
          lat: 8.0119,
          lng: 98.8378,
        ),
      ),
      geocoder: _FakeGeocoder(
        reverseHit: const GeoResult(
          name: 'Railay Beach',
          displayName: 'Railay Beach, Ao Nang, Krabi, Thailand',
          lat: 8.0119,
          lon: 98.8378,
          country: 'Thailand',
          city: 'Ao Nang',
        ),
      ),
      candidateName: 'Railay Beach',
    );

    expect(find.text('Railay Beach'), findsOneWidget);
    expect(find.text('A limestone cove.'), findsOneWidget);
    expect(find.textContaining('Ao Nang'), findsOneWidget);
    // Not yet confirmed — the button tap in _openWith just opened the
    // screen, this assertion runs against the still-open review UI.
    expect(result, isNull);
  });

  testWidgets('no location resolved shows the explicit empty state',
      (tester) async {
    await _openWith(
      tester,
      wikipedia: _FakeWikipedia(null),
      geocoder: _FakeGeocoder(),
      candidateName: 'Some Obscure Place',
    );

    expect(
      find.text('No location found — you can add one manually next'),
      findsOneWidget,
    );
  });

  testWidgets('confirm returns the resolved candidate', (tester) async {
    ResolvedPlaceCandidate? result;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        placeLocationSummaryFetcherProvider.overrideWithValue(
          _FakeWikipedia(
            const WikipediaLookup(summary: 'A cove.', lat: 8.0, lng: 98.8),
          ),
        ),
        geocoderProvider.overrideWithValue(
          _FakeGeocoder(
            reverseHit: const GeoResult(
              name: 'x',
              displayName: 'x',
              lat: 8.0,
              lon: 98.8,
              country: 'Thailand',
              city: 'Krabi',
            ),
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await PlaceCandidateReviewScreen.open(
                context,
                candidateName: 'Railay Beach',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add this place'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Railay Beach');
    expect(result!.summary, 'A cove.');
  });

  testWidgets('cancel returns null', (tester) async {
    final result = await _openWith(
      tester,
      wikipedia: _FakeWikipedia(null),
      geocoder: _FakeGeocoder(),
      candidateName: 'Railay Beach',
    );
    // Screen is open; now cancel it.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/places/place_candidate_review_screen_test.dart`
Expected: FAIL — file doesn't exist yet, plus `placeLocationSummaryFetcherProvider` doesn't exist yet (added in Step 3).

- [ ] **Step 3: Write the implementation**

Add the missing provider to `lib/features/places/presentation/place_providers.dart`:

```dart
/// Separate instance from [placeSummaryFetcherProvider] (same underlying
/// class, different interface) — deliberately not derived from it via a
/// cast, so overriding one in a test never silently affects the other.
/// See design spec §5.6.
final placeLocationSummaryFetcherProvider =
    Provider<PlaceLocationSummaryFetcher>(
  (ref) => WikipediaPlaceSummaryFetcher(http.Client()),
);
```

(`PlaceLocationSummaryFetcher` and `WikipediaPlaceSummaryFetcher` are
already imported in this file via the existing `place_summary_service.dart`
import.)

```dart
// lib/features/places/presentation/place_candidate_review_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../data/geocoding_service.dart';
import '../data/place_candidate_resolver.dart';
import 'place_providers.dart';

/// Resolves an OCR'd candidate name via Wikipedia-then-Places and shows
/// it for confirmation before anything is saved — this is the "only if I
/// decide to add" decision point from the design spec (§4 step 3).
class PlaceCandidateReviewScreen extends ConsumerStatefulWidget {
  const PlaceCandidateReviewScreen({super.key, required this.candidateName});

  final String candidateName;

  static Future<ResolvedPlaceCandidate?> open(
    BuildContext context, {
    required String candidateName,
  }) {
    return Navigator.of(context, rootNavigator: true)
        .push<ResolvedPlaceCandidate>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            PlaceCandidateReviewScreen(candidateName: candidateName),
      ),
    );
  }

  @override
  ConsumerState<PlaceCandidateReviewScreen> createState() =>
      _PlaceCandidateReviewScreenState();
}

class _PlaceCandidateReviewScreenState
    extends ConsumerState<PlaceCandidateReviewScreen> {
  ResolvedPlaceCandidate? _candidate;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final result = await resolvePlaceCandidate(
      wikipedia: ref.read(placeLocationSummaryFetcherProvider),
      geocoder: ref.read(geocoderProvider),
      name: widget.candidateName,
    );
    if (mounted) setState(() => _candidate = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final candidate = _candidate;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.placeCandidateReviewTitle)),
      body: candidate == null
          ? Center(child: Text(l10n.placeCandidateReviewLookingUp))
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    candidate.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (candidate.summary != null)
                    Text(candidate.summary!)
                  else
                    Text(l10n.videoCaptureNoTextFound),
                  const SizedBox(height: AppSpacing.sm),
                  if (candidate.hasLocation)
                    Text(
                      [candidate.city, candidate.country]
                          .where((s) => s.isNotEmpty)
                          .join(', '),
                    )
                  else
                    Text(l10n.placeCandidateReviewNoLocation),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.placeCandidateReviewCancel),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(candidate),
                          child: Text(l10n.placeCandidateReviewConfirm),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/places/place_candidate_review_screen_test.dart`
Expected: PASS, all 5 cases.

- [ ] **Step 5: Commit**

```bash
git add lib/features/places/presentation/place_candidate_review_screen.dart lib/features/places/presentation/place_providers.dart test/widget/places/place_candidate_review_screen_test.dart
git commit -m "feat(places): add place candidate review screen"
```

---

## Task 9: `AddPlaceScreen` — accept a pre-resolved summary

**Files:**
- Modify: `lib/features/places/presentation/add_place_screen.dart`
- Test: `test/widget/places/add_place_screen_test.dart` (add a case; existing cases must keep passing)

**Interfaces:**
- Modifies: `AddPlaceScreen` constructor and `AddPlaceScreen.open` gain an optional `initialSummary` param. When set, `_save()` stores it directly via `repo.setSummary` instead of firing the existing `fetchAndStorePlaceSummary` — avoids a redundant, possibly-inconsistent second Wikipedia fetch for a value the caller already resolved (design spec §5.7). When unset (every existing caller), behavior is byte-for-byte unchanged.

- [ ] **Step 1: Write the failing test**

Add to `test/widget/places/add_place_screen_test.dart`:

```dart
  testWidgets(
      'a pre-resolved summary is stored directly, without re-fetching',
      (tester) async {
    final repo = FakePlaceRepository([]);
    var fetchCalled = false;
    // Built directly with `initialSummary` rather than through the
    // existing `_app()` helper above — that helper's `home:` doesn't take
    // this new param, and this is the one test in this file that needs it.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geocoderProvider.overrideWithValue(FakeGeocoder([_railay])),
          placeRepositoryProvider.overrideWithValue(repo),
          placeCollectionRepositoryProvider
              .overrideWithValue(FakePlaceCollectionRepository([])),
          tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
          clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
          placeSummaryFetcherProvider.overrideWithValue(
            _CountingSummaryFetcher(() => fetchCalled = true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AddPlaceScreen(
            renderMap: false,
            initialName: 'Railay Beach',
            initialSummary: 'A limestone cove.',
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repo.watchAll().first).single;
    expect(saved.summary, 'A limestone cove.');
    expect(fetchCalled, isFalse);
  });
```

Add the small fake fetcher near the file's other fakes:

```dart
class _CountingSummaryFetcher implements PlaceSummaryFetcher {
  _CountingSummaryFetcher(this.onCalled);
  final VoidCallback onCalled;

  @override
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async {
    onCalled();
    return 'should not be used';
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/places/add_place_screen_test.dart`
Expected: FAIL — `initialSummary` param doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Modify `lib/features/places/presentation/add_place_screen.dart`:

```dart
  // Constructor: add the new param alongside the other `initial*` fields.
  const AddPlaceScreen({
    super.key,
    this.tripId,
    this.initialName,
    this.initialLat,
    this.initialLng,
    this.initialCountry,
    this.initialCity,
    this.initialNotes,
    this.initialSummary,
    this.renderMap = true,
  });

  // ...

  /// Pre-resolved via the video place-capture flow's Wikipedia-then-Places
  /// lookup (design spec §5.6) — when set, `_save()` stores this directly
  /// instead of re-fetching, so what the user reviewed before adding is
  /// exactly what gets saved. Every other caller leaves this null and
  /// behavior is unchanged from before this field existed.
  final String? initialSummary;
```

Update `AddPlaceScreen.open`'s static method the same way (add the
param, pass it through to the constructor):

```dart
  static Future<void> open(
    BuildContext context, {
    String? tripId,
    String? initialName,
    double? initialLat,
    double? initialLng,
    String? initialCountry,
    String? initialCity,
    String? initialNotes,
    String? initialSummary,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => AddPlaceScreen(
          tripId: tripId,
          initialName: initialName,
          initialLat: initialLat,
          initialLng: initialLng,
          initialCountry: initialCountry,
          initialCity: initialCity,
          initialNotes: initialNotes,
          initialSummary: initialSummary,
        ),
      ),
    );
  }
```

Update `_save()` — replace the existing unconditional
`fetchAndStorePlaceSummary` call:

```dart
    // Pre-resolved (video place-capture flow) skips the fetch entirely —
    // storing exactly what the user already reviewed rather than
    // re-querying Wikipedia a second time with the same inputs.
    if (widget.initialSummary != null) {
      unawaited(repo.setSummary(id, summary: widget.initialSummary));
    } else {
      unawaited(
        fetchAndStorePlaceSummary(
          fetcher: summaryFetcher,
          repo: repo,
          placeId: id,
          name: name,
          city: _city,
          country: _country,
          lat: lat,
          lng: lng,
        ),
      );
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/places/add_place_screen_test.dart`
Expected: PASS — the new case plus every pre-existing case in this file.

- [ ] **Step 5: Commit**

```bash
git add lib/features/places/presentation/add_place_screen.dart test/widget/places/add_place_screen_test.dart
git commit -m "feat(places): let AddPlaceScreen accept a pre-resolved summary"
```

---

## Task 10: Wire TikTok share-link routing

**Files:**
- Modify: `lib/core/widgets/app_shell.dart`
- Test: no new automated test — `app_shell.dart` has no existing widget test suite of its own (its logic is a thin `ref.listen` wiring callback over screens already tested individually in Tasks 7–9); this task is verified on-device, matching how the original Maps-link wiring in this same file was verified (see `docs/plans/M3-places.md`).

**Interfaces:**
- Consumes: `parseTikTokShare` (Task 1), `VideoFrameCaptureScreen.open` (Task 7), `PlaceCandidateReviewScreen.open` (Task 8), `AddPlaceScreen.open` (Task 9, extended).

- [ ] **Step 1: Modify the share-intent listener**

In `lib/core/widgets/app_shell.dart`, add the imports:

```dart
import '../sharing/tiktok_link.dart';
import '../../features/places/presentation/place_candidate_review_screen.dart';
import '../../features/places/presentation/video_frame_capture_screen.dart';
```

Change the text-share branch of the `ref.listen(incomingSharesProvider, ...)`
callback from:

```dart
      // Text share: a Google Maps link becomes a place (SPEC §3.1).
      final link =
          await ref.read(mapsLinkServiceProvider).expand(share.texts.first);
```

to:

```dart
      final text = share.texts.first;
      // A TikTok link routes into the video place-capture flow instead of
      // the Maps-link path below (design spec §5.1).
      if (parseTikTokShare(text) != null) {
        navigationShell.goBranch(2);
        final candidateName =
            await VideoFrameCaptureScreen.open(context, sharedText: text);
        if (candidateName == null || !context.mounted) return;
        final candidate = await PlaceCandidateReviewScreen.open(
          context,
          candidateName: candidateName,
        );
        if (candidate == null || !context.mounted) return;
        await AddPlaceScreen.open(
          context,
          initialName: candidate.name,
          initialLat: candidate.lat,
          initialLng: candidate.lng,
          initialCountry: candidate.country,
          initialCity: candidate.city,
          initialSummary: candidate.summary,
        );
        return;
      }
      // Text share: a Google Maps link becomes a place (SPEC §3.1).
      final link =
          await ref.read(mapsLinkServiceProvider).expand(share.texts.first);
```

- [ ] **Step 2: Verify it compiles and existing tests still pass**

Run: `flutter analyze lib/core/widgets/app_shell.dart`
Run: `flutter test` (full suite — this file has no dedicated tests, but
confirm nothing else broke)
Expected: no analyzer errors; full suite green.

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/app_shell.dart
git commit -m "feat(sharing): route shared TikTok links into video place capture"
```

- [ ] **Step 4: On-device verification (required — cannot be automated)**

Per CLAUDE.md's Verification section, this cannot be run in this
sandbox. Before considering the feature done, verify on a real device:
1. Share a real public TikTok video link to Tripper.
2. Confirm the video-fetch step succeeds (or fails cleanly with the
   "Couldn't fetch this video" state — see Task 2's on-device note,
   `extractTikTokVideoUrl` will likely need real-page adjustment).
3. Scrub, pause, and capture a frame with visible on-screen text; confirm
   OCR pre-fills something reasonable.
4. Confirm the review screen shows a sensible Wikipedia summary/location
   (or the explicit "no location found" state) and that "Add this place"
   lands on `AddPlaceScreen` prefilled, and that saving stores the
   summary correctly (check the place's detail card).
5. Confirm a non-TikTok text share (a Google Maps link) still works
   exactly as before — this task's change must not regress it.

---

## Self-Review

**1. Spec coverage:**
- §5.1 share-intent routing → Task 1, Task 10 ✓
- §5.2 `TikTokVideoLinkService` (isolated, never-throws) → Task 2 ✓
- §5.3 video download → Task 5 (`VideoDownloader`) ✓
- §5.4 `VideoFrameCaptureScreen` (scrub, capture, video_player/video_thumbnail) → Task 5 (`VideoFrameCapturer`), Task 7 ✓
- §5.5 OCR reuse, editable/never-auto-applied → Task 7 ✓
- §5.6 `PlaceCandidateResolver`, Wikipedia-then-Places, extended fetcher → Task 3, Task 4 ✓
- §5.7 review card → save path, no redundant re-fetch → Task 8, Task 9 ✓
- §6 no schema changes → confirmed, no Drift table/migration touched anywhere in this plan ✓
- §7 error handling table → fetch-failure state (Task 7), OCR-empty state (Task 7), Wikipedia-silent-fallthrough (Task 4), Places-no-match state (Task 8) — all covered ✓
- §8 testing strategy → each task's own tests match what §8 specifies per component ✓
- §2 scope (TikTok only) → confirmed, no Instagram code anywhere in this plan ✓

**2. Placeholder scan:** no TBD/TODO; every step has concrete code. (One
deliberate exception left visible on purpose: Task 7 Step 3 calls out its
own placeholder line and immediately replaces it with real code in the
same step, so a worker following it never lands on the broken
intermediate version — flagged there so it isn't missed.)

**3. Type consistency check:**
- `WikipediaLookup{summary, lat, lng, hasCoordinates}` (Task 3) used identically in Task 4 (`wiki.summary`/`wiki.lat`/`wiki.lng`/`wiki.hasCoordinates`) and nowhere else — consistent.
- `PlaceLocationSummaryFetcher.lookup(...)` signature (Task 3) matches every call site (Task 4, Task 8's provider) — consistent.
- `ResolvedPlaceCandidate{name, summary, lat, lng, country, city, hasLocation}` (Task 4) matches Task 8's rendering (`candidate.name/summary/hasLocation/city/country`) and Task 10's `AddPlaceScreen.open` call (`candidate.lat/lng/country/city/summary`) — consistent.
- `VideoDownloader.download(Uri) -> Future<String?>` and `VideoFrameCapturer.captureFrame(String, Duration) -> Future<String?>` (Task 5) match Task 7's usage exactly — consistent.
- `AddPlaceScreen`'s new `initialSummary` param (Task 9) matches Task 10's `initialSummary: candidate.summary` call — consistent.
- `VideoFrameCaptureScreen.open(...) -> Future<String?>` (Task 7) matches Task 10's `candidateName = await VideoFrameCaptureScreen.open(...)` — consistent.
- `PlaceCandidateReviewScreen.open(...) -> Future<ResolvedPlaceCandidate?>` (Task 8) matches Task 10's `candidate = await PlaceCandidateReviewScreen.open(...)` — consistent.
