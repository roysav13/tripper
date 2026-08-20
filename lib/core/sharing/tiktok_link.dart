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
