import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/pill_chip.dart';
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

String _formatAmount(int amountMinor, String currency) =>
    '${formatMinor(amountMinor, digits: minorDigitsFor(currency))} $currency';

/// One line per currency, joined — the fallback view whenever a set of
/// expenses can't collapse into one honest figure (mixed currencies, no
/// home currency set). Shared by the hero card and each group header so
/// they degrade the same way.
String joinCurrencyAmounts(List<CurrencyAmount> amounts) =>
    amounts.map((a) => _formatAmount(a.amountMinor, a.currency)).join(' · ');

/// The Spend tab's hero: the trip-wide total, today's spend, and a
/// running transaction count — the figures a long trip needs visible at
/// all times to stay oriented, as opposed to the per-category breakdown
/// (available on request, via the filter row below this card). A solid
/// [PaperCard]-style surface that follows the active theme like every
/// other card — light in light mode, dark in dark mode.
class SpendHeroCard extends StatelessWidget {
  const SpendHeroCard({
    super.key,
    required this.headline,
    required this.todayHeadline,
  });

  final HeadlineTotal headline;
  final HeadlineTotal todayHeadline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return PaperCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.expensesTotal, color: colors.inkMuted),
          const SizedBox(height: AppSpacing.xs),
          _HeadlineFigure(headline: headline, colors: colors, l10n: l10n),
          const SizedBox(height: AppSpacing.sm),
          SectionLabel(l10n.expensesTodayLabel, color: colors.inkMuted),
          const SizedBox(height: 2),
          _TodayFigure(headline: todayHeadline, colors: colors),
        ],
      ),
    );
  }
}

class _HeadlineFigure extends StatelessWidget {
  const _HeadlineFigure({
    required this.headline,
    required this.colors,
    required this.l10n,
  });

  final HeadlineTotal headline;
  final AppColors colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final amountMinor = headline.amountMinor;
    final currency = headline.currency;
    if (amountMinor == null || currency == null) {
      // Mixed currencies, conversion off: stack each currency's own total
      // — the honest answer instead of a fabricated single figure (v1 has
      // no conversion rates without a home currency set).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final total in headline.perCurrency)
            Text(
              _formatAmount(total.amountMinor, total.currency),
              style: AppTextStyles.mono.copyWith(
                fontSize: AppTypeScale.title,
                fontWeight: FontWeight.w500,
                color: colors.inkPrimary,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.expensesConversionOffHint,
            style: AppTextStyles.mono.copyWith(color: colors.inkMuted),
          ),
        ],
      );
    }
    // One combined string, not split spans — "≈" has to stay glued to the
    // figure it qualifies, and every other total in this feature (row,
    // group header) is one string too, so the hero reads the same way.
    final amountText =
        '${headline.isHomeConversion ? '≈ ' : ''}${_formatAmount(amountMinor, currency)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          amountText,
          style: AppTextStyles.mono.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: colors.inkPrimary,
          ),
        ),
        if (headline.pendingCount > 0)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
            child: Text(
              l10n.expensesConversionPending(headline.pendingCount),
              style: AppTextStyles.mono.copyWith(color: colors.inkMuted),
            ),
          ),
      ],
    );
  }
}

class _TodayFigure extends StatelessWidget {
  const _TodayFigure({required this.headline, required this.colors});

  final HeadlineTotal headline;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final amountMinor = headline.amountMinor;
    final currency = headline.currency;
    final String text;
    if (amountMinor != null && currency != null) {
      text =
          '${headline.isHomeConversion ? '≈ ' : ''}${_formatAmount(amountMinor, currency)}';
    } else if (headline.perCurrency.isNotEmpty) {
      text = joinCurrencyAmounts(headline.perCurrency);
    } else {
      text = l10n.expensesNoSpendToday;
    }
    return Text(
      text,
      style: AppTextStyles.mono.copyWith(
        fontSize: AppTypeScale.body,
        fontWeight: FontWeight.w500,
        color: colors.inkPrimary,
      ),
    );
  }
}

/// Single-select category filter for the Spend tab's list, plus an "All"
/// entry. Same [PillChip] language as the Places and Vault filter sheets
/// use for their own facet values — one chip control across the app.
class ExpenseCategoryFilterRow extends StatelessWidget {
  const ExpenseCategoryFilterRow({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final ExpenseCategory? selected;
  final ValueChanged<ExpenseCategory?> onSelect;

  /// Fixed so a pinned sliver header (see [TripExpensesTab]) can reserve
  /// an exact extent for this row.
  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            PillChip(
              label: l10n.expensesFilterAll,
              selected: selected == null,
              onTap: () => onSelect(null),
            ),
            for (final category in ExpenseCategory.values) ...[
              const SizedBox(width: AppSpacing.sm),
              PillChip(
                label: expenseCategoryLabel(l10n, category),
                icon: expenseCategoryIcon(category),
                selected: selected == category,
                onTap: () => onSelect(selected == category ? null : category),
              ),
            ],
          ],
        ),
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
      DateFormat('dd MMM yyyy', l10n.localeName).format(expense.date),
    ].join(' · ');

    return PaperCard(
      onTap: onTap,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent.withValues(alpha: 0.12),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
              child: Icon(
                expenseCategoryIcon(expense.category),
                size: 18,
                color: colors.accent,
              ),
            ),
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
                _formatAmount(expense.amountMinor, expense.currency),
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
                  '≈ ${_formatAmount(expense.convertedAmountMinor!, expense.convertedCurrency!)}',
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
          DateFormat('EEE, MMM d', l10n.localeName).format(group.periodStart),
        ExpenseGroupGranularity.week => l10n.expenseGroupWeekOf(
            DateFormat('MMM d', l10n.localeName).format(group.periodStart),
          ),
        ExpenseGroupGranularity.month =>
          DateFormat('MMMM yyyy', l10n.localeName).format(group.periodStart),
      };

  String _totalText(ExpenseGroup group) {
    final home = group.homeCurrencyTotal;
    if (home != null) {
      return '≈ ${_formatAmount(home.amountMinor, group.homeCurrency)}';
    }
    return joinCurrencyAmounts(group.perCurrencyTotals);
  }
}
