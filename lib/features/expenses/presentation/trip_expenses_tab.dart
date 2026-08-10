import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/expense.dart';
import 'currency_picker.dart';
import 'expense_form_sheet.dart';
import 'expense_providers.dart';
import 'expense_widgets.dart';

/// Spend tab inside a trip's detail screen (M5.5).
class TripExpensesTab extends ConsumerWidget {
  const TripExpensesTab({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncExpenses = ref.watch(tripExpensesProvider(trip.id));
    final expenses = asyncExpenses.valueOrNull ?? const <Expense>[];
    final summary = ref.watch(tripExpenseSummaryProvider(trip.id));

    if (asyncExpenses.hasError) {
      return ErrorState(
        onRetry: () => ref.invalidate(tripExpensesProvider(trip.id)),
      );
    }

    if (asyncExpenses.hasValue && expenses.isEmpty) {
      return EmptyState(
        icon: Icons.payments_outlined,
        title: l10n.expensesEmptyTitle,
        body: l10n.expensesEmptyBody,
        ctaLabel: l10n.expensesEmptyCta,
        onCta: () => _addExpense(
          context,
          ref,
          tripId: trip.id,
          defaultCurrency: summary.mainCurrency,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.expensesEmptyCta,
        backgroundColor: colors.accent,
        foregroundColor: colors.surface,
        onPressed: () => _addExpense(
          context,
          ref,
          tripId: trip.id,
          defaultCurrency: summary.mainCurrency,
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        children: [
          ExpenseSummaryCard(
            totals: summary.totals,
            breakdown: summary.breakdown,
            home: summary.home,
            homeCurrency: summary.homeCurrency,
            showConversionOffHint:
                summary.homeCurrency.isEmpty && summary.totals.length > 1,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final expense in expenses)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: ExpenseRowCard(
                expense: expense,
                onTap: () => showExpenseFormSheet(
                  context,
                  tripId: trip.id,
                  existing: expense,
                  defaultCurrency: summary.mainCurrency,
                ),
                onDelete: () => _delete(context, ref, expense),
              ),
            ),
        ],
      ),
    );
  }

  /// Both the FAB and the empty-state CTA route through here: a home
  /// currency is required before the first "add expense" attempt that
  /// finds one unset (group totals need a single currency to total into —
  /// see docs/superpowers/specs/2026-08-10-spend-improvements-design.md).
  /// Dismissing the picker cancels the whole add attempt; once set, this
  /// never interrupts again since homeCurrencyProvider is a single
  /// app-wide setting, not per-trip.
  Future<void> _addExpense(
    BuildContext context,
    WidgetRef ref, {
    required String tripId,
    String? defaultCurrency,
  }) async {
    final home = ref.read(homeCurrencyProvider);
    if (home.isEmpty) {
      final chosen = await showCurrencyPicker(context, allowNone: false);
      if (chosen == null) return;
      await ref.read(homeCurrencyProvider.notifier).set(chosen);
    }
    if (!context.mounted) return;
    unawaited(
      showExpenseFormSheet(
        context,
        tripId: tripId,
        defaultCurrency: defaultCurrency,
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    // Resolve everything from ref/context BEFORE the await — the same
    // use-after-dispose class of bug that bit the vault link dialog.
    final repo = ref.read(expenseRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.deleteExpense(expense.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.expenseDeleted)));
  }
}
