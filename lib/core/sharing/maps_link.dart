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

  Future<MapsLink?> expand(String text) async {
    final link = parseMapsShare(text);
    if (link == null) return null;
    if (link.hasCoordinates || !isShortMapsLink(link.url)) return link;
    try {
      final resolved = await _resolveRedirects(link.url);
      final expanded = parseMapsShare(resolved);
      if (expanded == null) return link;
      return MapsLink(
        url: link.url,
        name: expanded.name ?? link.name,
        lat: expanded.lat,
        lng: expanded.lng,
      );
    } catch (_) {
      return link; // offline fallback: name + url only, "locate later"
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
        // Already carries coordinates — stop early.
        if (_atCoords.hasMatch(current)) return current;
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
