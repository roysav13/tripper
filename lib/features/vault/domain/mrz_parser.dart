/// Passport MRZ (machine-readable zone) parsing — the two 44-character
/// lines at the bottom of a passport photo page, ICAO 9303 TD3 format.
/// Built first within M5.4 because the fixed format + check digits make
/// it far more reliable than freeform OCR of the rest of the page.
///
/// Pure Dart, no ML-Kit dependency — this consumes whatever raw text the
/// OCR layer produced, so it's unit-testable with fixture strings and
/// never needs a real image.
library;

import 'document.dart';

/// What a successfully parsed MRZ yields. Fields are null when their MRZ
/// check digit didn't validate — a failed check digit means OCR misread
/// those characters, and prefilling a form with misread data is worse
/// than prefilling nothing.
class MrzResult {
  const MrzResult({
    this.documentNumber,
    this.expiryDate,
    required this.surname,
    required this.givenNames,
    required this.issuingCountry,
  });

  final String? documentNumber;
  final DateTime? expiryDate;
  final String surname;
  final List<String> givenNames;
  final String issuingCountry;

  /// "Anna Maria Eriksson" — for a suggested document title.
  String get fullName => [...givenNames, surname]
      .where((part) => part.isNotEmpty)
      .map(_titleCase)
      .join(' ');
}

/// Scans [ocrText] (the raw multi-line output of text recognition over a
/// document photo) for a TD3 passport MRZ and parses it. Returns null if
/// no plausible MRZ is present — callers treat that as "nothing to
/// prefill", never as an error.
///
/// Built around how ML-Kit actually emits a passport page (a real photo
/// produced 47 tiny lines, 2026-07-23 on-device): the two MRZ lines are
/// NOT assumed intact or adjacent. Line 2 carries every check-digit-
/// validated field (document number, expiry), so it's searched for
/// independently — it self-validates, no pairing needed. Fragmentation
/// (one physical line split across several OCR lines) is healed by also
/// trying joins of up to 3 consecutive MRZ-alphabet-only lines. Line 1
/// (names) is a separate best-effort search; the result stands without
/// it. Also tolerated: OCR-inserted spaces, guillemet misreads of `<`,
/// truncated trailing filler.
MrzResult? parseMrz(String ocrText) {
  final lines = ocrText
      .split(RegExp(r'[\r\n]+'))
      .map(_normalizeMrzLine)
      .where((l) => l.isNotEmpty)
      .toList();

  final candidates = _mrzCandidates(lines);

  // --- line 2: the self-validating payload ---
  // Two passes: first accept only candidates where BOTH check digits
  // validate — fragment joins can shift other MRZ fields (birth date has
  // its own valid check digit) into the expiry position, and a
  // both-digits requirement is what rules those out. Only if no fully
  // valid candidate exists fall back to single-field validation (a real
  // line 2 where OCR misread one field's characters).
  ({String? documentNumber, DateTime? expiryDate})? line2;
  for (final requireBoth in const [true, false]) {
    for (final c in candidates) {
      if (c.length >= 28) {
        line2 = _parseLine2(_padMrz(c), requireBoth: requireBoth);
        if (line2 != null) break;
      }
      // A candidate holding both lines merged (starts with P<, ~88
      // chars): line 2 is its tail.
      if (c.startsWith('P<') && c.length >= 80) {
        line2 = _parseLine2(_padMrz(c.substring(44)), requireBoth: requireBoth);
        if (line2 != null) break;
      }
    }
    if (line2 != null) break;
  }
  if (line2 == null) return null;

  // --- line 1: names, best effort ---
  var surname = '';
  var givenNames = const <String>[];
  var issuingCountry = '';
  for (final c in candidates) {
    if (!c.startsWith('P<') || c.length < 8) continue;
    final nameField = _padMrz(c).substring(5);
    final nameParts = nameField.split('<<');
    final s = nameParts.first.replaceAll('<', ' ').trim();
    if (s.isEmpty) continue;
    surname = s;
    givenNames = nameParts.length > 1
        ? nameParts[1].split('<').where((p) => p.isNotEmpty).toList()
        : const <String>[];
    issuingCountry = c.substring(2, 5).replaceAll('<', '');
    break;
  }

  return MrzResult(
    documentNumber: line2.documentNumber,
    expiryDate: line2.expiryDate,
    surname: surname,
    givenNames: givenNames,
    issuingCountry: issuingCountry,
  );
}

/// Every run of 1-3 consecutive MRZ-alphabet-only lines, joined in order
/// — singles first so an intact line wins before any join is tried.
List<String> _mrzCandidates(List<String> lines) {
  final candidates = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (!_isMrzAlphabet(lines[i])) continue;
    var joined = lines[i];
    candidates.add(joined);
    for (var j = i + 1; j <= i + 2 && j < lines.length; j++) {
      if (!_isMrzAlphabet(lines[j])) break;
      joined += lines[j];
      candidates.add(joined);
    }
  }
  return candidates;
}

bool _isMrzAlphabet(String line) => RegExp(r'^[A-Z0-9<]+$').hasMatch(line);

/// Parses a padded 44-char candidate as TD3 line 2. Positions: 0-8
/// document number, 9 its check digit, 21-26 expiry YYMMDD, 27 its check
/// digit. (10-20 are nationality/birth/sex — not needed for the form.)
/// Check digits are the entire reason MRZ parsing is trustworthy (SPEC:
/// "high-accuracy" is the point of doing MRZ first), and they're also
/// what makes the independent line-2 search safe against false matches —
/// see the two-pass note at the call site for [requireBoth].
({String? documentNumber, DateTime? expiryDate})? _parseLine2(
  String line2, {
  required bool requireBoth,
}) {
  if (!RegExp(r'^[A-Z0-9<]{44}$').hasMatch(line2)) return null;

  final numberRaw = line2.substring(0, 9);
  final expiryRaw = line2.substring(21, 27);

  final documentNumber = _checkDigitMatches(numberRaw, line2[9])
      ? numberRaw.replaceAll('<', '')
      : null;
  final expiryDate = _checkDigitMatches(expiryRaw, line2[27])
      ? _parseMrzDate(expiryRaw)
      : null;

  if (requireBoth && (documentNumber == null || expiryDate == null)) {
    return null;
  }
  if (documentNumber == null && expiryDate == null) return null;
  return (documentNumber: documentNumber, expiryDate: expiryDate);
}

/// Uppercases, strips OCR-inserted spaces, and maps guillemet misreads
/// back to the `<` filler character they almost certainly were.
String _normalizeMrzLine(String line) => line
    .replaceAll(' ', '')
    .toUpperCase()
    .replaceAll('«', '<<')
    .replaceAll('»', '<<')
    .replaceAll('‹', '<')
    .replaceAll('›', '<');

String _padMrz(String line) =>
    line.length >= 44 ? line.substring(0, 44) : line.padRight(44, '<');

/// ICAO 9303 check digit: weights 7-3-1 repeating; A-Z = 10-35, `<` = 0.
bool _checkDigitMatches(String field, String check) {
  final digit = int.tryParse(check);
  if (digit == null) return false;
  const weights = [7, 3, 1];
  var sum = 0;
  for (var i = 0; i < field.length; i++) {
    final c = field.codeUnitAt(i);
    final int value;
    if (c >= 0x30 && c <= 0x39) {
      value = c - 0x30; // 0-9
    } else if (c >= 0x41 && c <= 0x5A) {
      value = c - 0x41 + 10; // A-Z
    } else if (c == 0x3C) {
      value = 0; // <
    } else {
      return false;
    }
    sum += value * weights[i % 3];
  }
  return sum % 10 == digit;
}

/// YYMMDD. Two-digit years pivot at 80: passports are valid at most ~10
/// years, so an expiry of "79" can only mean 2079, while "85" in an MRZ
/// today could only plausibly be a long-expired 1985 document.
DateTime? _parseMrzDate(String raw) {
  final yy = int.tryParse(raw.substring(0, 2));
  final mm = int.tryParse(raw.substring(2, 4));
  final dd = int.tryParse(raw.substring(4, 6));
  if (yy == null || mm == null || dd == null) return null;
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
  final year = yy < 80 ? 2000 + yy : 1900 + yy;
  return DateTime(year, mm, dd);
}

String _titleCase(String word) => word.isEmpty
    ? word
    : word[0].toUpperCase() + word.substring(1).toLowerCase();

/// What the form should apply after a successful MRZ parse. Null field =
/// leave that form field alone. Kept as a pure computation (rather than
/// logic buried in widget state) so the never-clobber-user-input rules
/// are unit-testable without a widget tree, file picker, or ML-Kit.
class MrzPrefill {
  const MrzPrefill({this.category, this.title, this.expiry, this.number});

  final DocumentCategory? category;
  final String? title;
  final DateTime? expiry;
  final String? number;

  bool get isEmpty =>
      category == null && title == null && expiry == null && number == null;
}

/// The no-clobber rules for OCR prefill (M5.4, SPEC: "never silently
/// overwrites a field the user already typed"):
/// - category: only replaced while it's still the untouched default
///   ([DocumentCategory.other])
/// - title: replaced only when empty or still the filename auto-fill —
///   both count as "not user input"; anything typed stays
/// - expiry / document number: only filled when currently empty
/// - number is only offered when the category is (or is becoming) the
///   passport category, since that's the detail field it maps to
MrzPrefill computeMrzPrefill({
  required MrzResult mrz,
  required DocumentCategory currentCategory,
  required String currentTitle,
  required String autoTitleFromFile,
  required DateTime? currentExpiry,
  required String currentNumber,
}) {
  final categoryIsDefault = currentCategory == DocumentCategory.other;
  final titleUntouched =
      currentTitle.trim().isEmpty || currentTitle.trim() == autoTitleFromFile;
  final willBePassport =
      categoryIsDefault || currentCategory == DocumentCategory.passportId;
  return MrzPrefill(
    category: categoryIsDefault ? DocumentCategory.passportId : null,
    title: titleUntouched && mrz.fullName.isNotEmpty ? mrz.fullName : null,
    expiry: currentExpiry == null ? mrz.expiryDate : null,
    number: willBePassport && currentNumber.trim().isEmpty
        ? mrz.documentNumber
        : null,
  );
}
