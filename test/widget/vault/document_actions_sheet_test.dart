import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/security/vault_lock.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_providers.dart';
import 'package:tripper/features/vault/presentation/vault_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_document_repository.dart';
import '../../helpers/fake_trip_repository.dart';
import '../../helpers/test_preferences.dart';

final _today = DateTime(2026, 7, 19);

final _trip = Trip(
  id: 't1',
  name: 'Thailand',
  destinations: const ['Bangkok'],
  startDate: DateTime(2026, 8, 1),
  endDate: DateTime(2026, 8, 10),
  colorTag: 0,
);

Future<Widget> _app(FakeDocumentRepository docs) async => ProviderScope(
      overrides: [
        await testPreferencesOverride(),
        documentRepositoryProvider.overrideWithValue(docs),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository([_trip])),
        clockProvider.overrideWithValue(() => _today),
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
  testWidgets(
      'linking a standalone document to a trip survives the sheet\'s pop '
      '(regression — "ref used after dispose" bug)', (tester) async {
    final repo = FakeDocumentRepository([
      Document(
        id: 'passport',
        title: 'Passport',
        category: DocumentCategory.passportId,
        createdAt: _today,
        isGlobal: true,
        // Unlinked at start — a standalone vault document.
      ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    // Open the actions sheet for the standalone document.
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    expect(find.text('Link to trips'), findsOneWidget);

    // Tapping this pops the actions sheet *and* opens the link dialog.
    // pumpAndSettle here lets the sheet's exit transition — and the
    // widget/ref disposal that goes with it — fully finish before we
    // touch the dialog, exactly like a real user taking a moment to pick
    // a trip. This is the timing the original bug depended on.
    await tester.tap(find.text('Link to trips'));
    await tester.pumpAndSettle();
    expect(find.text('Thailand'), findsOneWidget);

    await tester.tap(find.text('Thailand'));
    await tester.tap(find.text('Save'));

    // Must not throw "Cannot use ref after the widget was disposed."
    await tester.pumpAndSettle();

    expect(find.text('Trip links updated.'), findsOneWidget);
    final linked = await repo.watchAll().first;
    expect(linked.single.tripIds, ['t1']);
  });
}
