import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/currencies.dart';

/// Searchable list of the supported currencies. Returns the chosen code,
/// or null if dismissed. [allowNone] adds an "off" entry (settings only:
/// no home currency = conversion disabled), which returns `''`.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  String? selected,
  bool allowNone = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _CurrencyPicker(
      selected: selected,
      allowNone: allowNone,
    ),
  );
}

class _CurrencyPicker extends StatefulWidget {
  const _CurrencyPicker({this.selected, this.allowNone = false});

  final String? selected;
  final bool allowNone;

  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  final _query = TextEditingController();
  var _results = kCurrencies;

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      setState(() => _results = searchCurrencies(_query.text));
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.currencyPickerSearch,
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (widget.allowNone && _query.text.trim().isEmpty)
                  ListTile(
                    title: Text(l10n.settingsHomeCurrencyOff),
                    subtitle: Text(
                      l10n.currencyPickerOffHint,
                      style: TextStyle(fontSize: 12, color: colors.inkMuted),
                    ),
                    trailing: (widget.selected ?? '').isEmpty
                        ? Icon(Icons.check, color: colors.accent, size: 18)
                        : null,
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                for (final currency in _results)
                  ListTile(
                    leading: SizedBox(
                      width: 32,
                      child: Text(
                        currency.symbol,
                        style: AppTextStyles.body.copyWith(
                          color: colors.inkSecondary,
                        ),
                      ),
                    ),
                    title: Text(
                      currency.code,
                      style: AppTextStyles.mono.copyWith(
                        fontSize: AppTypeScale.body,
                        color: colors.inkPrimary,
                      ),
                    ),
                    subtitle: Text(
                      currency.name,
                      style: TextStyle(fontSize: 12, color: colors.inkMuted),
                    ),
                    trailing: currency.code == widget.selected
                        ? Icon(Icons.check, color: colors.accent, size: 18)
                        : null,
                    onTap: () => Navigator.of(context).pop(currency.code),
                  ),
                if (_results.isEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                    child: Text(
                      l10n.currencyPickerNoMatch,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
