import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/currencies.dart';
import '../domain/expense.dart';
import '../domain/expense_grouping.dart';

IconData expenseCategoryIcon(ExpenseCategory category) => switch (category) {
      ExpenseCategory.transport => Icons.directions_bus_outlined,
      ExpenseCategory.stay => Icons.hotel_outlined,
      ExpenseCategory.food => Icons.restaurant_outlined,
      ExpenseCategory.activities => Icons.local_activity_outlined,
      ExpenseCategory.shopping => Icons.shopping_bag_outlined,
      ExpenseCategory.other => Icons.receipt_long_outlined,
    };

String expenseCategoryLabel(AppLocalizations l10n, ExpenseCategory category) =>
    switch (category) {
      // Reuses the vault's category strings where they're the same word —
      // one translation to maintain, not two.
      ExpenseCategory.transport => l10n.catTransport,
      ExpenseCategory.stay => l10n.catStay,
      ExpenseCategory.food => l10n.catFood,
      ExpenseCategory.activities => l10n.catActivities,
      ExpenseCategory.shopping => l10n.catShopping,
      ExpenseCategory.other => l10n.catOther,
    };

/// Running totals + per-category breakdown. Numerals are mono per the
/// design system's "data reads authoritative" rule.
///
/// Totals are listed **per currency** — a mixed-currency trip shows one
/// line each rather than a single meaningless sum (no conversion rates
/// in v1, and inventing one would be worse than showing both).
class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({
    super.key,
    required this.totals,
    required this.breakdown,
    this.home,
    this.homeCurrency = '',
    this.showConversionOffHint = false,
  });

  final List<CurrencyAmount> totals;
  final List<CategoryTotals> breakdown;

  /// Combined home-currency figure for mixed-currency trips; null when
  /// conversion is off or the trip uses one currency anyway.
  final HomeTotal? home;
  final String homeCurrency;

  /// True when this trip mixes currencies but no home currency is set —
  /// without this the feature is invisible and the absence of a combined
  /// total looks like a bug rather than an unset preference.
  final bool showConversionOffHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                l10n.expensesTotal,
                style: AppTextStyles.sectionLabel.copyWith(
                  color: colors.inkSecondary,
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final total in totals)
                      Text(
                        '${formatMinor(total.amountMinor, digits: minorDigitsFor(total.currency))} ${total.currency}',
                        style: AppTextStyles.mono.copyWith(
                          fontSize: AppTypeScale.title,
                          color: colors.inkPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (home != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // "≈" is doing real work: this figure depends on a rate
                  // fetched at some past moment, so it must never look as
                  // exact as the per-currency lines above it.
                  Text(
                    l10n.expensesConvertedTotal(
                      formatMinor(
                        home!.amountMinor,
                        digits: minorDigitsFor(homeCurrency),
                      ),
                      homeCurrency,
                    ),
                    style: AppTextStyles.mono.copyWith(
                      color: colors.inkSecondary,
                    ),
                  ),
                  if (home!.pendingCount > 0)
                    Text(
                      l10n.expensesConversionPending(home!.pendingCount),
                      style: AppTextStyles.mono.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  if (home!.ratesAt != null)
                    Text(
                      l10n.expensesRatesAsOf(
                        DateFormat('dd MMM yyyy', 'en_US').format(home!.ratesAt!),
                      ),
                      style: AppTextStyles.mono.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (showConversionOffHint) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                l10n.expensesConversionOffHint,
                textAlign: TextAlign.end,
                style: AppTextStyles.mono.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final row in breakdown)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Icon(
                        expenseCategoryIcon(row.category),
                        size: 14,
                        color: colors.inkSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        expenseCategoryLabel(l10n, row.category),
                        style: AppTextStyles.body.copyWith(
                          color: colors.inkSecondary,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final amount in row.amounts)
                          MonoText(
                            // Single-currency trips keep the bare number;
                            // mixed ones need the code to disambiguate.
                            totals.length > 1
                                ? '${formatMinor(amount.amountMinor, digits: minorDigitsFor(amount.currency))} '
                                    '${amount.currency}'
                                : formatMinor(
                                    amount.amountMinor,
                                    digits: minorDigitsFor(amount.currency),
                                  ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class ExpenseRowCard extends StatelessWidget {
  const ExpenseRowCard({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final meta = [
      expenseCategoryLabel(l10n, expense.category),
      DateFormat('dd MMM yyyy', 'en_US').format(expense.date),
    ].join(' · ');

    return PaperCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            expenseCategoryIcon(expense.category),
            size: 20,
            color: colors.inkSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.notes.trim().isEmpty
                      ? expenseCategoryLabel(l10n, expense.category)
                      : expense.notes,
                  style: AppTextStyles.body.copyWith(
                    color: colors.inkPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                MonoText(meta),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                // Always shows the code: a trip can mix currencies, and
                // a bare number would be ambiguous on exactly the rows
                // where it matters most.
                '${formatMinor(expense.amountMinor, digits: minorDigitsFor(expense.currency))} '
                '${expense.currency}',
                style: AppTextStyles.mono.copyWith(
                  fontSize: AppTypeScale.body,
                  color: colors.inkPrimary,
                ),
              ),
              // The stored conversion, when this row has one and it says
              // something the line above doesn't. Absent (not "0.00", not
              // a spinner) while awaiting a connection — an empty slot
              // reads as "pending", a zero reads as a fact.
              if (expense.isConverted &&
                  expense.convertedCurrency != expense.currency)
                MonoText(
                  '≈ ${formatMinor(expense.convertedAmountMinor!, digits: minorDigitsFor(expense.convertedCurrency!))} '
                  '${expense.convertedCurrency}',
                  muted: true,
                ),
            ],
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: colors.inkMuted,
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// A collapsible group's header: the period's label, its total (home
/// currency when the group mixes currencies and one is set, otherwise one
/// line per currency — see [ExpenseGroup.homeCurrencyTotal]), and an
/// expand/collapse chevron. Tapping anywhere on the header toggles
/// [expanded].
class ExpenseGroupHeader extends StatelessWidget {
  const ExpenseGroupHeader({
    super.key,
    required this.group,
    required this.expanded,
    required this.onTap,
  });

  final ExpenseGroup group;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final pending = group.homeCurrencyTotal?.pendingCount ?? 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(_label(l10n, group))),
                MonoText(_totalText(group)),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colors.inkMuted,
                ),
              ],
            ),
            if (pending > 0)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: MonoText(
                  l10n.expensesConversionPending(pending),
                  muted: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n, ExpenseGroup group) =>
      switch (group.granularity) {
        ExpenseGroupGranularity.day =>
          DateFormat('EEE, MMM d', 'en_US').format(group.periodStart),
        ExpenseGroupGranularity.week => l10n.expenseGroupWeekOf(
            DateFormat('MMM d', 'en_US').format(group.periodStart),
          ),
        ExpenseGroupGranularity.month =>
          DateFormat('MMMM yyyy', 'en_US').format(group.periodStart),
      };

  String _totalText(ExpenseGroup group) {
    final home = group.homeCurrencyTotal;
    if (home != null) {
      return '≈ ${formatMinor(home.amountMinor, digits: minorDigitsFor(group.homeCurrency))} '
          '${group.homeCurrency}';
    }
    return group.perCurrencyTotals
        .map(
          (t) =>
              '${formatMinor(t.amountMinor, digits: minorDigitsFor(t.currency))} ${t.currency}',
        )
        .join(' · ');
  }
}
