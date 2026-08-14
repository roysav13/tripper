import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/domain/document_sort.dart';

Document _doc(
  String id, {
  DocumentCategory category = DocumentCategory.other,
  required DateTime createdAt,
  DateTime? expiry,
  DateTime? departure,
}) =>
    Document(
      id: id,
      title: id,
      category: category,
      createdAt: createdAt,
      expiryDate: expiry,
      details: departure == null
          ? const {}
          : {'departureTime': departure.toIso8601String()},
    );

void main() {
  group('relevantDateOf', () {
    test('uses expiryDate when set', () {
      final doc = _doc(
        'a',
        createdAt: DateTime(2026, 1, 1),
        expiry: DateTime(2026, 12, 1),
      );
      expect(relevantDateOf(doc), DateTime(2026, 12, 1));
    });

    test('falls back to a flight\'s departure time when there\'s no expiry',
        () {
      final doc = _doc(
        'a',
        category: DocumentCategory.flight,
        createdAt: DateTime(2026, 1, 1),
        departure: DateTime(2026, 8, 16, 14, 30),
      );
      expect(relevantDateOf(doc), DateTime(2026, 8, 16, 14, 30));
    });

    test('expiry wins over departure when a flight document has both', () {
      final doc = _doc(
        'a',
        category: DocumentCategory.flight,
        createdAt: DateTime(2026, 1, 1),
        expiry: DateTime(2026, 12, 1),
        departure: DateTime(2026, 8, 16, 14, 30),
      );
      expect(relevantDateOf(doc), DateTime(2026, 12, 1));
    });

    test('a non-flight document with no expiry has no relevant date', () {
      final doc = _doc('a', createdAt: DateTime(2026, 1, 1));
      expect(relevantDateOf(doc), isNull);
    });

    test('an unparsable departure string is treated as absent', () {
      final doc = Document(
        id: 'a',
        title: 'a',
        category: DocumentCategory.flight,
        createdAt: DateTime(2026, 1, 1),
        details: const {'departureTime': 'not-a-date'},
      );
      expect(relevantDateOf(doc), isNull);
    });
  });

  group('sortDocuments', () {
    test('createdDate orders newest first', () {
      final sorted = sortDocuments(
        [
          _doc('old', createdAt: DateTime(2026, 1, 1)),
          _doc('new', createdAt: DateTime(2026, 6, 1)),
          _doc('mid', createdAt: DateTime(2026, 3, 1)),
        ],
        DocumentSortOrder.createdDate,
      );
      expect(sorted.map((d) => d.id).toList(), ['new', 'mid', 'old']);
    });

    test('relevantDate orders soonest first', () {
      final sorted = sortDocuments(
        [
          _doc(
            'far',
            createdAt: DateTime(2026, 1, 1),
            expiry: DateTime(2027, 1, 1),
          ),
          _doc(
            'soon',
            createdAt: DateTime(2026, 1, 1),
            expiry: DateTime(2026, 8, 1),
          ),
          _doc(
            'mid',
            createdAt: DateTime(2026, 1, 1),
            expiry: DateTime(2026, 10, 1),
          ),
        ],
        DocumentSortOrder.relevantDate,
      );
      expect(sorted.map((d) => d.id).toList(), ['soon', 'mid', 'far']);
    });

    test(
        'relevantDate pushes dateless documents last, tiebroken by '
        'createdAt (newest first)', () {
      final sorted = sortDocuments(
        [
          _doc('dateless-old', createdAt: DateTime(2026, 1, 1)),
          _doc(
            'dated',
            createdAt: DateTime(2026, 1, 1),
            expiry: DateTime(2026, 9, 1),
          ),
          _doc('dateless-new', createdAt: DateTime(2026, 6, 1)),
        ],
        DocumentSortOrder.relevantDate,
      );
      expect(
        sorted.map((d) => d.id).toList(),
        ['dated', 'dateless-new', 'dateless-old'],
      );
    });
  });

  group('filterDocumentsByCategory', () {
    final docs = [
      _doc(
        'a',
        category: DocumentCategory.passportId,
        createdAt: DateTime(2026, 1, 1),
      ),
      _doc(
        'b',
        category: DocumentCategory.flight,
        createdAt: DateTime(2026, 1, 1),
      ),
      _doc(
        'c',
        category: DocumentCategory.stay,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    test('empty category set means no filtering', () {
      expect(filterDocumentsByCategory(docs, {}).length, 3);
    });

    test('non-empty set keeps only matching categories', () {
      final filtered = filterDocumentsByCategory(
        docs,
        {DocumentCategory.passportId, DocumentCategory.stay},
      );
      expect(filtered.map((d) => d.id).toList(), ['a', 'c']);
    });
  });
}
