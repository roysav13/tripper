import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/sort_option.dart';
import 'package:tripper/core/filtering/sort_spec.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/filtering/sort_field_list.dart';
import 'package:tripper/l10n/app_localizations.dart';

enum _Field { name, date, recommended }

class _Item {
  const _Item(this.id);
  final String id;
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

void main() {
  final options = [
    SortOption<_Item, _Field>(
      field: _Field.recommended,
      label: 'Recommended',
      compare: (a, b) => 0,
      ascendingLabel: 'Recommended',
      descendingLabel: 'Recommended',
      directional: false,
    ),
    SortOption<_Item, _Field>(
      field: _Field.name,
      label: 'Name',
      compare: (a, b) => a.id.compareTo(b.id),
      ascendingLabel: 'A–Z',
      descendingLabel: 'Z–A',
    ),
    SortOption<_Item, _Field>(
      field: _Field.date,
      label: 'Date visited',
      compare: (a, b) => a.id.compareTo(b.id),
      ascendingLabel: 'Oldest first',
      descendingLabel: 'Newest first',
    ),
  ];

  testWidgets('renders every option label', (tester) async {
    await tester.pumpWidget(
      _app(
        SortFieldList<_Item, _Field>(
          options: options,
          current: const SortSpec(_Field.recommended, SortDirection.ascending),
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Date visited'), findsOneWidget);
  });

  testWidgets(
      'the selected directional field shows its direction label and an arrow',
      (tester) async {
    await tester.pumpWidget(
      _app(
        SortFieldList<_Item, _Field>(
          options: options,
          current: const SortSpec(_Field.date, SortDirection.descending),
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.text('NEWEST FIRST'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
  });

  testWidgets('a selected non-directional field shows no arrow',
      (tester) async {
    await tester.pumpWidget(
      _app(
        SortFieldList<_Item, _Field>(
          options: options,
          current: const SortSpec(_Field.recommended, SortDirection.ascending),
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });

  testWidgets('tapping any row calls onSelect with that row\'s field',
      (tester) async {
    _Field? selected;
    await tester.pumpWidget(
      _app(
        SortFieldList<_Item, _Field>(
          options: options,
          current: const SortSpec(_Field.recommended, SortDirection.ascending),
          onSelect: (field) => selected = field,
        ),
      ),
    );
    await tester.tap(find.text('Date visited'));
    expect(selected, _Field.date);
  });

  testWidgets(
      'subtitleOf renders under the field it targets, and nothing '
      'for fields it returns null for', (tester) async {
    await tester.pumpWidget(
      _app(
        SortFieldList<_Item, _Field>(
          options: options,
          current: const SortSpec(_Field.recommended, SortDirection.ascending),
          onSelect: (_) {},
          subtitleOf: (field) =>
              field == _Field.date ? const Text('Fetching…') : null,
        ),
      ),
    );
    expect(find.text('Fetching…'), findsOneWidget);
  });
}
