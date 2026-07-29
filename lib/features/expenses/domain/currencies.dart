import 'package:flutter/foundation.dart';

/// A currency the app will accept. Curated rather than free-text so a
/// typo ("NIS", which isn't an ISO code at all) can't be stored and then
/// silently fail every conversion lookup forever.
@immutable
class Currency {
  const Currency(this.code, this.name, this.symbol, {this.minorDigits = 2});

  /// ISO-4217, uppercase.
  final String code;
  final String name;
  final String symbol;

  /// Decimal places. **Not always 2** — JPY, KRW and VND have none, so
  /// ¥1000 is 1000 minor units, not 100000. Everything that formats,
  /// parses or converts an amount has to respect this or it's wrong by
  /// a factor of 100.
  final int minorDigits;
}

/// Travel-oriented selection: majors, plus the currencies this app's
/// users actually spend in. Deliberately not all ~160 ISO codes — a
/// shorter list is easier to scan and every entry here is one the rate
/// endpoint covers.
const kCurrencies = <Currency>[
  Currency('ILS', 'Israeli new shekel', '₪'),
  Currency('USD', 'US dollar', r'$'),
  Currency('EUR', 'Euro', '€'),
  Currency('GBP', 'British pound', '£'),
  Currency('JPY', 'Japanese yen', '¥', minorDigits: 0),
  Currency('THB', 'Thai baht', '฿'),
  Currency('VND', 'Vietnamese dong', '₫', minorDigits: 0),
  Currency('KRW', 'South Korean won', '₩', minorDigits: 0),
  Currency('CNY', 'Chinese yuan', '¥'),
  Currency('INR', 'Indian rupee', '₹'),
  Currency('IDR', 'Indonesian rupiah', 'Rp'),
  Currency('SGD', 'Singapore dollar', r'S$'),
  Currency('MYR', 'Malaysian ringgit', 'RM'),
  Currency('PHP', 'Philippine peso', '₱'),
  Currency('AUD', 'Australian dollar', r'A$'),
  Currency('NZD', 'New Zealand dollar', r'NZ$'),
  Currency('CAD', 'Canadian dollar', r'C$'),
  Currency('CHF', 'Swiss franc', 'CHF'),
  Currency('SEK', 'Swedish krona', 'kr'),
  Currency('NOK', 'Norwegian krone', 'kr'),
  Currency('DKK', 'Danish krone', 'kr'),
  Currency('PLN', 'Polish zloty', 'zł'),
  Currency('CZK', 'Czech koruna', 'Kč'),
  Currency('HUF', 'Hungarian forint', 'Ft'),
  Currency('RON', 'Romanian leu', 'lei'),
  Currency('TRY', 'Turkish lira', '₺'),
  Currency('AED', 'UAE dirham', 'AED'),
  Currency('SAR', 'Saudi riyal', 'SAR'),
  Currency('EGP', 'Egyptian pound', 'E£'),
  Currency('ZAR', 'South African rand', 'R'),
  Currency('MAD', 'Moroccan dirham', 'MAD'),
  Currency('MXN', 'Mexican peso', r'MX$'),
  Currency('BRL', 'Brazilian real', r'R$'),
  Currency('ARS', 'Argentine peso', r'AR$'),
  Currency('CLP', 'Chilean peso', r'CL$', minorDigits: 0),
  Currency('COP', 'Colombian peso', r'CO$'),
  Currency('PEN', 'Peruvian sol', 'S/'),
  Currency('HKD', 'Hong Kong dollar', r'HK$'),
  Currency('TWD', 'Taiwan dollar', r'NT$'),
  Currency('GEL', 'Georgian lari', '₾'),
  Currency('RSD', 'Serbian dinar', 'din'),
  Currency('ISK', 'Icelandic krona', 'kr', minorDigits: 0),
];

final Map<String, Currency> _byCode = {
  for (final c in kCurrencies) c.code: c,
};

Currency? currencyFor(String code) => _byCode[code.trim().toUpperCase()];

bool isSupportedCurrency(String code) => _byCode.containsKey(
      code.trim().toUpperCase(),
    );

/// Decimal places for [code]. Falls back to 2 for anything unrecognised
/// — legacy rows from before the picker existed still format sanely.
int minorDigitsFor(String code) => currencyFor(code)?.minorDigits ?? 2;

/// Matches on code, name, or symbol so "shek", "ILS" and "₪" all find
/// the shekel.
List<Currency> searchCurrencies(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kCurrencies;
  return [
    for (final c in kCurrencies)
      if (c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          c.symbol.toLowerCase().contains(q))
        c,
  ];
}
