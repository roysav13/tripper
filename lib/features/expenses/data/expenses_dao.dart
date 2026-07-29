import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'expense_tables.dart';

part 'expenses_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  /// Newest first — the spend list reads as a running log.
  Stream<List<ExpenseRow>> watchForTrip(String tripId) {
    return (select(expenses)
          ..where((e) => e.tripId.equals(tripId))
          ..orderBy([
            (e) => OrderingTerm.desc(e.date),
            (e) => OrderingTerm.desc(e.createdAt),
          ]))
        .watch();
  }

  Future<ExpenseRow?> getById(String id) =>
      (select(expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<void> insertExpense(ExpenseRow row) => into(expenses).insert(row);

  Future<void> updateExpense(ExpenseRow row) => update(expenses).replace(row);

  Future<void> deleteExpense(String id) =>
      (delete(expenses)..where((e) => e.id.equals(id))).go();

  /// All trips' expenses — the conversion backfill operates globally.
  Future<List<ExpenseRow>> getAll() => select(expenses).get();

  Stream<List<ExpenseRow>> watchAll() => select(expenses).watch();

  /// Writes (or with nulls, clears) the stored conversion. Uses
  /// `Value(...)` explicitly so null means "set to null", not "leave
  /// unchanged" — clearing is a real operation here (home-currency
  /// change invalidates every stored conversion).
  Future<void> setConversion(
    String id, {
    required int? amountMinor,
    required String? currency,
    required DateTime? rateAt,
  }) {
    return (update(expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        convertedAmountMinor: Value(amountMinor),
        convertedCurrency: Value(currency),
        convertedRateAt: Value(rateAt),
      ),
    );
  }
}
