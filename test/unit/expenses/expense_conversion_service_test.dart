import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripper/features/expenses/data/exchange_rate_service.dart';
import 'package:tripper/features/expenses/data/expense_conversion_service.dart';
import 'package:tripper/features/expenses/domain/exchange_rates.dart';
import 'package:tripper/features/expenses/domain/expense.dart';

import '../../helpers/fake_expense_repository.dart';

final _now = DateTime(2026, 7, 23, 9);

/// Returns rates when [online], null otherwise — the offline case is the
/// whole point of the stored-conversion design.
class _FakeRateSource implements ExchangeRateSource {
  _FakeRateSource({this.online = true});

  bool online;
  int fetchCount = 0;

  @override
  Future<ExchangeRateSnapshot?> fetch(String base) async {
    fetchCount++;
    if (!online) return null;
    return ExchangeRateSnapshot(
      base: base,
      rates: const {'USD': 0.27, 'EUR': 0.25},
      fetchedAt: _now,
    );
  }
}

Expense _expense({
  required String id,
  int amountMinor = 10000,
  String currency = 'USD',
  int? convertedAmountMinor,
  String? convertedCurrency,
}) =>
    Expense(
      id: id,
      tripId: 't1',
      amountMinor: amountMinor,
      currency: currency,
      category: ExpenseCategory.food,
      date: DateTime(2026, 8, 2),
      convertedAmountMinor: convertedAmountMinor,
      convertedCurrency: convertedCurrency,
    );

void main() {
  late FakeExpenseRepository repo;
  late _FakeRateSource source;
  late ExpenseConversionService service;

  Future<void> build({bool online = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    source = _FakeRateSource(online: online);
    service = ExpenseConversionService(
      repo,
      ExchangeRateService(source, prefs, () => _now),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    repo = FakeExpenseRepository();
  });

  test('converts expenses that are not already in the home currency', () async {
    repo.emit([_expense(id: 'a', amountMinor: 2700, currency: 'USD')]);
    await build();

    final count = await service.backfill('ILS');

    expect(count, 1);
    final stored = (await repo.getAll()).single;
    expect(stored.convertedCurrency, 'ILS');
    expect(stored.convertedAmountMinor, 10000); // 27 USD -> 100 ILS
    expect(stored.convertedRateAt, _now);
  });

  test(
      'expenses already in the home currency are left alone — no rate '
      'lookup needed', () async {
    repo.emit([_expense(id: 'a', currency: 'ILS')]);
    await build();

    expect(await service.backfill('ILS'), 0);
    expect(source.fetchCount, 0);
    expect((await repo.getAll()).single.convertedAmountMinor, isNull);
  });

  test(
      'offline leaves the expense unconverted rather than storing a '
      'wrong or zero value', () async {
    repo.emit([_expense(id: 'a')]);
    await build(online: false);

    expect(await service.backfill('ILS'), 0);
    final stored = (await repo.getAll()).single;
    expect(stored.convertedAmountMinor, isNull);
    expect(stored.isConverted, isFalse);
  });

  test(
      'a later backfill (connection returned) fills in what was left '
      'pending', () async {
    repo.emit([_expense(id: 'a', amountMinor: 2700)]);
    await build(online: false);
    await service.backfill('ILS');
    expect((await repo.getAll()).single.isConverted, isFalse);

    source.online = true;
    await service.backfill('ILS');

    expect((await repo.getAll()).single.convertedAmountMinor, 10000);
  });

  test('an unconvertible currency stays pending instead of being zeroed',
      () async {
    repo.emit([_expense(id: 'a', currency: 'THB')]);
    await build();

    expect(await service.backfill('ILS'), 0);
    expect((await repo.getAll()).single.convertedAmountMinor, isNull);
  });

  test('already-converted expenses are not re-converted', () async {
    repo.emit([
      _expense(
        id: 'a',
        convertedAmountMinor: 999,
        convertedCurrency: 'ILS',
      ),
    ]);
    await build();

    expect(await service.backfill('ILS'), 0);
    expect((await repo.getAll()).single.convertedAmountMinor, 999);
  });

  test(
      'changing the home currency clears conversions pointing at the '
      'old one, so the next backfill recomputes them', () async {
    repo.emit([
      _expense(id: 'a', convertedAmountMinor: 999, convertedCurrency: 'ILS'),
      _expense(id: 'b', convertedAmountMinor: 111, convertedCurrency: 'EUR'),
    ]);
    await build();

    await service.clearStaleConversions('EUR');

    final all = await repo.getAll();
    // The ILS one was stale for a EUR home currency -> cleared.
    expect(all.firstWhere((e) => e.id == 'a').convertedAmountMinor, isNull);
    // The EUR one already matched -> untouched.
    expect(all.firstWhere((e) => e.id == 'b').convertedAmountMinor, 111);
  });
}
