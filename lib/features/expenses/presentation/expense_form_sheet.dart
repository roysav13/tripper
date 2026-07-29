import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/currencies.dart';
import '../domain/expense.dart';
import 'currency_picker.dart';
import 'expense_providers.dart';
import 'expense_widgets.dart';

/// Add or edit an expense. [existing] switches it to edit mode;
/// [defaultCurrency] is the trip's currency once it has one (v1 is
/// single-currency per trip), so only the first expense has to pick.
Future<void> showExpenseFormSheet(
  BuildContext context, {
  required String tripId,
  Expense? existing,
  String? defaultCurrency,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ExpenseForm(
        tripId: tripId,
        existing: existing,
        defaultCurrency: defaultCurrency,
      ),
    ),
  );
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({
    required this.tripId,
    this.existing,
    this.defaultCurrency,
  });

  final String tripId;
  final Expense? existing;
  final String? defaultCurrency;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  /// Always a code from [kCurrencies] — chosen from the picker, never
  /// typed, so an unconvertible typo can't reach the database.
  late String _currency;
  late ExpenseCategory _category;
  late DateTime _date;
  bool _amountError = false;
  bool _currencyError = false;
  bool _saving = false;

  int get _digits => minorDigitsFor(_currency);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _currency = existing?.currency ?? widget.defaultCurrency ?? '';
    _amount = TextEditingController(
      text: existing == null
          ? ''
          : formatMinor(existing.amountMinor, digits: _digits),
    );
    _notes = TextEditingController(text: existing?.notes ?? '');
    _category = existing?.category ?? ExpenseCategory.food;
    _date = existing?.date ?? ref.read(clockProvider)();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickCurrency() async {
    final picked = await showCurrencyPicker(
      context,
      selected: _currency.isEmpty ? null : _currency,
    );
    if (picked == null || picked.isEmpty) return;
    setState(() {
      _currency = picked;
      _currencyError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Text(
          widget.existing == null
              ? l10n.expenseFormTitle
              : l10n.expenseFormEditTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _amount,
                autofocus: widget.existing == null,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.expenseFormAmount,
                  errorText: _amountError ? l10n.errAmountRequired : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.expenseFormCurrency,
                  errorText: _currencyError ? l10n.errCurrencyRequired : null,
                ),
                child: InkWell(
                  onTap: _pickCurrency,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currency.isEmpty ? '—' : _currency,
                        style: AppTextStyles.mono.copyWith(
                          fontSize: AppTypeScale.body,
                          color: _currency.isEmpty
                              ? context.colors.inkMuted
                              : context.colors.inkPrimary,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: context.colors.inkSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in ExpenseCategory.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: ChoiceChip(
                    avatar: Icon(expenseCategoryIcon(c), size: 16),
                    label: Text(expenseCategoryLabel(l10n, c)),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          icon: const Icon(Icons.event_outlined, size: 16),
          label: Text(DateFormat('dd MMM yyyy').format(_date)),
          onPressed: _pickDate,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _notes,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.expenseFormNotes),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final currency = _currency;
    // Validating against the catalogue (not a regex) is the point of the
    // picker: only a code the rate lookup can actually use gets stored.
    final currencyValid = isSupportedCurrency(currency);
    final amountMinor = currencyValid
        ? parseAmountToMinor(_amount.text, digits: minorDigitsFor(currency))
        : null;
    setState(() {
      _amountError = currencyValid && amountMinor == null;
      _currencyError = !currencyValid;
    });
    if (amountMinor == null || !currencyValid) return;

    setState(() => _saving = true);
    final repo = ref.read(expenseRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      await repo.createExpense(
        tripId: widget.tripId,
        amountMinor: amountMinor,
        currency: currency,
        category: _category,
        date: _date,
        notes: _notes.text,
      );
    } else {
      await repo.updateExpense(
        existing.copyWith(
          amountMinor: amountMinor,
          currency: currency,
          category: _category,
          date: _date,
          notes: _notes.text,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
