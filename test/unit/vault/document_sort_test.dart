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

  group('compareDocumentsByCreatedDate', () {
    test('ascending by createdAt', () {
      final docs = [
        _doc('new', createdAt: DateTime(2026, 6, 1)),
        _doc('old', createdAt: DateTime(2026, 1, 1)),
        _doc('mid', createdAt: DateTime(2026, 3, 1)),
      ]..sort(compareDocumentsByCreatedDate);
      expect(docs.map((d) => d.id).toList(), ['old', 'mid', 'new']);
    });
  });

  group('compareDocumentsByRelevantDate', () {
    test('ascending by relevantDateOf (soonest first)', () {
      final docs = [
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
      ]..sort(compareDocumentsByRelevantDate);
      expect(docs.map((d) => d.id).toList(), ['soon', 'mid', 'far']);
    });
  });
}
