import 'dart:async';

import 'package:tripper/features/expenses/data/expense_repository.dart';
import 'package:tripper/features/expenses/domain/expense.dart';

/// Fake at the repository boundary (testing rules — no DB in widget tests).
class FakeExpenseRepository implements ExpenseRepository {
  FakeExpenseRepository([List<Expense> initial = const []])
      : _expenses = [...initial];

  final List<Expense> _expenses;
  final _controller = StreamController<List<Expense>>.broadcast();
  var _idCounter = 0;

  void emit(List<Expense> expenses) {
    _expenses
      ..clear()
      ..addAll(expenses);
    _controller.add(List.of(expenses));
  }

  /// States-audit support — simulates a stream failure.
  void emitError(Object error) => _controller.addError(error);

  List<Expense> _forTrip(String tripId) => [
        for (final e in _expenses)
          if (e.tripId == tripId) e,
      ];

  @override
  Stream<List<Expense>> watchForTrip(String tripId) async* {
    yield _forTrip(tripId);
    yield* _controller.stream.map((_) => _forTrip(tripId));
  }

  @override
  Stream<List<Expense>> watchAll() async* {
    yield List.of(_expenses);
    yield* _controller.stream;
  }

  @override
  Future<List<Expense>> getAll() async => List.of(_expenses);

  @override
  Future<void> setConversion(
    String id, {
    required int? amountMinor,
    required String? currency,
    required DateTime? rateAt,
  }) async {
    emit([
      for (final e in _expenses)
        if (e.id == id)
          e.copyWith(
            convertedAmountMinor: () => amountMinor,
            convertedCurrency: () => currency,
            convertedRateAt: () => rateAt,
          )
        else
          e,
    ]);
  }

  @override
  Future<Expense?> getById(String id) async =>
      _expenses.where((e) => e.id == id).firstOrNull;

  @override
  Future<String> createExpense({
    required String tripId,
    required int amountMinor,
    required String currency,
    required ExpenseCategory category,
    required DateTime date,
    String notes = '',
  }) async {
    final expense = Expense(
      id: 'fake-${_idCounter++}',
      tripId: tripId,
      amountMinor: amountMinor,
      currency: currency.toUpperCase(),
      category: category,
      date: date,
      notes: notes.trim(),
    );
    emit([..._expenses, expense]);
    return expense.id;
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    emit([
      for (final e in _expenses)
        if (e.id == expense.id) expense else e,
    ]);
  }

  @override
  Future<void> deleteExpense(String id) async {
    emit([..._expenses.where((e) => e.id != id)]);
  }
}
