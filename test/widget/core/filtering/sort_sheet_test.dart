import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/facet.dart';
import 'package:tripper/core/filtering/filter_sort_config.dart';
import 'package:tripper/core/filtering/filter_sort_controller.dart';
import 'package:tripper/core/filtering/sort_option.dart';
import 'package:tripper/core/filtering/sort_spec.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/filtering/sort_sheet.dart';
import 'package:tripper/l10n/app_localizations.dart';

enum _Field { name, date }

class _Item {
  const _Item(this.id);
  final String id;
}

final _controllerFamily = NotifierProvider.family<FilterSortController<_Field>,
    FilterSortState<_Field>, String>(
  () => FilterSortController<_Field>(
    const SortSpec(_Field.name, SortDirection.ascending),
  ),
);

final _config = FilterSortConfig<_Item, _Field>(
  facets: const <Facet<_Item>>[],
  sortOptions: [
    SortOption<_Item, _Field>(
      field: _Field.name,
      label: 'Name',
      compare: (a, b) => a.id.compareTo(b.id),
      ascendingLabel: 'A–Z',
      descendingLabel: 'Z–A',
    ),
    SortOption<_Item, _Field>(
      field: _Field.date,
      label: 'Date',
      compare: (a, b) => a.id.compareTo(b.id),
      ascendingLabel: 'Oldest first',
      descendingLabel: 'Newest first',
    ),
  ],
  defaultSort: const SortSpec(_Field.name, SortDirection.ascending),
  resultLabel: (count) => 'Show $count items',
);

Future<void> _openSheet(
  WidgetTester tester, {
  Widget? Function(BuildContext context, WidgetRef ref, _Field field)?
      sortSubtitleBuilder,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSortSheet<_Item, _Field>(
                context,
                controllerFamily: _controllerFamily,
                scope: 'scope-a',
                config: _config,
                sortSubtitleBuilder: sortSubtitleBuilder,
              ),
              child: const Text('open'),
            ),
          ),
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the sort options', (tester) async {
    await _openSheet(tester);

    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
  });

  testWidgets('the close button dismisses the sheet', (tester) async {
    await _openSheet(tester);
    expect(find.text('Sort by'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Sort by'), findsNothing);
  });

  testWidgets('sortSubtitleBuilder renders under the field it targets',
      (tester) async {
    await _openSheet(
      tester,
      sortSubtitleBuilder: (context, ref, field) =>
          field == _Field.name ? const Text('Fetching…') : null,
    );

    expect(find.text('Fetching…'), findsOneWidget);
  });
}
