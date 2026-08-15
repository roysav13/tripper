import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/security/vault_lock.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_providers.dart';
import 'package:tripper/features/vault/presentation/vault_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_document_repository.dart';
import '../../helpers/test_preferences.dart';

final _today = DateTime(2026, 7, 19);

/// True if any document card in the tree is currently drawing its coral
/// leading edge in the warning (amber) color instead of the normal
/// accent color (M5, 2026-07-23: expired-only, not "expiring soon" too;
/// redesign, 2026-08-15: signaled by the edge color, not a card border).
bool _hasWarningEdge(WidgetTester tester) {
  final edges = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
  return edges.any((b) => b.color == AppColors.light.warning);
}

Future<Widget> _app(List<Document> docs) async => ProviderScope(
      overrides: [
        await testPreferencesOverride(),
        documentRepositoryProvider
            .overrideWithValue(FakeDocumentRepository(docs)),
        clockProvider.overrideWithValue(() => _today),
        // Auto-pass the vault lock; the lock itself is unit-tested.
        biometricAuthenticatorProvider.overrideWithValue((_) async => true),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const VaultScreen(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('empty vault shows designed empty state', (tester) async {
    await tester.pumpWidget(await _app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Your documents, ready anywhere'), findsOneWidget);
  });

  testWidgets('pinned docs render in the quick-access grid', (tester) async {
    await tester.pumpWidget(
      await _app([
        Document(
          id: 'p',
          title: 'Passport',
          category: DocumentCategory.passportId,
          createdAt: _today,
          isPinned: true,
        ),
        Document(
          id: 'i',
          title: 'Travel insurance',
          category: DocumentCategory.insurance,
          createdAt: _today,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('PINNED · QUICK ACCESS'), findsOneWidget);
    // Grouped by category, one section label per non-empty category.
    expect(find.text('PASSPORT / ID'), findsWidgets);
    expect(find.text('INSURANCE'), findsOneWidget);
    expect(find.text('Passport'), findsNWidgets(2));
    expect(find.text('Travel insurance'), findsOneWidget);
  });

  testWidgets(
      'document expiring soon (not yet expired) shows its date but no '
      'warning edge (M5, 2026-07-23)', (tester) async {
    await tester.pumpWidget(
      await _app([
        Document(
          id: 'x',
          title: 'Old passport',
          category: DocumentCategory.passportId,
          createdAt: _today,
          expiryDate: DateTime(2026, 8, 1), // 13 days out from _today
        ),
      ]),
    );
    await tester.pumpAndSettle();
    // _expiryText formats dd/MM/yyyy (document_widgets.dart), uppercased
    // by MonoText — 1 Aug 2026 renders as "EXP 01/08/2026". The previous
    // 'EXP 08/26' substring never actually matched this format; fixed
    // while investigating an unrelated test failure (2026-07-23).
    expect(find.textContaining('EXP 01/08/2026'), findsOneWidget);
    expect(_hasWarningEdge(tester), isFalse);
  });

  testWidgets('already-expired document gets the warning edge', (tester) async {
    await tester.pumpWidget(
      await _app([
        Document(
          id: 'x',
          title: 'Expired passport',
          category: DocumentCategory.passportId,
          createdAt: _today,
          expiryDate: DateTime(2026, 1, 1), // well before _today
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(_hasWarningEdge(tester), isTrue);
  });

  testWidgets('100+ documents render without overflow or exceptions (M4.2)',
      (tester) async {
    final many = [
      for (var i = 0; i < 120; i++)
        Document(
          id: 'doc-$i',
          title: 'Document number $i with a fairly long descriptive title',
          category: DocumentCategory.values[i % DocumentCategory.values.length],
          createdAt: _today,
        ),
    ];
    await tester.pumpWidget(await _app(many));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.fling(find.byType(ListView), const Offset(0, -3000), 2000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('flight details render in the meta line', (tester) async {
    await tester.pumpWidget(
      await _app([
        Document(
          id: 'f',
          title: 'TLV to BKK',
          category: DocumentCategory.flight,
          createdAt: _today,
          details: const {
            'flightNumber': 'LY083',
            'confirmationCode': 'XK4R2M',
          },
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('LY083'), findsOneWidget);
    expect(find.textContaining('XK4R2M'), findsOneWidget);
  });

  testWidgets('a category filter chip narrows the visible documents',
      (tester) async {
    await tester.pumpWidget(
      await _app([
        Document(
          id: 'p',
          title: 'A passport',
          category: DocumentCategory.passportId,
          createdAt: _today,
        ),
        Document(
          id: 's',
          title: 'A hotel booking',
          category: DocumentCategory.stay,
          createdAt: _today,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('A passport'), findsOneWidget);
    expect(find.text('A hotel booking'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Stay'));
    await tester.pumpAndSettle();

    expect(find.text('A passport'), findsNothing);
    expect(find.text('A hotel booking'), findsOneWidget);
  });

  testWidgets(
      'switching the order-by control from Created to Relevant date '
      'reorders documents within a category', (tester) async {
    await tester.pumpWidget(
      await _app([
        Document(
          id: 'a',
          title: 'Newest doc',
          category: DocumentCategory.passportId,
          createdAt: DateTime(2026, 7, 10), // most recently created
          expiryDate: DateTime(2026, 12, 1), // furthest expiry
        ),
        Document(
          id: 'b',
          title: 'Oldest doc',
          category: DocumentCategory.passportId,
          createdAt: DateTime(2026, 1, 1), // least recently created
          expiryDate: DateTime(2026, 8, 1), // soonest expiry
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // Default order-by is Created: newest first.
    expect(
      tester.getTopLeft(find.text('Newest doc')).dy,
      lessThan(tester.getTopLeft(find.text('Oldest doc')).dy),
    );

    await tester.tap(find.text('Relevant date'));
    await tester.pumpAndSettle();

    // Relevant date is soonest-first — the doc with the nearer expiry
    // (created earlier) now renders first, flipping the order.
    expect(
      tester.getTopLeft(find.text('Oldest doc')).dy,
      lessThan(tester.getTopLeft(find.text('Newest doc')).dy),
    );
  });
}
