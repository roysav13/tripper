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
import 'package:tripper/core/widgets/filtering/filter_sort_view.dart';
import 'package:tripper/l10n/app_localizations.dart';

enum _Field { name }

class _Item {
  const _Item(this.id, {this.category});
  final String id;
  final String? category;
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
  resultLabel: (count) => 'Show $count',
);

void main() {
  Widget app(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FilterSortView<_Item, _Field>(
              itemsProvider: _itemsProvider,
              controllerFamily: _controllerFamily,
              scope: 'scope-a',
              config: _config,
              builder: (context, all, visible, state) => Column(
                children: [for (final item in visible) Text(item.id)],
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
      );

  testWidgets('builder receives filtered and sorted items', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(_itemsProvider.notifier).state = const AsyncValue.data([
      _Item('b', category: 'hotel'),
      _Item('a', category: 'hotel'),
      _Item('c', category: 'other'),
    ]);
    container
        .read(_controllerFamily('scope-a').notifier)
        .toggleValue('category', 'hotel');

    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle();

    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsNothing);
    // sorted ascending by id
    final aOffset = tester.getTopLeft(find.text('a')).dy;
    final bOffset = tester.getTopLeft(find.text('b')).dy;
    expect(aOffset, lessThan(bOffset));
  });

  testWidgets(
      'a stale selection is pruned automatically after the frame settles',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(_itemsProvider.notifier).state = const AsyncValue.data([
      _Item('a', category: 'hotel'),
    ]);
    container
        .read(_controllerFamily('scope-a').notifier)
        .toggleValue('category', 'hotel');

    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);

    // The only hotel item is edited away — the stale selection must be
    // pruned so the item reappears instead of the list staying empty.
    container.read(_itemsProvider.notifier).state = const AsyncValue.data([
      _Item('a', category: 'other'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('a'), findsOneWidget);
    expect(
      container.read(_controllerFamily('scope-a')).selection.isEmpty,
      isTrue,
    );
  });
}
