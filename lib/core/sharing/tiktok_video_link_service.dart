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
