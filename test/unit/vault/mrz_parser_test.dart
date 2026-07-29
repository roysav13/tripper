import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/domain/mrz_parser.dart';

/// ICAO 9303 specimen passport MRZ (the standard "ERIKSSON ANNA MARIA"
/// example from the spec itself — fixed fixture, not a real document).
final _line1 = 'P<UTOERIKSSON<<ANNA<MARIA'.padRight(44, '<');
const _line2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

void main() {
  group('parseMrz', () {
    test('parses the ICAO specimen', () {
      final result = parseMrz('$_line1\n$_line2');
      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C3');
      expect(result.surname, 'ERIKSSON');
      expect(result.givenNames, ['ANNA', 'MARIA']);
      expect(result.expiryDate, DateTime(2012, 4, 15));
      expect(result.issuingCountry, 'UTO');
      expect(result.fullName, 'Anna Maria Eriksson');
    });

    test('tolerates OCR-inserted spaces inside the MRZ lines', () {
      final spaced = '${_line1.substring(0, 10)} ${_line1.substring(10)}\n'
          '${_line2.substring(0, 20)} ${_line2.substring(20)}';
      expect(parseMrz(spaced)?.documentNumber, 'L898902C3');
    });

    test('finds the MRZ embedded among other page text', () {
      final page = 'PASSPORT\nUtopia\nERIKSSON, ANNA MARIA\n'
          '$_line1\n$_line2\nsome footer text';
      expect(parseMrz(page), isNotNull);
    });

    test(
        'a corrupted expiry check digit drops the expiry but keeps the '
        'validated document number', () {
      // Flip the expiry check digit (position 27) from 9 to 8.
      final corrupted = _line2.replaceRange(27, 28, '8');
      final result = parseMrz('$_line1\n$corrupted');
      expect(result, isNotNull);
      expect(result!.expiryDate, isNull);
      expect(result.documentNumber, 'L898902C3');
    });

    test(
        'a corrupted document-number check digit drops the number but '
        'keeps the validated expiry', () {
      final corrupted = _line2.replaceRange(9, 10, '5');
      final result = parseMrz('$_line1\n$corrupted');
      expect(result, isNotNull);
      expect(result!.documentNumber, isNull);
      expect(result.expiryDate, DateTime(2012, 4, 15));
    });

    test('garbage text yields null, never throws', () {
      expect(parseMrz(''), isNull);
      expect(parseMrz('just a receipt\nfrom a coffee shop'), isNull);
      expect(parseMrz('P<but far too short\nalso short'), isNull);
    });

    test('a second line with non-MRZ characters is rejected', () {
      final fakeLine2 = 'this line is definitely not an mrz line but is '
          'long enough to pass the length check';
      expect(parseMrz('$_line1\n$fakeLine2'), isNull);
    });

    test(
        'tolerates truncated trailing filler on line 1 (OCR eats the '
        'chevron run)', () {
      // Only 'P<UTOERIKSSON<<ANNA<MARIA' — no trailing <<<< at all.
      const truncated = 'P<UTOERIKSSON<<ANNA<MARIA';
      final result = parseMrz('$truncated\n$_line2');
      expect(result, isNotNull);
      expect(result!.surname, 'ERIKSSON');
      expect(result.documentNumber, 'L898902C3');
    });

    test('tolerates line 2 truncated after the expiry check digit', () {
      // Positions 0-27 intact, personal-number tail lost.
      final truncated = _line2.substring(0, 28);
      final result = parseMrz('$_line1\n$truncated');
      expect(result, isNotNull);
      expect(result!.expiryDate, DateTime(2012, 4, 15));
    });

    test(
        'heals line 2 split across two OCR lines (real ML-Kit behavior — '
        'a passport photo produced 47 tiny lines on-device)', () {
      final frag1 = _line2.substring(0, 15);
      final frag2 = _line2.substring(15);
      final result = parseMrz('$_line1\n$frag1\n$frag2');
      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C3');
      expect(result.expiryDate, DateTime(2012, 4, 15));
    });

    test('heals line 2 split across three OCR lines', () {
      final page = 'REPUBLIC OF UTOPIA\n$_line1\n'
          '${_line2.substring(0, 10)}\n'
          '${_line2.substring(10, 30)}\n'
          '${_line2.substring(30)}\n'
          'some footer';
      final result = parseMrz(page);
      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C3');
    });

    test(
        'MRZ lines separated by other recognized text still parse — '
        'line 2 is found independently, no adjacency assumption', () {
      final page = '$_line1\nUTOPIA NATIONAL\nPASSPORT\n$_line2';
      final result = parseMrz(page);
      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C3');
      expect(result.surname, 'ERIKSSON');
    });

    test('tolerates both lines merged into one OCR line', () {
      final merged = '$_line1$_line2';
      final result = parseMrz(merged);
      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C3');
      expect(result.expiryDate, DateTime(2012, 4, 15));
    });

    test('maps guillemet misreads back to chevrons', () {
      // OCR read the << separators as « — a common ML-Kit misread.
      final guillemets = _line1.replaceAll('<<', '«');
      expect(parseMrz('$guillemets\n$_line2')?.surname, 'ERIKSSON');
    });

    test('expiry year windowing pivots at 80 (79 -> 2079, 85 -> 1985)', () {
      String withExpiry(String yymmdd, String check) =>
          _line2.replaceRange(21, 28, '$yymmdd$check');
      expect(
        parseMrz('$_line1\n${withExpiry('790101', '4')}')!.expiryDate,
        DateTime(2079, 1, 1),
      );
      expect(
        parseMrz('$_line1\n${withExpiry('850101', '9')}')!.expiryDate,
        DateTime(1985, 1, 1),
      );
    });
  });

  group('computeMrzPrefill (never-clobber rules)', () {
    final mrz = parseMrz('$_line1\n$_line2')!;

    test('fills everything on an untouched form', () {
      final prefill = computeMrzPrefill(
        mrz: mrz,
        currentCategory: DocumentCategory.other,
        currentTitle: '',
        autoTitleFromFile: 'passport_scan',
        currentExpiry: null,
        currentNumber: '',
      );
      expect(prefill.category, DocumentCategory.passportId);
      expect(prefill.title, 'Anna Maria Eriksson');
      expect(prefill.expiry, DateTime(2012, 4, 15));
      expect(prefill.number, 'L898902C3');
    });

    test('replaces a filename auto-fill title but never a typed one', () {
      final autoFilled = computeMrzPrefill(
        mrz: mrz,
        currentCategory: DocumentCategory.other,
        currentTitle: 'passport_scan',
        autoTitleFromFile: 'passport_scan',
        currentExpiry: null,
        currentNumber: '',
      );
      expect(autoFilled.title, 'Anna Maria Eriksson');

      final typed = computeMrzPrefill(
        mrz: mrz,
        currentCategory: DocumentCategory.other,
        currentTitle: 'My old passport',
        autoTitleFromFile: 'passport_scan',
        currentExpiry: null,
        currentNumber: '',
      );
      expect(typed.title, isNull);
    });

    test(
        'leaves a user-chosen category alone and withholds the number '
        'for non-passport categories', () {
      final prefill = computeMrzPrefill(
        mrz: mrz,
        currentCategory: DocumentCategory.visa,
        currentTitle: '',
        autoTitleFromFile: 'scan',
        currentExpiry: null,
        currentNumber: '',
      );
      expect(prefill.category, isNull);
      expect(prefill.number, isNull);
      // Expiry is category-agnostic — still offered.
      expect(prefill.expiry, DateTime(2012, 4, 15));
    });

    test('keeps an already-set expiry and an already-typed number', () {
      final prefill = computeMrzPrefill(
        mrz: mrz,
        currentCategory: DocumentCategory.passportId,
        currentTitle: 'Passport',
        autoTitleFromFile: 'scan',
        currentExpiry: DateTime(2030, 1, 1),
        currentNumber: 'X123',
      );
      expect(prefill.expiry, isNull);
      expect(prefill.number, isNull);
      expect(prefill.isEmpty, isTrue);
    });
  });
}
