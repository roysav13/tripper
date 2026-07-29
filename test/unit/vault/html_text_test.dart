import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/vault/domain/html_text.dart';

/// Encodes [text] as UTF-16 with the given endianness, optionally with a
/// BOM — mirrors how Outlook/Gmail save confirmation emails.
List<int> _utf16Bytes(
  String text, {
  required bool littleEndian,
  bool bom = true,
}) {
  final bytes = <int>[];
  if (bom) {
    bytes.addAll(littleEndian ? [0xFF, 0xFE] : [0xFE, 0xFF]);
  }
  for (final unit in text.codeUnits) {
    if (littleEndian) {
      bytes
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    } else {
      bytes
        ..add(unit >> 8)
        ..add(unit & 0xFF);
    }
  }
  return bytes;
}

void main() {
  group('decodeTextBytes (real .html files are often not UTF-8)', () {
    const sample = 'Flight LY315\nPNR: X4B7QZ';

    test('plain UTF-8', () {
      expect(decodeTextBytes(utf8.encode(sample)), sample);
    });

    test('UTF-8 with BOM strips the BOM', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(sample)];
      expect(decodeTextBytes(bytes), sample);
    });

    test('UTF-16 LE with BOM', () {
      final bytes = _utf16Bytes(sample, littleEndian: true);
      expect(decodeTextBytes(bytes), sample);
    });

    test('UTF-16 BE with BOM', () {
      final bytes = _utf16Bytes(sample, littleEndian: false);
      expect(decodeTextBytes(bytes), sample);
    });

    test('BOM-less UTF-16 LE is detected by its NUL pattern', () {
      final bytes = _utf16Bytes(sample, littleEndian: true, bom: false);
      expect(decodeTextBytes(bytes), sample);
    });

    test('BOM-less UTF-16 BE is detected by its NUL pattern', () {
      final bytes = _utf16Bytes(sample, littleEndian: false, bom: false);
      expect(decodeTextBytes(bytes), sample);
    });

    test('Windows-1252/latin-1 bytes decode instead of throwing', () {
      // 0xE9 is 'é' in latin-1 and an invalid lone UTF-8 byte.
      final bytes = [...utf8.encode('Caf'), 0xE9, ...utf8.encode(' LY315')];
      final text = decodeTextBytes(bytes);
      expect(text, contains('LY315'));
      expect(text, startsWith('Caf'));
    });

    test('empty and garbage bytes never throw', () {
      expect(decodeTextBytes([]), '');
      expect(
        () => decodeTextBytes([0xC3, 0x28, 0xFF, 0xFE, 0x00]),
        returnsNormally,
      );
    });
  });

  test('strips tags, keeps text', () {
    expect(
      htmlToPlainText('<b>Flight</b> <span class="x">LY315</span>'),
      'Flight LY315',
    );
  });

  test(
      'block closers and <br> become line breaks — label/value rows '
      'stay on separate lines for the keyword-gated parser', () {
    const html = '<table>'
        '<tr><td>Flight</td><td>LY315</td></tr>'
        '<tr><td>Departure</td><td>13 AUG 2026 07:25</td></tr>'
        '</table>';
    final text = htmlToPlainText(html);
    expect(text.split('\n'), [
      'Flight',
      'LY315',
      'Departure',
      '13 AUG 2026 07:25',
    ]);
  });

  test('script, style, and comments are removed entirely', () {
    const html = '<style>.a{color:red}</style>'
        '<script>var pnr = "FAKE01";</script>'
        '<!-- PNR: NOPE99 -->'
        '<p>PNR: X4B7QZ</p>';
    final text = htmlToPlainText(html);
    expect(text, contains('X4B7QZ'));
    expect(text, isNot(contains('FAKE01')));
    expect(text, isNot(contains('NOPE99')));
    expect(text, isNot(contains('color')));
  });

  test('named, decimal, and hex entities decode', () {
    expect(
      htmlToPlainText('A&nbsp;&amp;&nbsp;B &#66; &#x43;'),
      'A & B B C',
    );
  });

  test('whitespace collapses; empty lines drop', () {
    expect(
      htmlToPlainText('<div>  a   b  </div><div>   </div><div>c</div>'),
      'a b\nc',
    );
  });
}
