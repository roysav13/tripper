import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/domain/packing_item_status.dart';
import 'package:tripper/features/packing/domain/trip_packing_item.dart';
import 'package:tripper/features/packing/presentation/packing_providers.dart';
import 'package:tripper/features/packing/presentation/trip_packing_tab.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_packing_repository.dart';

const _trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

TripPackingItem _item({
  required String id,
  PackingCategory category = PackingCategory.other,
  String label = 'Charger',
  PackingItemStatus status = PackingItemStatus.toPack,
  String tripId = 't1',
}) =>
    TripPackingItem(
      id: id,
      tripId: tripId,
      category: category,
      label: label,
      status: status,
      sortOrder: 0,
    );

Widget _app(FakePackingRepository repo) => ProviderScope(
      overrides: [packingRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TripPackingTab(trip: _trip)),
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
  testWidgets('empty trip shows the designed empty state', (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Nothing packed yet'), findsOneWidget);
  });

  testWidgets('items render grouped under their category header',
      (tester) async {
    final repo = FakePackingRepository(
      tripItems: [
        _item(
          id: 'a',
          category: PackingCategory.clothing,
          label: 'Black shirt',
        ),
        _item(id: 'b', category: PackingCategory.documents, label: 'Passport'),
      ],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('CLOTHING'), findsOneWidget);
    expect(find.text('DOCUMENTS'), findsOneWidget);
    expect(find.text('Black shirt'), findsOneWidget);
    expect(find.text('Passport'), findsOneWidget);
    // Categories with nothing in them stay hidden.
    expect(find.text('ELECTRONICS'), findsNothing);
  });

  testWidgets('tapping a non-clothing item toggles checked/unchecked',
      (tester) async {
    final repo = FakePackingRepository(
      tripItems: [
        _item(id: 'a', category: PackingCategory.documents, label: 'Passport'),
      ],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(
      (await repo.watchTripItems('t1').first).single.status,
      PackingItemStatus.packed,
    );
  });

  testWidgets(
      'a clothing item shows its status and opens a 5-option menu on tap',
      (tester) async {
    final repo = FakePackingRepository(
      tripItems: [
        _item(
          id: 'a',
          category: PackingCategory.clothing,
          label: 'Black shirt',
          status: PackingItemStatus.worn,
        ),
      ],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Worn'), findsOneWidget);

    await tester.tap(find.text('Black shirt'));
    await tester.pumpAndSettle();

    expect(find.text('To pack'), findsWidgets);
    expect(find.text('Clean'), findsWidgets);

    await tester.tap(find.text('Clean').last);
    await tester.pumpAndSettle();

    expect(
      (await repo.watchTripItems('t1').first).single.status,
      PackingItemStatus.clean,
    );
  });

  testWidgets(
      "tapping a non-clothing item's label opens the edit sheet "
      'pre-filled, and saving renames the row', (tester) async {
    final repo = FakePackingRepository(
      tripItems: [
        _item(id: 'a', category: PackingCategory.documents, label: 'Passport'),
      ],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

    expect(find.text('Edit item'), findsOneWidget);
    // Pre-filled with the current label, not blank.
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Passport'))
          .controller!
          .text,
      'Passport',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Item'),
      'EU passport',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('EU passport'), findsOneWidget);
    expect(find.text('Passport'), findsNothing);
    expect(
      (await repo.watchTripItems('t1').first).single.label,
      'EU passport',
    );
  });

  testWidgets(
      "a clothing item has its own edit affordance — the card's tap is "
      'spoken for by the status picker', (tester) async {
    final repo = FakePackingRepository(
      tripItems: [
        _item(
          id: 'a',
          category: PackingCategory.clothing,
          label: 'Black shirt',
          status: PackingItemStatus.worn,
        ),
      ],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit item'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Black shirt'))
          .controller!
          .text,
      'Black shirt',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Item'),
      'Grey shirt',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Grey shirt'), findsOneWidget);
    final updated = (await repo.watchTripItems('t1').first).single;
    expect(updated.label, 'Grey shirt');
    expect(updated.status, PackingItemStatus.worn); // status untouched
  });

  testWidgets('deleting an item asks for confirmation first', (tester) async {
    final repo = FakePackingRepository(
      tripItems: [_item(id: 'a', label: 'Charger')],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Charger'), findsOneWidget); // still there

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Charger'), findsNothing);
    expect(find.text('Item deleted.'), findsOneWidget);
  });

  testWidgets('a stream failure shows the error state with retry',
      (tester) async {
    final repo = FakePackingRepository(tripItems: [_item(id: 'a')]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    repo.emitTripItemsError(Exception('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('the empty-state CTA opens the add-item sheet', (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add an item'));
    await tester.pumpAndSettle();

    expect(find.text('Add item'), findsOneWidget);
  });

  testWidgets(
      'adding an item picks a category and label, then appears in that '
      "category's section", (tester) async {
    final repo = FakePackingRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add an item'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Documents'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Item'),
      'Passport',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('DOCUMENTS'), findsOneWidget);
  });

  testWidgets('a floating add button is shown once there are items',
      (tester) async {
    final repo = FakePackingRepository(tripItems: [_item(id: 'a')]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add item'), findsOneWidget);
  });

  testWidgets('applying a template with no saved templates shows a hint',
      (tester) async {
    await tester.pumpWidget(_app(FakePackingRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply template…'));
    await tester.pumpAndSettle();

    expect(
      find.text('No saved templates yet — create one from Manage templates.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'applying a template appends its items to the trip list and shows '
      'a confirmation', (tester) async {
    final repo = FakePackingRepository();
    await repo.createTemplate(name: 'Beach trip');
    final templates = await repo.watchTemplates().first;
    await repo.addTemplateItem(
      templateId: templates.single.id,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply template…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beach trip'));
    await tester.pumpAndSettle();

    expect(find.text('Swimsuit'), findsOneWidget);
    expect(find.text('Added 1 item from Beach trip'), findsOneWidget);
  });
}
