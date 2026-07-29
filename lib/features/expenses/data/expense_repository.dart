import '../../../core/database/app_database.dart';
import '../domain/expense.dart';
import 'expenses_dao.dart';

/// Widget tests mock at this boundary (testing rules).
abstract interface class ExpenseRepository {
  Stream<List<Expense>> watchForTrip(String tripId);

  /// Across all trips — drives the conversion backfill, which is global.
  Stream<List<Expense>> watchAll();
  Future<Expense?> getById(String id);
  Future<String> createExpense({
    required String tripId,
    required int amountMinor,
    required String currency,
    required ExpenseCategory category,
    required DateTime date,
    String notes,
  });
  Future<void> updateExpense(Expense expense);
  Future<void> deleteExpense(String id);

  /// Every expense across all trips — the conversion backfill's work
  /// list (conversion is a global concern, not per-trip).
  Future<List<Expense>> getAll();

  /// Stores a computed conversion. Passing nulls clears it, which is
  /// what a home-currency change does before re-converting.
  Future<void> setConversion(
    String id, {
    required int? amountMinor,
    required String? currency,
    required DateTime? rateAt,
  });
}

class DriftExpenseRepository implements ExpenseRepository {
  DriftExpenseRepository(this._dao, this._clock, this._idGen);

  final ExpensesDao _dao;
  final DateTime Function() _clock;
  final String Function() _idGen;

  @override
  Stream<List<Expense>> watchForTrip(String tripId) =>
      _dao.watchForTrip(tripId).map((rows) => rows.map(_toDomain).toList());

  @override
  Stream<List<Expense>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_toDomain).toList());

  @override
  Future<Expense?> getById(String id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<String> createExpense({
    required String tripId,
    required int amountMinor,
    required String currency,
    required ExpenseCategory category,
    required DateTime date,
    String notes = '',
  }) async {
    final id = _idGen();
    await _dao.insertExpense(
      ExpenseRow(
        id: id,
        tripId: tripId,
        amountMinor: amountMinor,
        currency: currency.toUpperCase(),
        category: category.index,
        date: date,
        notes: notes.trim(),
        createdAt: _clock(),
      ),
    );
    return id;
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    final existing = await _dao.getById(expense.id);
    if (existing == null) return;
    await _dao.updateExpense(
      existing.copyWith(
        amountMinor: expense.amountMinor,
        currency: expense.currency.toUpperCase(),
        category: expense.category.index,
        date: expense.date,
        notes: expense.notes.trim(),
      ),
    );
  }

  @override
  Future<void> deleteExpense(String id) => _dao.deleteExpense(id);

  @override
  Future<List<Expense>> getAll() async =>
      (await _dao.getAll()).map(_toDomain).toList();

  @override
  Future<void> setConversion(
    String id, {
    required int? amountMinor,
    required String? currency,
    required DateTime? rateAt,
  }) =>
      _dao.setConversion(
        id,
        amountMinor: amountMinor,
        currency: currency,
        rateAt: rateAt,
      );

  Expense _toDomain(ExpenseRow row) => Expense(
        id: row.id,
        tripId: row.tripId,
        amountMinor: row.amountMinor,
        currency: row.currency,
        // Defensive: an index from a newer schema version falls back to
        // `other` rather than throwing a RangeError on an old build.
        category: row.category < ExpenseCategory.values.length
            ? ExpenseCategory.values[row.category]
            : ExpenseCategory.other,
        date: row.date,
        notes: row.notes,
        convertedAmountMinor: row.convertedAmountMinor,
        convertedCurrency: row.convertedCurrency,
        convertedRateAt: row.convertedRateAt,
      );
}
