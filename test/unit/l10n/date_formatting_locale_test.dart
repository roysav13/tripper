import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test(
      'a DateFormat pinned to the Hebrew locale renders Hebrew month names, '
      'and pinned to English renders English month names — the fix each app '
      "call site's DateFormat(pattern, l10n.localeName) relies on", () {
    final english =
        DateFormat('dd MMM yyyy', 'en').format(DateTime(2026, 7, 16));
    expect(english, '16 Jul 2026');

    final hebrew =
        DateFormat('dd MMM yyyy', 'he').format(DateTime(2026, 7, 16));
    expect(hebrew, isNot(english));
    expect(RegExp('[֐-׿]').hasMatch(hebrew), isTrue);
  });

  test(
      'the pinned locale is explicit, not inherited from Intl.defaultLocale '
      '— call sites must pass l10n.localeName rather than rely on the '
      'ambient default', () {
    final original = Intl.defaultLocale;
    Intl.defaultLocale = 'he';
    addTearDown(() => Intl.defaultLocale = original);

    final pinnedToEnglish =
        DateFormat('dd MMM yyyy', 'en').format(DateTime(2026, 7, 16));
    expect(pinnedToEnglish, '16 Jul 2026');
  });
}
