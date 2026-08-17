import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/filter_engine.dart';
import 'package:tripper/core/filtering/filter_selection.dart';
import 'package:tripper/core/filtering/sort_option.dart';
import 'package:tripper/core/filtering/sort_spec.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/domain/document_sort.dart';
import 'package:tripper/features/vault/presentation/document_filter_config.dart';
import 'package:tripper/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final config = buildDocumentFilterSortConfig(l10n);

  Document doc(
    String id, {
    DocumentCategory category = DocumentCategory.other,
    DateTime? createdAt,
    DateTime? expiry,
  }) =>
      Document(
        id: id,
        title: id,
        category: category,
        createdAt: createdAt ?? DateTime(2026, 1, 1),
        expiryDate: expiry,
      );

  group('category facet, via applyFilter (ported filterDocumentsByCategory)',
      () {
    final docs = [
      doc('a', category: DocumentCategory.passportId),
      doc('b', category: DocumentCategory.flight),
      doc('c', category: DocumentCategory.stay),
    ];

    test('no filters returns everything', () {
      expect(
        applyFilter(docs, config.facets, FilterSelection.empty),
        hasLength(3),
      );
    });

    test('category facet is OR within the set', () {
      final selection = FilterSelection.empty
          .toggle('category', DocumentCategory.passportId.name)
          .toggle('category', DocumentCategory.stay.name);
      final result = applyFilter(docs, config.facets, selection);
      expect(result.map((d) => d.id), ['a', 'c']);
    });
  });

  group('sort options', () {
    test('createdDate defaults to newest first (descending)', () {
      final docs = [
        doc('old', createdAt: DateTime(2026, 1, 1)),
        doc('new', createdAt: DateTime(2026, 6, 1)),
        doc('mid', createdAt: DateTime(2026, 3, 1)),
      ];
      final sorted = applySort(
        docs,
        const SortSpec(DocumentSortField.createdDate, SortDirection.descending),
        config.sortOptions,
      );
      expect(sorted.map((d) => d.id), ['new', 'mid', 'old']);
    });

    test('relevantDate pushes documents without a relevant date last', () {
      final docs = [
        doc('no-date'),
        doc('dated', expiry: DateTime(2026, 9, 1)),
      ];
      final sorted = applySort(
        docs,
        const SortSpec(DocumentSortField.relevantDate, SortDirection.ascending),
        config.sortOptions,
      );
      expect(sorted.map((d) => d.id), ['dated', 'no-date']);
    });
  });

  test('resultLabel matches the existing pluralized ARB string', () {
    expect(config.resultLabel(1), l10n.vaultFilterShowResults(1));
    expect(config.resultLabel(3), l10n.vaultFilterShowResults(3));
  });
}
