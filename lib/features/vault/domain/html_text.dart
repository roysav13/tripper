/// Minimal HTML → plain text for travel-document extraction (M5.4
/// extension, 2026-07-23): airline/hotel confirmations saved or shared
/// as .html files feed the same `parseTravelDoc` pipeline as OCR text.
///
/// Deliberately dependency-free and lossy — this is not an HTML renderer.
/// The one structural property extraction cares about is that values and
/// their labels stay on plausible line boundaries, so block-level tag
/// closers become newlines and everything else becomes spaces.
library;

import 'dart:convert';

final _scriptRe = RegExp(
  r'<script[\s\S]*?</script>',
  caseSensitive: false,
);
final _styleRe = RegExp(
  r'<style[\s\S]*?</style>',
  caseSensitive: false,
);
final _commentRe = RegExp(r'<!--[\s\S]*?-->');
final _blockBreakRe = RegExp(
  r'<(br|/p|/div|/td|/th|/tr|/li|/h[1-6]|/table|/section|/article)[^>]*>',
  caseSensitive: false,
);
final _anyTagRe = RegExp(r'<[^>]+>');
final _decimalEntityRe = RegExp(r'&#(\d+);');
final _hexEntityRe = RegExp(r'&#x([0-9a-fA-F]+);');

const _namedEntities = {
  '&nbsp;': ' ',
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&#39;': "'",
  '&apos;': "'",
  '&ndash;': '–',
  '&mdash;': '—',
};

/// Decodes raw file bytes to a string without ever throwing. Saved-email
/// HTML is frequently NOT UTF-8 — Outlook/Gmail exports are commonly
/// UTF-16, and older confirmations Windows-1252 — and a strict UTF-8
/// decode throws a FileSystemException on those (real failure, 2026-07-23).
///
/// Order: BOM (definitive) → UTF-16 heuristic (interleaved NULs, which
/// valid UTF-8 text never contains) → UTF-8 allowing malformed sequences
/// → latin-1, which can decode any byte sequence at all and so is a
/// guaranteed terminal fallback. Worst case some accented characters
/// come out wrong; the flight numbers, codes and dates extraction needs
/// are ASCII regardless.
String decodeTextBytes(List<int> bytes) {
  if (bytes.isEmpty) return '';

  // --- BOMs ---
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: false);
  }

  // --- BOM-less UTF-16: ASCII-heavy text shows every other byte NUL ---
  final sample = bytes.length > 512 ? bytes.sublist(0, 512) : bytes;
  var nulAtOdd = 0;
  var nulAtEven = 0;
  for (var i = 0; i < sample.length; i++) {
    if (sample[i] != 0) continue;
    if (i.isOdd) {
      nulAtOdd++;
    } else {
      nulAtEven++;
    }
  }
  final nulShare = (nulAtOdd + nulAtEven) / sample.length;
  if (nulShare > 0.25) {
    return _decodeUtf16(bytes, littleEndian: nulAtOdd >= nulAtEven);
  }

  // --- UTF-8, tolerating bad bytes; latin-1 if even that fails ---
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  try {
    return String.fromCharCodes(units);
  } catch (_) {
    return '';
  }
}

String htmlToPlainText(String html) {
  var text = html
      .replaceAll(_scriptRe, ' ')
      .replaceAll(_styleRe, ' ')
      .replaceAll(_commentRe, ' ')
      .replaceAll(_blockBreakRe, '\n')
      .replaceAll(_anyTagRe, ' ');

  for (final entry in _namedEntities.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  text = text
      .replaceAllMapped(
        _decimalEntityRe,
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAllMapped(
        _hexEntityRe,
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      );

  return text
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .join('\n');
}
