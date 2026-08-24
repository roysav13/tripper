/// Extension ⇄ MIME mapping for the file types Tripper accepts.
///
/// The web needs this in both directions. A browser file picker hands us
/// a `blob:` URL, which carries no filename and therefore no extension,
/// but the Blob behind it does carry the original MIME type — so the
/// extension a stored key should end in is recoverable from that. Going
/// the other way, a Blob we create ourselves has to be told its type or
/// the round trip loses the extension.
library;

const _mimeToExtension = <String, String>{
  'application/pdf': '.pdf',
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/heic': '.heic',
  'image/heif': '.heif',
  'image/gif': '.gif',
  'text/html': '.html',
  'text/plain': '.txt',
};

/// Dotted extension for [mimeType] (`'image/png'` → `'.png'`), or null
/// for anything unrecognised — including the generic
/// `application/octet-stream` a browser falls back to, which tells us
/// nothing.
String? extensionForMimeType(String? mimeType) {
  if (mimeType == null) return null;
  // Strip any `; charset=…` parameter before matching.
  final base = mimeType.split(';').first.trim().toLowerCase();
  return _mimeToExtension[base];
}

/// MIME type for a dotted [extension] (`'.pdf'` → `'application/pdf'`),
/// defaulting to `application/octet-stream`.
String mimeTypeForExtension(String extension) {
  final normalized = extension.toLowerCase();
  for (final entry in _mimeToExtension.entries) {
    if (entry.value == normalized) return entry.key;
  }
  return 'application/octet-stream';
}
