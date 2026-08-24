import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/files/file_extensions.dart';

void main() {
  group('extensionForMimeType', () {
    test('maps the types Tripper accepts', () {
      expect(extensionForMimeType('application/pdf'), '.pdf');
      expect(extensionForMimeType('image/jpeg'), '.jpg');
      expect(extensionForMimeType('image/png'), '.png');
      expect(extensionForMimeType('image/webp'), '.webp');
      expect(extensionForMimeType('text/html'), '.html');
    });

    test('ignores case and any parameters the browser appends', () {
      expect(extensionForMimeType('IMAGE/PNG'), '.png');
      expect(extensionForMimeType('text/html; charset=utf-8'), '.html');
      expect(extensionForMimeType('  application/pdf  '), '.pdf');
    });

    test('returns null when the type says nothing useful', () {
      // The fallback a browser uses when it can't identify the file — it
      // must not become a bogus extension on the stored key.
      expect(extensionForMimeType('application/octet-stream'), isNull);
      expect(extensionForMimeType('video/mp4'), isNull);
      expect(extensionForMimeType(''), isNull);
      expect(extensionForMimeType(null), isNull);
    });
  });

  group('mimeTypeForExtension', () {
    test('round-trips the accepted types', () {
      for (final extension in ['.pdf', '.jpg', '.png', '.webp', '.html']) {
        expect(
          extensionForMimeType(mimeTypeForExtension(extension)),
          extension,
        );
      }
    });

    test('is case-insensitive', () {
      expect(mimeTypeForExtension('.PDF'), 'application/pdf');
    });

    test('falls back to octet-stream for anything unmapped', () {
      expect(mimeTypeForExtension('.xyz'), 'application/octet-stream');
      expect(mimeTypeForExtension(''), 'application/octet-stream');
    });
  });
}
