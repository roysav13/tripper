import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/ticket_card.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

void main() {
  group('DocumentRowTile', () {
    testWidgets('renders on a TicketCard with the category icon and color', (
      tester,
    ) async {
      const doc = Document(
        id: 'p',
        title: 'My passport',
        category: DocumentCategory.passportId,
      );
      await tester.pumpWidget(
        _app(const DocumentRowTile(doc: doc, warning: false)),
      );

      expect(find.text('My passport'), findsOneWidget);
      expect(find.byIcon(Icons.badge_outlined), findsOneWidget);

      final ticket = tester.widget<TicketCard>(find.byType(TicketCard));
      final context = tester.element(find.byType(TicketCard));
      expect(
        ticket.accentColor,
        documentCategoryAccent(context.colors, DocumentCategory.passportId),
      );
    });

    testWidgets('an expired document turns the warning color, not its own', (
      tester,
    ) async {
      const doc = Document(
        id: 'p',
        title: 'Old passport',
        category: DocumentCategory.passportId,
      );
      await tester.pumpWidget(
        _app(const DocumentRowTile(doc: doc, warning: true)),
      );

      final ticket = tester.widget<TicketCard>(find.byType(TicketCard));
      final context = tester.element(find.byType(TicketCard));
      expect(ticket.accentColor, context.colors.warning);
    });

    testWidgets('shows the pin indicator only when pinned', (tester) async {
      const pinned = Document(
        id: 'p',
        title: 'Pinned doc',
        category: DocumentCategory.flight,
        isPinned: true,
      );
      await tester.pumpWidget(
        _app(const DocumentRowTile(doc: pinned, warning: false)),
      );
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

      const unpinned = Document(
        id: 'u',
        title: 'Unpinned doc',
        category: DocumentCategory.flight,
      );
      await tester.pumpWidget(
        _app(const DocumentRowTile(doc: unpinned, warning: false)),
      );
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    });

    testWidgets('forwards tap', (tester) async {
      var tapped = false;
      const doc = Document(
        id: 'p',
        title: 'Tap me',
        category: DocumentCategory.other,
      );
      await tester.pumpWidget(
        _app(
          DocumentRowTile(doc: doc, warning: false, onTap: () => tapped = true),
        ),
      );
      await tester.tap(find.byType(TicketCard));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('PinnedDocumentCard', () {
    testWidgets('renders title and expiry in a narrower ticket', (
      tester,
    ) async {
      final doc = Document(
        id: 'p',
        title: 'Boarding pass',
        category: DocumentCategory.flight,
        expiryDate: DateTime(2026, 8, 1),
      );
      await tester.pumpWidget(
        _app(PinnedDocumentCard(doc: doc, warning: false)),
      );

      expect(find.text('Boarding pass'), findsOneWidget);
      expect(find.textContaining('01/08/2026'), findsOneWidget);

      final ticket = tester.widget<TicketCard>(find.byType(TicketCard));
      expect(ticket.stubWidth, lessThan(84.0)); // narrower than the default
    });
  });
}
