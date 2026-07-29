import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/app.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/security/vault_lock.dart';
import 'package:tripper/features/expenses/presentation/expense_providers.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_providers.dart';

import '../helpers/fake_document_repository.dart';
import '../helpers/fake_expense_repository.dart';
import '../helpers/fake_place_repository.dart';
import '../helpers/fake_trip_repository.dart';
import '../helpers/test_preferences.dart';

/// Permanent guardrails (M4 §4.3): tap targets, labels, contrast.
Future<Widget> _populatedApp() async => ProviderScope(
      overrides: [
        await testPreferencesOverride(),
        testSharesOverride(),
        tripRepositoryProvider.overrideWithValue(
          FakeTripRepository([
            Trip(
              id: 't1',
              name: 'Thailand',
              destinations: const ['Krabi'],
              startDate: DateTime(2026, 7, 16),
              endDate: DateTime(2026, 7, 27),
              completionPromptShown: true,
            ),
          ]),
        ),
        documentRepositoryProvider.overrideWithValue(
          FakeDocumentRepository([
            const Document(
              id: 'd1',
              title: 'Passport',
              category: DocumentCategory.passportId,
              isPinned: true,
            ),
          ]),
        ),
        placeRepositoryProvider.overrideWithValue(
          FakePlaceRepository([
            const Place(
              id: 'p1',
              name: 'Railay viewpoint',
              country: 'Thailand',
              city: 'Krabi',
            ),
          ]),
        ),
        // Without this the M5.5b conversion wiring reaches the real Drift
        // database (via expensesDao), opening a second AppDatabase.
        expenseRepositoryProvider.overrideWithValue(FakeExpenseRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        launchRedirectDoneProvider.overrideWith((ref) => true),
        biometricAuthenticatorProvider.overrideWithValue((_) async => true),
      ],
      child: const TripperApp(),
    );

void main() {
  testWidgets('trips list meets tap target, label and contrast guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('vault meets tap target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vault'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('places meets tap target and contrast guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Places'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('layout survives 1.3x text scaling without overflow',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: await _populatedApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Any RenderFlex overflow throws in tests, so reaching here is the pass.
    expect(find.text('Thailand'), findsOneWidget);
  });
}
