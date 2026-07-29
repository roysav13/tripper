import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/vault/domain/checkin_notifications.dart';
import 'package:tripper/features/vault/presentation/document_form_sheet.dart';
import 'package:tripper/features/vault/presentation/document_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_document_repository.dart';

final _today = DateTime(2026, 7, 23);

Future<FakeDocumentRepository> _pump(WidgetTester tester) async {
  final repo = FakeDocumentRepository([]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _today),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDocumentFormSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets(
      'departure-time field is hidden for the default (non-flight) '
      'category', (tester) async {
    await _pump(tester);
    expect(find.text('Departure time'), findsNothing);
  });

  testWidgets('selecting Flight reveals the departure-time field',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Flight'));
    await tester.pumpAndSettle();
    expect(find.text('Departure time'), findsOneWidget);
  });

  testWidgets('switching away from Flight hides it again', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Flight'));
    await tester.pumpAndSettle();
    expect(find.text('Departure time'), findsOneWidget);
    // "Passport / ID" (DocumentCategory.values first entry) rather than
    // "Other" (last entry) — the category chip row is a horizontally
    // scrolling ListView and "Other" isn't built/visible without
    // scrolling to it first; the first chip always is.
    await tester.tap(find.text('Passport / ID'));
    await tester.pumpAndSettle();
    expect(find.text('Departure time'), findsNothing);
  });

  testWidgets(
      'saving a flight document without setting departure time leaves '
      'the detail key unset (optional, no-op downstream per '
      'checkInOpensNotifications)', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.text('Flight'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Home flight');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final docs = await repo.watchAll().first;
    expect(docs, hasLength(1));
    expect(docs.single.details.containsKey(kDepartureTimeDetailKey), isFalse);
  });
}
