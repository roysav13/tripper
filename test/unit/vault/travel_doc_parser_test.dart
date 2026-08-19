import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/domain/travel_doc_parser.dart';
import 'package:tripper/l10n/app_localizations.dart';

void main() {
  final now = DateTime(2026, 7, 23);
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('parseTravelDoc', () {
    test('boarding pass: flight number, PNR, departure date+time', () {
      const text = '''
BOARDING PASS
EL AL ISRAEL AIRLINES
Flight LY315
Seat 23A  Gate B7
Departure 13 AUG 2026 07:25
PNR: X4B7QZ
''';
      final fields = parseTravelDoc(text, now: now);
      expect(fields.flightNumber, 'LY315');
      expect(fields.confirmationCode, 'X4B7QZ');
      expect(fields.departureTime, DateTime(2026, 8, 13, 7, 25));
      expect(fields.looksLikeFlight, isTrue);
    });

    test('flight number with a space (LY 315) is joined', () {
      const text = 'FLIGHT LY 315\nGATE 4';
      expect(parseTravelDoc(text, now: now).flightNumber, 'LY315');
    });

    test('hotel confirmation: numeric booking code, no flight signals', () {
      const text = '''
Hotel Paradiso
Booking confirmation
Confirmation number: 84739218
Check-in: 13/08/2026
''';
      final fields = parseTravelDoc(text, now: now);
      expect(fields.confirmationCode, '84739218');
      expect(fields.looksLikeFlight, isFalse);
      // Check-in date is NOT a departure — no DEPART keyword near it.
      expect(fields.departureTime, isNull);
    });

    test('visa: VALID UNTIL date lands in expiryDate', () {
      const text = 'REPUBLIC OF UTOPIA\nVISA\nVALID UNTIL 15 MAR 2027';
      final fields = parseTravelDoc(text, now: now);
      expect(fields.expiryDate, DateTime(2027, 3, 15));
    });

    test(
        'departure without a clock time is not extracted (date-only '
        'would misplace the check-in reminder)', () {
      const text = 'DEPARTURE 13 AUG 2026\nFLIGHT LY315';
      expect(parseTravelDoc(text, now: now).departureTime, isNull);
    });

    test('departure outside the plausibility window is discarded', () {
      const text = 'DEPARTURE 13 AUG 2031 07:25'; // 5 years out
      expect(parseTravelDoc(text, now: now).departureTime, isNull);
    });

    test('date formats: ISO and dd/mm/yyyy both parse', () {
      expect(
        parseTravelDoc('DEPARTURE 2026-08-13 07:25', now: now).departureTime,
        DateTime(2026, 8, 13, 7, 25),
      );
      expect(
        parseTravelDoc('DEPARTURE 13/08/2026 07:25', now: now).departureTime,
        DateTime(2026, 8, 13, 7, 25),
      );
    });

    test(
        'same-line "DEP … ARR …" takes the departure time, never the '
        'arrival (real bug, 2026-07-23)', () {
      const text = 'FLIGHT LY315\nDEP 13 AUG 2026 07:25  ARR 10:45';
      expect(
        parseTravelDoc(text, now: now).departureTime,
        DateTime(2026, 8, 13, 7, 25),
      );
    });

    test(
        'an arrival time on a following line is not mistaken for the '
        'departure', () {
      const text = 'DEPARTURE 13 AUG 2026\nARRIVAL 13 AUG 2026 10:45';
      // Departure has no time of its own; the arrival line must not
      // donate one. No departureTime is correct here.
      expect(parseTravelDoc(text, now: now).departureTime, isNull);
    });

    test('LANDING lines are an arrival boundary too', () {
      const text = 'DEPARTURE 13 AUG 2026\nLANDING TIME 10:45';
      expect(parseTravelDoc(text, now: now).departureTime, isNull);
    });

    test(
        'time left of the DEPART keyword (previous column) is not '
        'taken', () {
      const text = 'ARRIVAL 10:45 DEPARTURE 13 AUG 2026 07:25';
      expect(
        parseTravelDoc(text, now: now).departureTime,
        DateTime(2026, 8, 13, 7, 25),
      );
    });

    test('date on the line above a labeled departure row is used', () {
      const text = '13 AUG 2026\nDEPARTURE 07:25 ARRIVAL 10:45';
      expect(
        parseTravelDoc(text, now: now).departureTime,
        DateTime(2026, 8, 13, 7, 25),
      );
    });

    test('all-letter 6-char PNR is accepted next to a strong keyword', () {
      const text = 'Booking reference\nQWERTY\nFLIGHT LY315';
      expect(parseTravelDoc(text, now: now).confirmationCode, 'QWERTY');
    });

    test(
        'all-letter token near only a weak keyword is NOT taken (too '
        'word-like to trust)', () {
      const text = 'Please confirm your details\nARRIVAL';
      expect(parseTravelDoc(text, now: now).confirmationCode, isNull);
    });

    test(
        'label and value separated by intervening table rows still '
        'pair up (HTML layouts)', () {
      const text = 'Booking reference\n\nYour trip\n\nX4B7QZ';
      expect(parseTravelDoc(text, now: now).confirmationCode, 'X4B7QZ');
    });

    test('12-hour times with AM/PM convert correctly', () {
      expect(
        parseTravelDoc('DEPARTURE 13 AUG 2026 7:25 PM', now: now).departureTime,
        DateTime(2026, 8, 13, 19, 25),
      );
      expect(
        parseTravelDoc('DEPARTURE 13 AUG 2026 12:05 AM', now: now)
            .departureTime,
        DateTime(2026, 8, 13, 0, 5),
      );
    });

    test('US-style month-first dates parse (common in airline emails)', () {
      expect(
        parseTravelDoc('DEPARTURE AUGUST 13, 2026 07:25', now: now)
            .departureTime,
        DateTime(2026, 8, 13, 7, 25),
      );
    });

    test('ordinal day suffixes parse', () {
      expect(
        parseTravelDoc('DEPARTURE 13TH AUGUST 2026 07:25', now: now)
            .departureTime,
        DateTime(2026, 8, 13, 7, 25),
      );
    });

    test('stopwords after a PNR keyword are skipped, not returned', () {
      const text = 'BOOKING REFERENCE NUMBER\nQZ8814';
      expect(parseTravelDoc(text, now: now).confirmationCode, 'QZ8814');
    });

    test('plain prose yields nothing', () {
      const text = 'Shopping list\nMilk\nEggs\nBread';
      final fields = parseTravelDoc(text, now: now);
      expect(fields.isEmpty, isTrue);
      expect(fields.looksLikeFlight, isFalse);
    });

    test(
        'stay confirmation: property name is read off the document '
        'heading, not the confirmation number', () {
      const text = '''
Hotel Paradiso
Booking confirmation
Confirmation number: 84739218
Check-in: 13/08/2026
''';
      expect(parseTravelDoc(text, now: now).stayName, 'Hotel Paradiso');
    });

    test('stay confirmation: explicit "Property:" label', () {
      const text = 'Property: The Grand Villa\nConfirmation: 55219';
      expect(parseTravelDoc(text, now: now).stayName, 'The Grand Villa');
    });

    test('stay confirmation: "reservation at <name>" phrasing', () {
      const text = 'Your reservation at Ocean Resort is confirmed\n'
          'Booking ref: A1B2C3';
      expect(parseTravelDoc(text, now: now).stayName, 'Ocean Resort');
    });

    test('stay name is cut before a trailing address on the same line', () {
      const text = 'Hotel Paradiso, 12 Rue de Rivoli, Paris\n'
          'Booking ref: A1B2C3';
      expect(parseTravelDoc(text, now: now).stayName, 'Hotel Paradiso');
    });

    test(
        'a line that merely mentions "hotel" in boilerplate is not '
        'mistaken for a property name', () {
      const text = 'Hotel booking confirmation\nConfirmation: 55219';
      expect(parseTravelDoc(text, now: now).stayName, isNull);
    });

    test('plain prose yields no stay name either', () {
      const text = 'Shopping list\nMilk\nEggs\nBread';
      expect(parseTravelDoc(text, now: now).stayName, isNull);
    });
  });

  group('computeTravelPrefill', () {
    final flightFields = parseTravelDoc(
      'BOARDING PASS\nFLIGHT LY315\nGATE B7\n'
      'DEPARTURE 13 AUG 2026 07:25\nPNR: X4B7QZ',
      now: now,
    );

    test(
        'flight doc on an untouched form: category, title, details, '
        'departure all fill', () {
      final prefill = computeTravelPrefill(
        fields: flightFields,
        currentCategory: DocumentCategory.other,
        currentTitle: '',
        autoTitleFromFile: 'scan',
        currentExpiry: null,
        currentDeparture: null,
        currentDetailA: '',
        currentDetailB: '',
        l10n: l10n,
      );
      expect(prefill.category, DocumentCategory.flight);
      expect(prefill.title, 'Flight LY315');
      expect(prefill.detailA, 'LY315');
      expect(prefill.detailB, 'X4B7QZ');
      expect(prefill.departureTime, DateTime(2026, 8, 13, 7, 25));
    });

    test('typed details are never clobbered', () {
      final prefill = computeTravelPrefill(
        fields: flightFields,
        currentCategory: DocumentCategory.flight,
        currentTitle: 'My flight home',
        autoTitleFromFile: 'scan',
        currentExpiry: null,
        currentDeparture: DateTime(2026, 8, 13, 9, 0),
        currentDetailA: 'LY316',
        currentDetailB: 'ABCDEF',
        l10n: l10n,
      );
      expect(prefill.title, isNull);
      expect(prefill.detailA, isNull);
      expect(prefill.detailB, isNull);
      expect(prefill.departureTime, isNull);
    });

    test(
        'a user-chosen stay category maps the code to detailA and '
        'withholds flight fields', () {
      final prefill = computeTravelPrefill(
        fields: flightFields,
        currentCategory: DocumentCategory.stay,
        currentTitle: '',
        autoTitleFromFile: 'scan',
        currentExpiry: null,
        currentDeparture: null,
        currentDetailA: '',
        currentDetailB: '',
        l10n: l10n,
      );
      expect(prefill.category, isNull); // user's choice stands
      expect(prefill.detailA, 'X4B7QZ'); // bookingRef slot
      expect(prefill.departureTime, isNull); // flight-only field
      expect(prefill.title, isNull);
    });

    test(
        'stay doc on an untouched form: title fills from the property '
        'name, not the confirmation number', () {
      final stayFields = parseTravelDoc(
        'Hotel Paradiso\nBooking confirmation\n'
        'Confirmation number: 84739218',
        now: now,
      );
      final prefill = computeTravelPrefill(
        fields: stayFields,
        currentCategory: DocumentCategory.stay,
        currentTitle: '',
        autoTitleFromFile: 'confirmation_84739218',
        currentExpiry: null,
        currentDeparture: null,
        currentDetailA: '',
        currentDetailB: '',
        l10n: l10n,
      );
      expect(prefill.title, 'Hotel Paradiso');
      expect(prefill.detailA, '84739218');
    });

    test('a typed stay title is never clobbered by the property name', () {
      final stayFields = parseTravelDoc(
        'Hotel Paradiso\nConfirmation number: 84739218',
        now: now,
      );
      final prefill = computeTravelPrefill(
        fields: stayFields,
        currentCategory: DocumentCategory.stay,
        currentTitle: 'Anniversary trip',
        autoTitleFromFile: 'scan',
        currentExpiry: null,
        currentDeparture: null,
        currentDetailA: '',
        currentDetailB: '',
        l10n: l10n,
      );
      expect(prefill.title, isNull);
    });

    test(
        'stay doc with no extractable property name leaves the title '
        'alone rather than falling back to the confirmation number', () {
      final hotelFields = parseTravelDoc(
        'Booking confirmation\nConfirmation number: 84739218',
        now: now,
      );
      final prefill = computeTravelPrefill(
        fields: hotelFields,
        currentCategory: DocumentCategory.stay,
        currentTitle: '',
        autoTitleFromFile: 'confirmation_84739218',
        currentExpiry: null,
        currentDeparture: null,
        currentDetailA: '',
        currentDetailB: '',
        l10n: l10n,
      );
      expect(prefill.title, isNull);
      expect(prefill.detailA, '84739218');
    });

    test('non-flight doc without signals never auto-switches category', () {
      final hotelFields = parseTravelDoc(
        'Booking confirmation\nConfirmation number: 84739218',
        now: now,
      );
      final prefill = computeTravelPrefill(
        fields: hotelFields,
        currentCategory: DocumentCategory.other,
        currentTitle: '',
        autoTitleFromFile: 'scan',
        currentExpiry: null,
        currentDeparture: null,
        currentDetailA: '',
        currentDetailB: '',
        l10n: l10n,
      );
      expect(prefill.category, isNull);
      // Category stays `other`, which has no detail fields — nothing to
      // put the code into, so the prefill is empty rather than wrong.
      expect(prefill.detailA, isNull);
      expect(prefill.isEmpty, isTrue);
    });
  });
}
