import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_widgets.dart';

const _doc = Document(
  id: 'd',
  title: 'Test doc',
  category: DocumentCategory.flight,
);

void main() {
  group('documentCategoryAccent', () {
    test('every category maps to a color actually in tripPalette', () {
      final colors = AppColors.light;
      for (final category in DocumentCategory.values) {
        expect(
          colors.tripPalette,
          contains(documentCategoryAccent(colors, category)),
        );
      }
    });

    test('categories that should read distinctly do not share a color', () {
      final colors = AppColors.light;
      // Passport, flight, and insurance are the three most safety-critical
      // categories to tell apart at a glance — pin down that they're
      // actually different swatches, not just "documented as different."
      final passport =
          documentCategoryAccent(colors, DocumentCategory.passportId);
      final flight = documentCategoryAccent(colors, DocumentCategory.flight);
      final insurance =
          documentCategoryAccent(colors, DocumentCategory.insurance);
      expect({passport, flight, insurance}, hasLength(3));
    });
  });

  group('documentCardAccent', () {
    test('uses the category color when there is no warning', () {
      final colors = AppColors.light;
      expect(
        documentCardAccent(colors, _doc, warning: false),
        documentCategoryAccent(colors, DocumentCategory.flight),
      );
    });

    test('overrides the category color with the system warning color', () {
      final colors = AppColors.light;
      final accent = documentCardAccent(colors, _doc, warning: true);
      expect(accent, colors.warning);
      // And specifically not the category's own identity color, which
      // is the whole point — an expired flight document must not still
      // look like a routine navy... er, cobalt flight card.
      expect(
        accent,
        isNot(documentCategoryAccent(colors, DocumentCategory.flight)),
      );
    });
  });
}
