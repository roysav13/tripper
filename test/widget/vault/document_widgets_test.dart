import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/auto_direction_text.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

final _today = DateTime(2026, 7, 19);

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: child),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

Document _doc({bool pinned = false}) => Document(
      id: 'd1',
      title: 'Passport',
      category: DocumentCategory.passportId,
      createdAt: _today,
      isPinned: pinned,
    );

void main() {
  group('DocumentRowTile', () {
    testWidgets('renders as a real elevated Material card', (tester) async {
      await tester.pumpWidget(
        _app(DocumentRowTile(doc: _doc(), warning: false)),
      );
      await tester.pumpAndSettle();

      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Passport'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.elevation, greaterThan(0));
    });

    testWidgets('the leading edge is coral normally, amber when expired',
        (tester) async {
      await tester.pumpWidget(
        _app(DocumentRowTile(doc: _doc(), warning: false)),
      );
      await tester.pumpAndSettle();
      final normalEdges =
          tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(
        normalEdges.any((b) => b.color == AppColors.dark.accent),
        isTrue,
      );

      await tester.pumpWidget(
        _app(DocumentRowTile(doc: _doc(), warning: true)),
      );
      await tester.pumpAndSettle();
      final warningEdges =
          tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(
        warningEdges.any((b) => b.color == AppColors.dark.warning),
        isTrue,
      );
    });

    testWidgets('the accent edge sits on the leading side in RTL too',
        (tester) async {
      await tester.pumpWidget(
        _app(
          DocumentRowTile(doc: _doc(), warning: false),
          direction: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();

      final edge = tester.getTopLeft(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.dark.accent,
        ),
      );
      final text = tester.getTopLeft(find.text('Passport'));
      // RTL: the leading (start) edge is the right side of the screen —
      // the accent bar must sit to the right of the title, not the left.
      expect(edge.dx, greaterThan(text.dx));
    });

    testWidgets('tapping the tile fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _app(
          DocumentRowTile(
            doc: _doc(),
            warning: false,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Passport'));
      expect(tapped, isTrue);
    });

    testWidgets('pinned indicator still renders', (tester) async {
      await tester.pumpWidget(
        _app(DocumentRowTile(doc: _doc(pinned: true), warning: false)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    });
  });

  group('PinnedDocumentCard', () {
    testWidgets(
        'renders a two-stop gradient from surface toward '
        'heroGradientEnd, not a flat color', (tester) async {
      await tester.pumpWidget(
        _app(PinnedDocumentCard(doc: _doc(), warning: false)),
      );
      await tester.pumpAndSettle();

      final ink = tester.widget<Ink>(find.byType(Ink));
      final decoration = ink.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, hasLength(2));
      expect(gradient.colors.first, AppColors.dark.surface);
      // The second stop is a blend, not the raw token — it must not equal
      // heroGradientEnd outright (that would be full-strength, the exact
      // "too strong" the user asked to soften), and must not equal the
      // first stop either (that would be no gradient at all).
      expect(gradient.colors[1], isNot(AppColors.dark.heroGradientEnd));
      expect(gradient.colors[1], isNot(gradient.colors[0]));
      expect(
        gradient.colors[1],
        Color.lerp(
          AppColors.dark.surface,
          AppColors.dark.heroGradientEnd,
          0.35,
        ),
      );
    });

    testWidgets(
        'title and category icon use theme ink, not fixed on-scrim '
        'ink', (tester) async {
      await tester.pumpWidget(
        _app(PinnedDocumentCard(doc: _doc(), warning: false)),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<AutoDirectionText>(
        find.byType(AutoDirectionText),
      );
      expect(title.style?.color, AppColors.dark.inkPrimary);
    });

    testWidgets('tapping the card fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _app(
          PinnedDocumentCard(
            doc: _doc(),
            warning: false,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Passport'));
      expect(tapped, isTrue);
    });
  });
}
