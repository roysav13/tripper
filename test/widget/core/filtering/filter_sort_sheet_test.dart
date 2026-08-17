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
import 'package:tripper/core/widgets/filtering/filter_sort_sheet.dart';
import 'package:tripper/l10n/app_localizations.dart';

enum _Field { name }

class _Item {
  const _Item(this.id, {this.category, this.country});
  final String id;
  final String? category;
  final String? country;
}

final _itemsProvider = StateProvider<AsyncValue<List<_Item>>>(
  (ref) => const AsyncValue.data([]),
);

final _controllerFamily = NotifierProvider.family<FilterSortController<_Field>,
    FilterSortState<_Field>, String>(
  () => FilterSortController<_Field>(
    const SortSpec(_Field.name, SortDirection.ascending),
  ),
);

final _config = FilterSortConfig<_Item, _Field>(
  facets: [
    Facet<_Item>(
      id: 'category',
      label: 'Category',
      presentation: FacetPresentation.chips,
      valuesOf: (i) => i.category == null
          ? {}
          : {FacetValue(id: i.category!, label: i.category!)},
    ),
    Facet<_Item>(
      id: 'country',
      label: 'Country',
      presentation: FacetPresentation.checklist,
      searchHint: 'Search countries',
      noResultsLabel: 'No countries match',
      valuesOf: (i) => i.country == null
          ? {}
          : {FacetValue(id: i.country!, label: i.country!)},
    ),
  ],
  sortOptions: [
    SortOption<_Item, _Field>(
      field: _Field.name,
      label: 'Name',
      compare: (a, b) => a.id.compareTo(b.id),
      ascendingLabel: 'A–Z',
      descendingLabel: 'Z–A',
    ),
  ],
  defaultSort: const SortSpec(_Field.name, SortDirection.ascending),
  resultLabel: (count) => 'Show $count items',
);

Future<void> _openSheet(WidgetTester tester, List<_Item> items) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(_itemsProvider.notifier).state = AsyncValue.data(items);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFilterSortSheet<_Item, _Field>(
                context,
                itemsProvider: _itemsProvider,
                controllerFamily: _controllerFamily,
                scope: 'scope-a',
                config: _config,
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
  testWidgets('renders a chip facet, a checklist facet, and the sort section',
      (tester) async {
    await _openSheet(tester, [
      const _Item('a', category: 'Hotel', country: 'Japan'),
      const _Item('b', category: 'Restaurant', country: 'Thailand'),
    ]);

    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('Restaurant'), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('Thailand'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
  });

  testWidgets('tapping a chip facet value applies live and updates the count',
      (tester) async {
    await _openSheet(tester, [
      const _Item('a', category: 'Hotel'),
      const _Item('b', category: 'Restaurant'),
    ]);

    expect(find.text('Show 2 items'), findsOneWidget);
    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Show 1 items'), findsOneWidget);
  });

  testWidgets('Clear is disabled until a filter is selected', (tester) async {
    await _openSheet(tester, [const _Item('a', category: 'Hotel')]);

    final clearButton = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Clear filters'));
    expect(clearButton.onPressed, isNull);

    await tester.tap(find.text('Hotel'));
    await tester.pumpAndSettle();

    final afterButton = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Clear filters'));
    expect(afterButton.onPressed, isNotNull);
  });

  testWidgets('the sheet updates live when its items provider changes',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(_itemsProvider.notifier).state =
        const AsyncValue.data([_Item('a', category: 'Hotel')]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showFilterSortSheet<_Item, _Field>(
                  context,
                  itemsProvider: _itemsProvider,
                  controllerFamily: _controllerFamily,
                  scope: 'scope-a',
                  config: _config,
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
    expect(find.text('Hotel'), findsOneWidget);

    container.read(_itemsProvider.notifier).state =
        const AsyncValue.data([_Item('b', category: 'Restaurant')]);
    await tester.pumpAndSettle();

    expect(find.text('Hotel'), findsNothing);
    expect(find.text('Restaurant'), findsOneWidget);
  });

  testWidgets('sortSubtitleBuilder renders under the field it targets',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(_itemsProvider.notifier).state =
        const AsyncValue.data([_Item('a', category: 'Hotel')]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showFilterSortSheet<_Item, _Field>(
                  context,
                  itemsProvider: _itemsProvider,
                  controllerFamily: _controllerFamily,
                  scope: 'scope-a',
                  config: _config,
                  sortSubtitleBuilder: (context, ref, field) =>
                      field == _Field.name ? const Text('Fetching…') : null,
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

    expect(find.text('Fetching…'), findsOneWidget);
  });
}
