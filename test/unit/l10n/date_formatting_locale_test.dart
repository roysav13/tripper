import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test(
      'a DateFormat pinned to en_US renders English month names even when '
      "Intl.defaultLocale is Hebrew — the fix this task's call sites rely on",
      () {
    final original = Intl.defaultLocale;
    Intl.defaultLocale = 'he';
    addTearDown(() => Intl.defaultLocale = original);

    final pinned = DateFormat('dd MMM yyyy', 'en_US');
    expect(pinned.format(DateTime(2026, 7, 16)), '16 Jul 2026');

    // Without a pinned locale, the same pattern picks up the active
    // Intl.defaultLocale instead — demonstrating why the pin matters,
    // not just asserting the pinned behavior in isolation.
    final unpinned = DateFormat('dd MMM yyyy');
    expect(unpinned.format(DateTime(2026, 7, 16)), isNot('16 Jul 2026'));
  });
}
