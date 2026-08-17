import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/filter_selection.dart';
import 'package:tripper/core/filtering/filter_sort_controller.dart';
import 'package:tripper/core/filtering/sort_spec.dart';

enum _Field { name, date }

void main() {
  const defaultSort = SortSpec(_Field.name, SortDirection.ascending);
  final provider = NotifierProvider.family<FilterSortController<_Field>,
      FilterSortState<_Field>, String>(
    () => FilterSortController<_Field>(defaultSort),
  );

  ProviderContainer container() => ProviderContainer();

  test('build seeds the default sort and an empty selection', () {
    final c = container();
    addTearDown(c.dispose);
    final state = c.read(provider('scope-a'));
    expect(state.selection, FilterSelection.empty);
    expect(state.sort, defaultSort);
  });

  test('toggleValue mutates the selection, not the sort', () {
    final c = container();
    addTearDown(c.dispose);
    c.read(provider('scope-a').notifier).toggleValue('category', 'hotel');
    final state = c.read(provider('scope-a'));
    expect(state.selection.valuesFor('category'), {'hotel'});
    expect(state.sort, defaultSort);
  });

  test('removeValue clears a selected value', () {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(provider('scope-a').notifier);
    notifier.toggleValue('category', 'hotel');
    notifier.removeValue('category', 'hotel');
    expect(c.read(provider('scope-a')).selection.isEmpty, isTrue);
  });

  test('setFacetValues replaces the whole set for a facet', () {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(provider('scope-a').notifier);
    notifier.setFacetValues('category', {'hotel', 'restaurant'});
    expect(
      c.read(provider('scope-a')).selection.valuesFor('category'),
      {'hotel', 'restaurant'},
    );
  });

  test('clearFilters empties the selection but keeps the current sort', () {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(provider('scope-a').notifier);
    notifier.toggleValue('category', 'hotel');
    notifier.selectSortField(_Field.date, SortDirection.descending);
    notifier.clearFilters();
    final state = c.read(provider('scope-a'));
    expect(state.selection.isEmpty, isTrue);
    expect(state.sort, const SortSpec(_Field.date, SortDirection.descending));
  });

  test('selecting a different field resets to that field default direction',
      () {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(provider('scope-a').notifier);
    notifier.selectSortField(_Field.date, SortDirection.descending);
    expect(
      c.read(provider('scope-a')).sort,
      const SortSpec(_Field.date, SortDirection.descending),
    );
  });

  test('selecting the already-selected field flips direction instead', () {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(provider('scope-a').notifier);
    notifier.selectSortField(_Field.date, SortDirection.descending);
    expect(
      c.read(provider('scope-a')).sort.direction,
      SortDirection.descending,
    );
    notifier.selectSortField(_Field.date, SortDirection.descending);
    expect(c.read(provider('scope-a')).sort.direction, SortDirection.ascending);
  });

  test('setSelection is a no-op when the selection is unchanged', () {
    final c = container();
    addTearDown(c.dispose);
    final notifier = c.read(provider('scope-a').notifier);
    notifier.toggleValue('category', 'hotel');
    final before = c.read(provider('scope-a'));
    notifier.setSelection(before.selection);
    expect(identical(c.read(provider('scope-a')), before), isTrue);
  });

  test('two family scopes are independent', () {
    final c = container();
    addTearDown(c.dispose);
    c.read(provider('places').notifier).toggleValue('category', 'hotel');
    expect(
      c.read(provider('places')).selection.valuesFor('category'),
      {'hotel'},
    );
    expect(c.read(provider('trip:1')).selection.isEmpty, isTrue);
  });
}
