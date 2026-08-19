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
