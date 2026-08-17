import '../../../core/filtering/facet.dart';
import '../../../core/filtering/filter_sort_config.dart';
import '../../../core/filtering/sort_option.dart';
import '../../../core/filtering/sort_spec.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/document.dart';
import '../domain/document_sort.dart';
import 'document_widgets.dart';

/// The Vault feature's config for the generic filter+sort core: a single
/// category facet (chips — 7 fixed values), and the created/relevant-date
/// sort options.
FilterSortConfig<Document, DocumentSortField> buildDocumentFilterSortConfig(
  AppLocalizations l10n,
) {
  return FilterSortConfig<Document, DocumentSortField>(
    facets: [
      Facet<Document>(
        id: 'category',
        label: l10n.vaultFilterCategorySection,
        presentation: FacetPresentation.chips,
        iconOf: (id) => categoryIcon(DocumentCategory.values.byName(id)),
        valuesOf: (doc) => {
          FacetValue(
            id: doc.category.name,
            label: categoryLabel(l10n, doc.category),
            sortKey: doc.category.index.toString().padLeft(3, '0'),
          ),
        },
      ),
    ],
    sortOptions: [
      SortOption<Document, DocumentSortField>(
        field: DocumentSortField.createdDate,
        label: l10n.vaultSortCreated,
        compare: compareDocumentsByCreatedDate,
        ascendingLabel: l10n.sortOldestFirst,
        descendingLabel: l10n.sortNewestFirst,
        defaultDirection: SortDirection.descending,
      ),
      SortOption<Document, DocumentSortField>(
        field: DocumentSortField.relevantDate,
        label: l10n.vaultSortRelevant,
        hasValue: (doc) => relevantDateOf(doc) != null,
        compare: compareDocumentsByRelevantDate,
        ascendingLabel: l10n.sortOldestFirst,
        descendingLabel: l10n.sortNewestFirst,
      ),
    ],
    defaultSort: const SortSpec(
      DocumentSortField.createdDate,
      SortDirection.descending,
    ),
    resultLabel: l10n.vaultFilterShowResults,
  );
}
