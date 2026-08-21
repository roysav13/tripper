import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/packing/presentation/packing_providers.dart';
import 'package:tripper/features/packing/presentation/packing_template_manager_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_packing_repository.dart';

Widget _app(FakePackingRepository repo) => ProviderScope(
      overrides: [packingRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PackingTemplateManagerScreen(),
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
  testWidgets('empty state shown with no templates', (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No templates yet'), findsOneWidget);
  });

  testWidgets('creating a template adds it to the list', (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New template'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Template name'),
      'Beach trip',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Beach trip'), findsOneWidget);
  });

  testWidgets('renaming a template updates the list', (tester) async {
    final repo = FakePackingRepository();
    await repo.createTemplate(name: 'Beach trip');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Summer beach trip');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Summer beach trip'), findsOneWidget);
    expect(find.text('Beach trip'), findsNothing);
  });

  testWidgets('deleting a template asks for confirmation first',
      (tester) async {
    final repo = FakePackingRepository();
    await repo.createTemplate(name: 'Beach trip');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Beach trip'), findsOneWidget); // still there

    await tester.tap(find.text('Delete this template?').hitTestable().first);
    // Confirm button uses the shared delete label; tap the dialog's action.
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Beach trip'), findsNothing);
    expect(find.text('Template deleted.'), findsOneWidget);
  });
}
