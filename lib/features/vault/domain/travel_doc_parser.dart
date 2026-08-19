/// Freeform travel-document field extraction (M5.4 extension): flight
/// numbers, booking/confirmation codes, stay/property names, departure
/// date+time, expiry dates — for boarding passes, e-tickets, hotel
/// confirmations, visas.
///
/// Runs on whatever text OCR produced when no passport MRZ was found.
/// Unlike the MRZ there are no check digits here, so everything is
/// keyword-gated heuristics: a value is only extracted when it sits near
/// a word that names it (FLIGHT, PNR, DEPARTURE, VALID UNTIL…), and
/// dates must fall inside a plausibility window around [now]. Expect
/// hit-or-miss on exotic layouts — SPEC's own framing for non-MRZ OCR.
///
/// Input-agnostic on purpose: M5.11's email parsing needs exactly these
/// heuristics over shared email text, and can reuse this parser as-is.
library;

import 'document.dart';
import '../../../l10n/app_localizations.dart';

class TravelDocFields {
  const TravelDocFields({
    this.flightNumber,
    this.confirmationCode,
    this.stayName,
    this.departureTime,
    this.expiryDate,
    this.flightSignals = 0,
  });

  final String? flightNumber;
  final String? confirmationCode;

  /// The property/hotel name, for stay documents — so the saved title can
  /// read "Hotel Paradiso" instead of the booking's confirmation number
  /// (which is what the source file/email is usually named).
  final String? stayName;

  /// Only set when BOTH a date and a clock time were found near a
  /// departure keyword — a date-only "departure" would schedule the
  /// check-in reminder (M5.3) at a meaningless midnight.
  final DateTime? departureTime;
  final DateTime? expiryDate;

  /// How many distinct flight-context words appeared (FLIGHT, BOARDING,
  /// GATE, SEAT…). Used to decide whether this looks like a flight
  /// document at all before auto-picking the category.
  final int flightSignals;

  bool get isEmpty =>
      flightNumber == null &&
      confirmationCode == null &&
      stayName == null &&
      departureTime == null &&
      expiryDate == null;

  bool get looksLikeFlight =>
      flightSignals >= 2 || (flightNumber != null && flightSignals >= 1);
}

const _flightKeywords = {
  'FLIGHT',
  'BOARDING',
  'GATE',
  'SEAT',
  'AIRLINE',
  'AIRWAYS',
  'TERMINAL',
  'DEPARTURE',
};

/// Strong keywords name a booking code unambiguously, so a bare 6-letter
/// token near one (the classic all-letter PNR, e.g. ABCDEF) is trusted.
/// Weak ones are common enough in prose that only letter+digit or long
/// numeric tokens are accepted near them.
const _strongPnrKeywords = [
  'PNR',
  'RECORD LOCATOR',
  'BOOKING REF',
  'BOOKING CODE',
  'BOOKING NUMBER',
  'BOOKING ID',
  'CONFIRMATION CODE',
  'CONFIRMATION NUMBER',
  'RESERVATION CODE',
  'RESERVATION NUMBER',
  'ETICKET',
  'E-TICKET',
  'TICKET NUMBER',
  'ORDER NUMBER',
];

const _weakPnrKeywords = [
  'CONFIRMATION',
  'RESERVATION',
  'REFERENCE',
  'BOOKING',
  'ORDER',
];

/// Explicit labels for the property name on a stay confirmation.
const _stayLabelKeywords = ['HOTEL', 'PROPERTY', 'RESORT', 'ACCOMMODATION'];

/// `"Your reservation at <name>"` style phrasing, common in booking emails.
const _stayPhraseKeywords = [
  'RESERVATION AT',
  'STAYING AT',
  'BOOKED AT',
  'CONFIRMED AT',
  'CHECK-IN AT',
  'STAY AT',
];

/// Property-type words that hint a bare line (no label) names the hotel
/// itself — the common case where the property name is the document's
/// own heading, e.g. "Hotel Paradiso" printed above "Booking confirmation".
const _stayNameHints = {
  'HOTEL',
  'RESORT',
  'INN',
  'SUITES',
  'LODGE',
  'HOSTEL',
  'MOTEL',
  'B&B',
  'GUESTHOUSE',
  'GUEST HOUSE',
  'APARTMENTS',
  'VILLA',
};

/// Generic words that, alongside a property-type hint word, still don't
/// add up to a name — "Hotel booking confirmation" is a heading about the
/// document, not the property, even though it contains "Hotel".
const _stayGenericWords = {
  'BOOKING',
  'RESERVATION',
  'CONFIRMATION',
  'CONFIRMED',
  'DETAILS',
  'VOUCHER',
  'RECEIPT',
  'YOUR',
  'IS',
};

/// A line is boilerplate (not a property name) when every word on it is
/// either a property-type hint (HOTEL, RESORT…) or one of the generic
/// booking words above — i.e. there's no actual proper noun left.
bool _isStayBoilerplateLine(String line) {
  final words =
      line.split(RegExp(r'[\s,.:;!]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return true;
  return words.every(
    (w) => _stayNameHints.contains(w) || _stayGenericWords.contains(w),
  );
}

/// Words that match the PNR token shape but are page furniture.
const _pnrStopwords = {
  'NUMBER', 'BOOKING', 'FLIGHT', 'REFERENCE', 'CONFIRMATION', 'RESERVATION',
  'LOCATOR', 'RECORD', 'CODE', 'DATE', 'NAME', 'CLASS', 'GATE', 'SEAT',
  'FROM', 'DEPART', 'TICKET', 'AIRLINE', 'HOTEL', 'GUEST', 'NIGHTS',
  'ARRIVAL', 'ARRIVE', 'RETURN', 'OUTBOUND', 'INBOUND', 'ADULT', 'CHILD',
  'TOTAL', 'PRICE', 'AIRPORT', 'STATUS', 'ISSUED', 'PLEASE', 'THANK',
  'DETAILS', 'ITINERARY', 'PASSENGER', 'TERMINAL', 'ECONOMY', 'BUSINESS', //
};

final _flightNumberRe = RegExp(r'\b([A-Z]{2})\s?(\d{1,4})\b');
final _pnrTokenRe = RegExp(r'\b[A-Z0-9]{5,10}\b');
final _timeRe = RegExp(r'\b(\d{1,2}):(\d{2})\s*(AM|PM)?');

/// IATA codes are two letters in the vast majority of cases; the odd
/// letter-digit codes (U2, 9W) are out of scope for v1 — documented
/// limitation rather than a looser, false-positive-prone pattern.
TravelDocFields parseTravelDoc(String ocrText, {required DateTime now}) {
  final rawLines = ocrText
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  // Same split/filter as rawLines, so indices line up — used for
  // case-insensitive keyword matching while rawLines preserves the
  // original casing for anything extracted as display text (stay name).
  final lines = rawLines.map((l) => l.toUpperCase()).toList();

  final signals = <String>{};
  for (final line in lines) {
    for (final kw in _flightKeywords) {
      if (line.contains(kw)) signals.add(kw);
    }
  }

  return TravelDocFields(
    flightNumber: _findFlightNumber(lines),
    confirmationCode: _findConfirmationCode(lines),
    stayName: _findStayName(rawLines, lines),
    departureTime: _findDeparture(lines, now),
    expiryDate: _findExpiry(lines, now),
    flightSignals: signals.length,
  );
}

/// Debug aid for diagnosing a document whose fields didn't extract: the
/// lines that mention a field keyword, with a couple of lines of context
/// each. Only the keyword-adjacent slice, never the whole document, and
/// only ever called from `kDebugMode` code paths — but it IS document
/// content, so it must never be logged in a release build.
List<String> travelDocDebugLines(String text, {int maxLines = 40}) {
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final keywordRe = RegExp(
    r'DEPART|\bDEP\b|\bSTD\b|ARRIV|\bARR\b|LAND|PNR|BOOKING|CONFIRMATION|'
    r'RESERVATION|REFERENCE|TICKET|ORDER|FLIGHT|EXPIR|VALID UNTIL',
    caseSensitive: false,
  );
  final wanted = <int>{};
  for (var i = 0; i < lines.length; i++) {
    if (!keywordRe.hasMatch(lines[i])) continue;
    for (var j = i; j <= i + 2 && j < lines.length; j++) {
      wanted.add(j);
    }
  }
  final indices = wanted.toList()..sort();
  return [
    for (final i in indices.take(maxLines))
      '$i: ${lines[i].length > 120 ? '${lines[i].substring(0, 120)}…' : lines[i]}',
  ];
}

String? _findFlightNumber(List<String> lines) {
  // Prefer a match on (or right after) a line that says FLIGHT; fall
  // back to the first pattern hit anywhere.
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].contains('FLIGHT')) continue;
    final m = _flightNumberRe.firstMatch(lines[i]) ??
        (i + 1 < lines.length
            ? _flightNumberRe.firstMatch(lines[i + 1])
            : null);
    if (m != null) return '${m.group(1)}${m.group(2)}';
  }
  for (final line in lines) {
    final m = _flightNumberRe.firstMatch(line);
    if (m != null) return '${m.group(1)}${m.group(2)}';
  }
  return null;
}

String? _findConfirmationCode(List<String> lines) {
  // Strong keywords first across the whole document, then weak ones —
  // a "PNR" hit anywhere beats a "BOOKING" hit that happens to appear
  // earlier in prose.
  for (final strong in [true, false]) {
    final keywords = strong ? _strongPnrKeywords : _weakPnrKeywords;
    for (var i = 0; i < lines.length; i++) {
      final kwIndex = keywords
          .map((kw) => lines[i].contains(kw) ? lines[i].indexOf(kw) : -1)
          .where((idx) => idx >= 0)
          .fold<int>(-1, (a, b) => a < 0 ? b : (b < a ? b : a));
      if (kwIndex < 0) continue;
      // HTML tables put the label and its value in separate cells, which
      // become separate lines and can be a couple of rows apart.
      final searchTexts = [
        lines[i].substring(kwIndex),
        for (var j = i + 1; j <= i + 3 && j < lines.length; j++) lines[j],
      ];
      for (final text in searchTexts) {
        for (final m in _pnrTokenRe.allMatches(text)) {
          final token = m.group(0)!;
          if (_pnrStopwords.contains(token)) continue;
          final hasLetter = token.contains(RegExp('[A-Z]'));
          final hasDigit = token.contains(RegExp(r'\d'));
          // Letter+digit mixes are near-certainly codes anywhere.
          if (hasLetter && hasDigit) return token;
          // All-digit: long enough to be a booking/ticket number.
          if (!hasLetter && token.length >= 6) return token;
          // All-letter 6-char PNRs (ABCDEF) are extremely common but
          // also word-shaped, so only trusted next to a strong keyword.
          if (strong && hasLetter && !hasDigit && token.length == 6) {
            return token;
          }
        }
      }
    }
  }
  return null;
}

/// Trailing address/date noise to cut off a captured name candidate — stay
/// confirmations often run the property name straight into an address or
/// date on the same line ("Hotel Paradiso, 12 Rue de Rivoli, Paris").
final _stayNameTerminatorRe = RegExp(
  r'[,(]|\s-\s|\bON\b|\bFROM\b|\bIS\b|\bWAS\b|\bHAS\b|\bCONFIRMED\b|'
  r'\bCHECK[- ]?IN\b|\bCHECK[- ]?OUT\b',
);

String? _cleanStayCandidate(String candidate) {
  var name = candidate.trim();
  final upper = name.toUpperCase();
  final term = _stayNameTerminatorRe.firstMatch(upper);
  if (term != null) name = name.substring(0, term.start).trim();
  name = name.replaceAll(RegExp(r'^[:\-–—\s]+|[:\-–—\s]+$'), '');
  if (name.isEmpty || name.length > 60) return null;
  if (RegExp(r'^\d').hasMatch(name)) return null; // looks like an address
  return name;
}

/// Extracts the property name from a stay (hotel) confirmation, so the
/// saved title can read e.g. "Hotel Paradiso" instead of the file's own
/// name — which for a downloaded/forwarded confirmation is usually the
/// booking's confirmation number. [rawLines] and [lines] (its uppercased,
/// same-length counterpart) come from the same split, so an index/offset
/// found via [lines] slices the matching original-case text out of
/// [rawLines] — keywords are matched case-insensitively but the returned
/// name keeps its original casing.
String? _findStayName(List<String> rawLines, List<String> lines) {
  // Explicit label at the start of a line: "Hotel: Paradiso Suites".
  for (var i = 0; i < lines.length; i++) {
    for (final label in _stayLabelKeywords) {
      if (!lines[i].startsWith(label)) continue;
      final sep =
          RegExp(r'^\s*[:\-]\s*').firstMatch(lines[i].substring(label.length));
      if (sep == null) continue; // e.g. "HOTEL POLICY" — not a label line
      final candidate = _cleanStayCandidate(
        rawLines[i].substring(label.length + sep.end),
      );
      if (candidate != null) return candidate;
    }
  }

  // Phrase mid-line: "Your reservation at Hotel Paradiso is confirmed".
  for (var i = 0; i < lines.length; i++) {
    for (final phrase in _stayPhraseKeywords) {
      final idx = lines[i].indexOf(phrase);
      if (idx < 0) continue;
      final candidate = _cleanStayCandidate(
        rawLines[i].substring(idx + phrase.length),
      );
      if (candidate != null) return candidate;
    }
  }

  // No label at all: the property name is often the document's own
  // heading — a short early line naming a property type (HOTEL, RESORT…)
  // that isn't generic boilerplate ("Booking confirmation").
  for (var i = 0; i < lines.length && i < 3; i++) {
    if (_isStayBoilerplateLine(lines[i])) continue;
    final hasHint = _stayNameHints.any(
      (hint) => RegExp('\\b${RegExp.escape(hint)}\\b').hasMatch(lines[i]),
    );
    if (!hasHint) continue;
    final candidate = _cleanStayCandidate(rawLines[i]);
    if (candidate != null) return candidate;
  }

  return null;
}

final _departureMarkerRe = RegExp(r'DEPART|\bDEP\b|\bSTD\b');

/// Arrival-side words end the departure block — without this boundary,
/// a "Departure … / Arrival 10:45" layout hands the *arrival* time to
/// the departure field (real bug, reported from real flight documents
/// 2026-07-23).
final _arrivalMarkerRe = RegExp(r'\bARR(IV\w*)?\b|\bLAND(ING|S|ED)?\b|\bETA\b');

DateTime? _findDeparture(List<String> lines, DateTime now) {
  for (var i = 0; i < lines.length; i++) {
    final depMatch = _departureMarkerRe.firstMatch(lines[i]);
    if (depMatch == null) continue;

    // The slice of this line "owned" by departure: from the keyword up
    // to the next arrival marker (handles "DEP 07:25  ARR 10:45" on one
    // line — anything left of DEPART belongs to a previous column too).
    var segment = lines[i].substring(depMatch.start);
    final arrInSegment = _arrivalMarkerRe.firstMatch(segment);
    if (arrInSegment != null) {
      segment = segment.substring(0, arrInSegment.start);
    }

    // Following lines join the window until one mentions arrival —
    // that line and everything after belong to the arrival block. The
    // reach is generous (4 lines) because HTML tables split a single
    // visual row into several lines; the arrival boundary is what keeps
    // that safe rather than a tight window.
    final window = <String>[segment];
    for (var j = i + 1; j <= i + 4 && j < lines.length; j++) {
      if (_arrivalMarkerRe.hasMatch(lines[j])) break;
      window.add(lines[j]);
    }

    DateTime? date;
    (int, int)? time;
    for (final text in window) {
      date ??= _findDate(text);
      time ??= _findTime(text);
    }
    // Tickets often print the date on its own line ABOVE the labeled
    // departure row — date only; a time above the label is likelier to
    // belong to something else.
    if (date == null && i > 0 && !_arrivalMarkerRe.hasMatch(lines[i - 1])) {
      date = _findDate(lines[i - 1]);
    }
    if (date == null || time == null) continue;
    final result = DateTime(date.year, date.month, date.day, time.$1, time.$2);
    // Plausibility: a real upcoming departure, not a misparse.
    if (result.isAfter(now.subtract(const Duration(days: 1))) &&
        result.isBefore(now.add(const Duration(days: 365 * 2)))) {
      return result;
    }
  }
  return null;
}

DateTime? _findExpiry(List<String> lines, DateTime now) {
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!line.contains('EXPIR') &&
        !line.contains('EXP DATE') &&
        !line.contains('VALID UNTIL')) {
      continue;
    }
    final date = _findDate(line) ??
        (i + 1 < lines.length ? _findDate(lines[i + 1]) : null);
    if (date == null) continue;
    if (date.isAfter(now.subtract(const Duration(days: 365 * 5))) &&
        date.isBefore(now.add(const Duration(days: 365 * 40)))) {
      return date;
    }
  }
  return null;
}

const _months = {
  'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6, //
  'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
};

const _monthAlt = 'JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC';

// "13 AUG 2026", "13 AUGUST 2026", "13TH AUG, 2026"
final _monthNameDateRe = RegExp(
  r'\b(\d{1,2})(?:ST|ND|RD|TH)?[\s.,-]*'
  '($_monthAlt)'
  r'[A-Z]*\.?[\s.,-]*'
  r'(\d{2,4})\b',
);

// "AUG 13 2026", "AUGUST 13, 2026" — US-style month-first, very common
// in airline confirmation emails.
final _monthFirstDateRe = RegExp(
  '\\b($_monthAlt)'
  r'[A-Z]*\.?[\s.,-]*'
  r'(\d{1,2})(?:ST|ND|RD|TH)?[\s.,-]*'
  r'(\d{4})\b',
);
final _isoDateRe = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');
// dd/mm/yyyy — day-first, matching this app's existing display formats
// (dd MMM yyyy, dd/MM/yyyy everywhere). US-style mm/dd input would
// misparse; accepted v1 limitation.
final _numericDateRe = RegExp(r'\b(\d{1,2})[/.](\d{1,2})[/.](\d{2,4})\b');

DateTime? _findDate(String text) {
  final byName = _monthNameDateRe.firstMatch(text);
  if (byName != null) {
    final day = int.parse(byName.group(1)!);
    final month = _months[byName.group(2)!]!;
    final year = _fullYear(int.parse(byName.group(3)!));
    return _validDate(year, month, day);
  }
  final monthFirst = _monthFirstDateRe.firstMatch(text);
  if (monthFirst != null) {
    final month = _months[monthFirst.group(1)!]!;
    final day = int.parse(monthFirst.group(2)!);
    final year = int.parse(monthFirst.group(3)!);
    return _validDate(year, month, day);
  }
  final iso = _isoDateRe.firstMatch(text);
  if (iso != null) {
    return _validDate(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  final numeric = _numericDateRe.firstMatch(text);
  if (numeric != null) {
    return _validDate(
      _fullYear(int.parse(numeric.group(3)!)),
      int.parse(numeric.group(2)!),
      int.parse(numeric.group(1)!),
    );
  }
  return null;
}

(int, int)? _findTime(String text) {
  for (final m in _timeRe.allMatches(text)) {
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (min >= 60) continue;
    final meridiem = m.group(3);
    if (meridiem != null) {
      if (h < 1 || h > 12) continue;
      if (meridiem == 'PM' && h != 12) h += 12;
      if (meridiem == 'AM' && h == 12) h = 0;
    } else if (h >= 24) {
      continue;
    }
    return (h, min);
  }
  return null;
}

int _fullYear(int raw) =>
    raw >= 100 ? raw : (raw < 80 ? 2000 + raw : 1900 + raw);

DateTime? _validDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

/// What the form should apply — same never-clobber contract as
/// `computeMrzPrefill`, extended with the flight-specific fields.
/// [detailA]/[detailB] map onto the form's category-specific detail
/// controllers (flight: flightNumber/confirmationCode; stay/transport:
/// booking or confirmation code in A).
class TravelPrefill {
  const TravelPrefill({
    this.category,
    this.title,
    this.expiry,
    this.departureTime,
    this.detailA,
    this.detailB,
  });

  final DocumentCategory? category;
  final String? title;
  final DateTime? expiry;
  final DateTime? departureTime;
  final String? detailA;
  final String? detailB;

  bool get isEmpty =>
      category == null &&
      title == null &&
      expiry == null &&
      departureTime == null &&
      detailA == null &&
      detailB == null;
}

TravelPrefill computeTravelPrefill({
  required TravelDocFields fields,
  required DocumentCategory currentCategory,
  required String currentTitle,
  required String autoTitleFromFile,
  required DateTime? currentExpiry,
  required DateTime? currentDeparture,
  required String currentDetailA,
  required String currentDetailB,
  required AppLocalizations l10n,
}) {
  final categoryIsDefault = currentCategory == DocumentCategory.other;
  final autoCategory = categoryIsDefault && fields.looksLikeFlight
      ? DocumentCategory.flight
      : null;
  final effective = autoCategory ?? currentCategory;
  final titleUntouched =
      currentTitle.trim().isEmpty || currentTitle.trim() == autoTitleFromFile;

  String? detailA;
  String? detailB;
  switch (effective) {
    case DocumentCategory.flight:
      if (currentDetailA.trim().isEmpty) detailA = fields.flightNumber;
      if (currentDetailB.trim().isEmpty) detailB = fields.confirmationCode;
    case DocumentCategory.stay || DocumentCategory.transport:
      if (currentDetailA.trim().isEmpty) detailA = fields.confirmationCode;
    default:
      break;
  }

  // Semantic titles, not the confirmation code the source file/email is
  // usually named after: the flight designator for a flight, the property
  // name for a stay.
  final title = titleUntouched
      ? switch (effective) {
          DocumentCategory.flight when fields.flightNumber != null =>
            l10n.docTitleFlight(fields.flightNumber!),
          DocumentCategory.stay when fields.stayName != null => fields.stayName,
          _ => null,
        }
      : null;

  return TravelPrefill(
    category: autoCategory,
    title: title,
    expiry: currentExpiry == null ? fields.expiryDate : null,
    departureTime:
        effective == DocumentCategory.flight && currentDeparture == null
            ? fields.departureTime
            : null,
    detailA: detailA,
    detailB: detailB,
  );
}
