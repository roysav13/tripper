import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> he;

  setUpAll(() {
    en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    he = jsonDecode(File('lib/l10n/app_he.arb').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('app_he.arb has exactly the same keys as app_en.arb', () {
    final enKeys = en.keys.where((k) => k != '@@locale').toSet();
    final heKeys = he.keys.where((k) => k != '@@locale').toSet();

    final missingFromHe = enKeys.difference(heKeys);
    final extraInHe = heKeys.difference(enKeys);

    expect(
      missingFromHe,
      isEmpty,
      reason:
          'app_he.arb is missing keys present in app_en.arb: $missingFromHe',
    );
    expect(
      extraInHe,
      isEmpty,
      reason: 'app_he.arb has keys not present in app_en.arb: $extraInHe',
    );
  });

  test(
      'every @-prefixed placeholder-metadata key has matching placeholder '
      'names in both files', () {
    for (final key in en.keys) {
      if (!key.startsWith('@') || key == '@@locale') continue;
      final enMeta = en[key] as Map<String, dynamic>;
      final heMeta = he[key] as Map<String, dynamic>?;
      expect(heMeta, isNotNull, reason: '$key missing from app_he.arb');
      final enPlaceholders =
          (enMeta['placeholders'] as Map<String, dynamic>?)?.keys.toSet() ?? {};
      final hePlaceholders =
          (heMeta!['placeholders'] as Map<String, dynamic>?)?.keys.toSet() ??
              {};
      expect(
        hePlaceholders,
        enPlaceholders,
        reason:
            '$key: placeholder names differ between app_en.arb and app_he.arb',
      );
    }
  });

  test(
      'every {placeholder} token used in an English string also appears '
      'in its Hebrew translation', () {
    final placeholderToken = RegExp(r'\{(\w+)\}');
    for (final key in en.keys) {
      if (key.startsWith('@')) continue;
      final enValue = en[key] as String;
      final heValue = he[key] as String?;
      if (heValue == null) continue; // caught by the key-parity test above
      final enTokens =
          placeholderToken.allMatches(enValue).map((m) => m.group(1)).toSet();
      final heTokens =
          placeholderToken.allMatches(heValue).map((m) => m.group(1)).toSet();
      expect(
        heTokens,
        enTokens,
        reason:
            '$key: placeholder tokens differ — en has $enTokens, he has $heTokens',
      );
    }
  });
}
