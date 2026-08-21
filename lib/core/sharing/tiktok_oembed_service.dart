import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable, kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'tiktok_link.dart';

/// A TikTok video's public embed metadata — caption text and a cover-frame
/// thumbnail URL, both from TikTok's official, keyless oEmbed endpoint
/// (`https://www.tiktok.com/oembed`). Unlike the video-playback CDN, this
/// endpoint and its thumbnail images are meant for arbitrary third-party
/// fetching (link unfurls, embeds) and aren't behind Akamai Bot Manager —
/// confirmed on-device after the video-download approach was blocked
/// outright by the same Akamai edge denial across several header attempts.
@immutable
class TikTokOEmbed {
  const TikTokOEmbed({this.caption, this.thumbnailUrl});

  final String? caption;
  final String? thumbnailUrl;
}

/// Widget tests fake at this boundary.
abstract interface class TikTokOEmbedFetcher {
  /// Best-effort — never throws. Null means no TikTok link found, or the
  /// oEmbed request failed for any reason.
  Future<TikTokOEmbed?> fetch(String sharedText);
}

class HttpTikTokOEmbedFetcher implements TikTokOEmbedFetcher {
  HttpTikTokOEmbedFetcher(this._client);

  final http.Client _client;

  @override
  Future<TikTokOEmbed?> fetch(String sharedText) async {
    final link = parseTikTokShare(sharedText);
    if (link == null) return null;
    try {
      final response = await _client
          .get(Uri.https('www.tiktok.com', '/oembed', {'url': link}))
          .timeout(const Duration(seconds: 8));
      if (kDebugMode) {
        debugPrint('[tiktok] oEmbed GET -> ${response.statusCode}');
      }
      if (response.statusCode != 200) return null;
      return parseTikTokOEmbed(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('[tiktok] oEmbed fetch failed: $e');
      return null;
    }
  }
}

final tiktokOEmbedFetcherProvider = Provider<TikTokOEmbedFetcher>(
  (ref) => HttpTikTokOEmbedFetcher(http.Client()),
);

/// Pure parser (unit-tested against fixture JSON, no network). Null when
/// neither a caption nor a thumbnail could be read — nothing useful to
/// build a candidate from either way.
TikTokOEmbed? parseTikTokOEmbed(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final rawCaption = decoded['title']?.toString().trim();
    final rawThumbnail = decoded['thumbnail_url']?.toString().trim();
    final caption = (rawCaption == null || rawCaption.isEmpty) ? null : rawCaption;
    final thumbnailUrl =
        (rawThumbnail == null || rawThumbnail.isEmpty) ? null : rawThumbnail;
    if (caption == null && thumbnailUrl == null) return null;
    return TikTokOEmbed(caption: caption, thumbnailUrl: thumbnailUrl);
  } catch (_) {
    return null;
  }
}
