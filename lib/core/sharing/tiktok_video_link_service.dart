import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
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
    if (link == null) {
      if (kDebugMode) {
        debugPrint('[tiktok] no TikTok URL found in shared text');
      }
      return null;
    }
    try {
      final pageBody = await _resolveRedirects(link);
      if (pageBody == null) {
        if (kDebugMode) debugPrint('[tiktok] page fetch failed (see above)');
        return null;
      }
      if (kDebugMode) {
        debugPrint('[tiktok] page fetched, ${pageBody.length} chars');
      }
      final videoUrl = extractTikTokVideoUrl(pageBody);
      if (videoUrl == null) {
        if (kDebugMode) {
          final hasRehydration =
              pageBody.contains('__UNIVERSAL_DATA_FOR_REHYDRATION__');
          final looksLikeCaptcha = pageBody.toLowerCase().contains('captcha') ||
              pageBody.toLowerCase().contains('verify you are human') ||
              pageBody.toLowerCase().contains('unusual traffic');
          debugPrint(
            '[tiktok] no video URL extracted — '
            'has rehydration script: $hasRehydration, '
            'looks like a bot-check page: $looksLikeCaptcha',
          );
        }
        return null;
      }
      if (kDebugMode) debugPrint('[tiktok] extracted video URL: $videoUrl');
      return Uri.tryParse(videoUrl);
    } catch (e) {
      if (kDebugMode) debugPrint('[tiktok] resolveVideoUrl threw: $e');
      return null;
    }
  }

  /// Follows redirect chains and fetches the final page body in one request.
  /// TikTok's short links (`vt.tiktok.com`/`vm.tiktok.com`) 302 to the real
  /// page. Returns the response body as a string, or null on any error.
  /// Pattern matches `MapsLinkService._resolveRedirects`: reads the body via
  /// `response.stream.bytesToString()` when the redirect chain ends, avoiding
  /// a redundant second request.
  Future<String?> _resolveRedirects(String url) async {
    var current = url;
    for (var i = 0; i < 6; i++) {
      final request = http.Request('GET', Uri.parse(current))
        ..followRedirects = false
        ..headers['User-Agent'] = _userAgent;
      final response =
          await _client.send(request).timeout(const Duration(seconds: 8));
      final location = response.headers['location'];
      if (kDebugMode) {
        debugPrint(
          '[tiktok] GET $current -> ${response.statusCode}'
          '${location == null ? '' : ' -> $location'}',
        );
      }
      if (location == null) {
        // No redirect — this is the final response
        if (response.statusCode != 200) return null;
        return await response.stream.bytesToString();
      }
      current = Uri.parse(current).resolve(location).toString();
    }
    // Max redirects reached — fetch the final URL one more time
    final request = http.Request('GET', Uri.parse(current))
      ..followRedirects = false
      ..headers['User-Agent'] = _userAgent;
    final response =
        await _client.send(request).timeout(const Duration(seconds: 8));
    if (kDebugMode) {
      debugPrint(
        '[tiktok] GET $current -> ${response.statusCode} (max redirects)',
      );
    }
    if (response.statusCode != 200) return null;
    return await response.stream.bytesToString();
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
    if (videoUrl == null && kDebugMode) {
      debugPrint(
        '[tiktok] rehydration script found and parsed as JSON, but no '
        'playAddr/downloadAddr field anywhere in it — TikTok likely '
        'nested the video data under different keys than expected',
      );
    }
    return videoUrl;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[tiktok] rehydration script found but JSON decode failed: $e');
    }
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
