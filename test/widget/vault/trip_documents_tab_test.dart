import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_providers.dart';
import 'package:tripper/features/vault/presentation/trip_documents_tab.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_document_repository.dart';

const _trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

Future<Widget> _app(FakeDocumentRepository repo) async => ProviderScope(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TripDocumentsTab(trip: _trip)),
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
  testWidgets('documents render for this trip', (tester) async {
    final repo = FakeDocumentRepository([
      Document(
        id: 'd1',
        title: 'Passport',
        category: DocumentCategory.passportId,
        createdAt: DateTime(2026, 7, 19),
        tripIds: const ['t1'],
      ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Passport'), findsOneWidget);
  });

  testWidgets('a stream failure shows the error state with retry',
      (tester) async {
    final repo = FakeDocumentRepository([
      Document(
        id: 'd1',
        title: 'Passport',
        category: DocumentCategory.passportId,
        createdAt: DateTime(2026, 7, 19),
        tripIds: const ['t1'],
      ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    repo.emitError(Exception('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('documents group by category, collapsible per section',
      (tester) async {
    final repo = FakeDocumentRepository([
      Document(
        id: 'd1',
        title: 'Passport',
        category: DocumentCategory.passportId,
        createdAt: DateTime(2026, 7, 19),
        tripIds: const ['t1'],
      ),
      Document(
        id: 'd2',
        title: 'Flight to BKK',
        category: DocumentCategory.flight,
        createdAt: DateTime(2026, 7, 19),
        tripIds: const ['t1'],
      ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('PASSPORT / ID'), findsOneWidget);
    expect(find.text('FLIGHT'), findsOneWidget);

    await tester.tap(find.text('FLIGHT'));
    await tester.pumpAndSettle();

    expect(find.text('Flight to BKK'), findsNothing);
    expect(find.text('Passport'), findsOneWidget);
  });
}
