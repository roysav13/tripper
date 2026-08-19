import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/expense.dart';
import '../domain/expense_grouping.dart';
import 'currency_picker.dart';
import 'expense_form_sheet.dart';
import 'expense_providers.dart';
import 'expense_widgets.dart';

/// Spend tab inside a trip's detail screen (M5.5, redesigned for long
/// trips: a hero + category filter row above a grouped transaction list,
/// all in one scrollable page — see docs/superpowers/plans for the
/// redesign spec).
class TripExpensesTab extends ConsumerStatefulWidget {
  const TripExpensesTab({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripExpensesTab> createState() => _TripExpensesTabState();
}

class _TripExpensesTabState extends ConsumerState<TripExpensesTab> {
  /// Which groups (keyed by [ExpenseGroup.periodStart]) are expanded.
  /// Seeded, on the first build that has groups, to contain only the
  /// newest group — after that, any key that's new since the previous
  /// build (see [_knownGroups]) is auto-expanded too, on top of whatever
  /// the user has toggled by hand. In-memory only; resets on remount, same
  /// as every other transient UI toggle in this app.
  Set<DateTime> _expandedGroups = {};

  /// Keys seen as of the last build with real data — null until the first
  /// non-empty build. Used to detect newly-appeared group keys (a new
  /// expense on a new day, or a granularity flip changing every group's
  /// key shape) so they auto-expand instead of silently rendering
  /// collapsed. See docs/superpowers/plans/2026-08-10-spend-improvements.md
  /// final-review findings.
  Set<DateTime>? _knownGroups;

  /// Null means "All" — the list's only facet, so a single-select row
  /// (not the full filter-sheet machinery Places/Vault use) is enough.
  ExpenseCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncExpenses = ref.watch(tripExpensesProvider(widget.trip.id));
    final expenses = asyncExpenses.valueOrNull ?? const <Expense>[];
    final summary = ref.watch(tripExpenseSummaryProvider(widget.trip.id));

    if (asyncExpenses.hasError) {
      return ErrorState(
        onRetry: () => ref.invalidate(tripExpensesProvider(widget.trip.id)),
      );
    }

    if (asyncExpenses.hasValue && expenses.isEmpty) {
      return EmptyState(
        icon: Icons.payments_outlined,
        title: l10n.expensesEmptyTitle,
        body: l10n.expensesEmptyBody,
        ctaLabel: l10n.expensesEmptyCta,
        onCta: () => _addExpense(defaultCurrency: summary.mainCurrency),
      );
    }

    final selectedCategory = _selectedCategory;
    final filteredExpenses = selectedCategory == null
        ? expenses
        : [
            for (final e in expenses)
              if (e.category == selectedCategory) e,
          ];
    final groups =
        groupExpenses(widget.trip, filteredExpenses, summary.homeCurrency);
    // Guard against seeding from a transient empty-groups build: the
    // expenses stream is `async*` (see FakeExpenseRepository.watchForTrip),
    // so the very first build can land before it emits, with `expenses`
    // (and thus `groups`) empty even though real data is on the way. Only
    // seed once real groups exist, so the newest group ends up expanded
    // instead of the seed permanently locking onto `{}`.
    //
    // After that first seed, any group key that wasn't present in the
    // previous build's group set is newly-appeared — a new expense landed
    // on a day (or week/month bucket) with no prior group, OR the category
    // filter just changed which groups have any matching expenses — and
    // gets auto-expanded too, rather than silently rendering collapsed.
    final currentKeys = {for (final group in groups) group.periodStart};
    if (_knownGroups == null) {
      if (groups.isNotEmpty) {
        _expandedGroups = {groups.first.periodStart};
        _knownGroups = currentKeys;
      }
    } else {
      _expandedGroups.addAll(currentKeys.difference(_knownGroups!));
      _knownGroups = currentKeys;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.expensesEmptyCta,
        backgroundColor: context.colors.accent,
        foregroundColor: context.colors.surface,
        onPressed: () => _addExpense(defaultCurrency: summary.mainCurrency),
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              end: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: SpendHeroCard(
                headline: summary.headline,
                todayHeadline: summary.todayHeadline,
              ),
            ),
          ),
          // Pinned so the filter stays reachable while a long trip's list
          // scrolls underneath it, instead of disappearing off the top.
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedFilterHeader(
              // Matches the tab's own (transparent) Scaffold, which shows
              // through to the screen's paper background — an opaque
              // backing is what keeps rows from showing through once
              // they've scrolled up underneath this header.
              backgroundColor: context.colors.paper,
              child: ExpenseCategoryFilterRow(
                selected: _selectedCategory,
                onSelect: (category) =>
                    setState(() => _selectedCategory = category),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              end: AppSpacing.lg,
              top: AppSpacing.md,
              bottom: 88,
            ),
            sliver: filteredExpenses.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Text(
                        l10n.expensesFilterEmpty,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body
                            .copyWith(color: context.colors.inkMuted),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildListDelegate([
                      for (final group in groups) ...[
                        ExpenseGroupHeader(
                          group: group,
                          expanded: _expandedGroups.contains(group.periodStart),
                          onTap: () => setState(() {
                            final isExpanded =
                                _expandedGroups.contains(group.periodStart);
                            if (isExpanded) {
                              _expandedGroups.remove(group.periodStart);
                            } else {
                              _expandedGroups.add(group.periodStart);
                            }
                          }),
                        ),
                        if (_expandedGroups.contains(group.periodStart))
                          for (final expense in group.expenses)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: ExpenseRowCard(
                                expense: expense,
                                onTap: () => showExpenseFormSheet(
                                  context,
                                  tripId: widget.trip.id,
                                  existing: expense,
                                  defaultCurrency: summary.mainCurrency,
                                ),
                                onDelete: () => _delete(expense),
                              ),
                            ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense({String? defaultCurrency}) async {
    final home = ref.read(homeCurrencyProvider);
    if (home.isEmpty) {
      final chosen = await showCurrencyPicker(context, allowNone: false);
      if (chosen == null) return;
      await ref.read(homeCurrencyProvider.notifier).set(chosen);
    }
    if (!mounted) return;
    // unawaited: fire-and-forget sheet presentation, matching the
    // convention already established in expense_providers.dart — the lint
    // (unawaited_futures) otherwise flags this call.
    unawaited(
      showExpenseFormSheet(
        context,
        tripId: widget.trip.id,
        defaultCurrency: defaultCurrency,
      ),
    );
  }

  Future<void> _delete(Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteExpenseTitle),
        content: Text(l10n.deleteExpenseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.menuDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Resolve everything from ref/context BEFORE the next await — the same
    // use-after-dispose class of bug that bit the vault link dialog.
    final repo = ref.read(expenseRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.deleteExpense(expense.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.expenseDeleted)));
  }
}

/// Pins [ExpenseCategoryFilterRow] to the top of the scroll view once the
/// hero card has scrolled past, with an opaque backing so rows scrolling
/// underneath don't show through it.
class _PinnedFilterHeader extends SliverPersistentHeaderDelegate {
  const _PinnedFilterHeader({
    required this.child,
    required this.backgroundColor,
  });

  final Widget child;
  final Color backgroundColor;

  static const _verticalPadding = AppSpacing.sm;
  static const _extent = ExpenseCategoryFilterRow.height + _verticalPadding * 2;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: _verticalPadding,
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedFilterHeader oldDelegate) =>
      child != oldDelegate.child ||
      backgroundColor != oldDelegate.backgroundColor;
}
