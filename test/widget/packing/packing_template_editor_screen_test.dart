import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/presentation/packing_providers.dart';
import 'package:tripper/features/packing/presentation/packing_template_editor_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_packing_repository.dart';

Future<Widget> _app(FakePackingRepository repo, String templateId) async =>
    ProviderScope(
      overrides: [packingRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: PackingTemplateEditorScreen(templateId: templateId),
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
  testWidgets('items render grouped by category', (tester) async {
    final repo = FakePackingRepository();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await tester.pumpWidget(await _app(repo, templateId));
    await tester.pumpAndSettle();

    expect(find.text('CLOTHING'), findsOneWidget);
    expect(find.text('Swimsuit'), findsOneWidget);
  });

  testWidgets('adding an item via the FAB appears in its category',
      (tester) async {
    final repo = FakePackingRepository();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await tester.pumpWidget(await _app(repo, templateId));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.enterText(find.widgetWithText(TextField, 'Item'), 'Passport');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Passport'), findsOneWidget);
  });

  testWidgets('deleting an item asks for confirmation first', (tester) async {
    final repo = FakePackingRepository();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await tester.pumpWidget(await _app(repo, templateId));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    // Confirm dialog is up; nothing deleted yet.
    expect(find.text('Delete this item?'), findsOneWidget);
    expect(find.text('Swimsuit'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Swimsuit'), findsOneWidget); // cancelling keeps it

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Swimsuit'), findsNothing);
  });
}
