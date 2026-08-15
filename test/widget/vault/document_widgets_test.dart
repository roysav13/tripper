import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
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

Document _doc({bool pinned = false, DateTime? expiry}) => Document(
      id: 'd1',
      title: 'Passport',
      category: DocumentCategory.passportId,
      createdAt: _today,
      isPinned: pinned,
      expiryDate: expiry,
    );

void main() {
  group('DocumentRowTile', () {
    testWidgets('renders as a real elevated Material card', (tester) async {
      await tester.pumpWidget(
        _app(DocumentRowTile(doc: _doc(), warning: false)),
      );
      await tester.pumpAndSettle();

      final material = tester.widget<Material>(
        find.ancestor(
          of: find.text('Passport'),
          matching: find.byType(Material),
        ).first,
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

      final edge = tester.getTopLeft(find.byType(ColoredBox).first);
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
}
