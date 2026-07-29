import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';
import 'package:tripper/features/expenses/data/expense_repository.dart';
import 'package:tripper/features/expenses/domain/expense.dart';
import 'package:tripper/features/trips/data/trip_repository.dart';

void main() {
  late AppDatabase db;
  late DriftExpenseRepository repo;
  late DriftTripRepository tripRepo;
  var idCounter = 0;
  final clock = DateTime(2026, 7, 23);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    idCounter = 0;
    repo = DriftExpenseRepository(
      db.expensesDao,
      () => clock,
      () => 'exp-${idCounter++}',
    );
    tripRepo = DriftTripRepository(db.tripsDao, () => clock);
  });

  tearDown(() => db.close());

  Future<String> createTrip([String name = 'Thailand']) => tripRepo.createTrip(
        name: name,
        destinations: ['Krabi'],
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 14),
        colorTag: 0,
      );

  Future<String> addExpense(
    String tripId, {
    int amountMinor = 1000,
    ExpenseCategory category = ExpenseCategory.food,
    DateTime? date,
    String notes = '',
  }) =>
      repo.createExpense(
        tripId: tripId,
        amountMinor: amountMinor,
        currency: 'ils', // lowercase on purpose — normalization is tested
        category: category,
        date: date ?? DateTime(2026, 8, 2),
        notes: notes,
      );

  test('create then read back, with currency uppercased', () async {
    final tripId = await createTrip();
    final id = await addExpense(tripId, amountMinor: 1230);

    final expense = await repo.getById(id);
    expect(expense, isNotNull);
    expect(expense!.amountMinor, 1230);
    expect(expense.currency, 'ILS');
    expect(expense.category, ExpenseCategory.food);
    expect(expense.tripId, tripId);
  });

  test('watchForTrip returns only that trip\'s expenses', () async {
    final tripA = await createTrip('A');
    final tripB = await createTrip('B');
    await addExpense(tripA, amountMinor: 100);
    await addExpense(tripB, amountMinor: 200);

    final forA = await repo.watchForTrip(tripA).first;
    expect(forA, hasLength(1));
    expect(forA.single.amountMinor, 100);
  });

  test('watchForTrip is newest-date first', () async {
    final tripId = await createTrip();
    await addExpense(tripId, amountMinor: 1, date: DateTime(2026, 8, 1));
    await addExpense(tripId, amountMinor: 2, date: DateTime(2026, 8, 5));
    await addExpense(tripId, amountMinor: 3, date: DateTime(2026, 8, 3));

    final rows = await repo.watchForTrip(tripId).first;
    expect(rows.map((e) => e.amountMinor), [2, 3, 1]);
  });

  test('a live subscription re-emits when an expense is added', () async {
    final tripId = await createTrip();
    final emissions = <int>[];
    final sub =
        repo.watchForTrip(tripId).listen((rows) => emissions.add(rows.length));
    await Future<void>.delayed(Duration.zero);

    await addExpense(tripId);
    await Future<void>.delayed(Duration.zero);

    expect(emissions.last, 1);
    await sub.cancel();
  });

  test('update changes the row in place', () async {
    final tripId = await createTrip();
    final id = await addExpense(tripId, amountMinor: 500);
    final original = (await repo.getById(id))!;

    await repo.updateExpense(
      original.copyWith(
        amountMinor: 750,
        category: ExpenseCategory.transport,
        notes: '  taxi  ',
      ),
    );

    final updated = (await repo.getById(id))!;
    expect(updated.amountMinor, 750);
    expect(updated.category, ExpenseCategory.transport);
    expect(updated.notes, 'taxi'); // trimmed
  });

  test('updating a non-existent expense is a no-op, not a crash', () async {
    final tripId = await createTrip();
    final ghost = Expense(
      id: 'nope',
      tripId: tripId,
      amountMinor: 1,
      currency: 'ILS',
      category: ExpenseCategory.other,
      date: clock,
    );
    await expectLater(repo.updateExpense(ghost), completes);
  });

  test('delete removes it', () async {
    final tripId = await createTrip();
    final id = await addExpense(tripId);
    await repo.deleteExpense(id);
    expect(await repo.getById(id), isNull);
  });

  test(
      'deleting a trip cascades to its expenses (unlike places, which '
      'survive their trip)', () async {
    final tripId = await createTrip();
    await addExpense(tripId);
    expect(await repo.watchForTrip(tripId).first, hasLength(1));

    await tripRepo.deleteTrip(tripId);

    expect(await repo.watchForTrip(tripId).first, isEmpty);
  });

  test('amounts round-trip exactly at scale — no float drift', () async {
    final tripId = await createTrip();
    for (var i = 0; i < 100; i++) {
      await addExpense(tripId, amountMinor: 10); // 0.10 each
    }
    final rows = await repo.watchForTrip(tripId).first;
    expect(totalMinor(rows), 1000); // exactly 10.00
    expect(formatMinor(totalMinor(rows)), '10.00');
  });
}
