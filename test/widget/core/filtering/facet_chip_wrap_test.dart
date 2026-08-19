import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/facet.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/filtering/facet_chip_wrap.dart';
import 'package:tripper/core/widgets/pill_chip.dart';
import 'package:tripper/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

void main() {
  const values = [
    FacetValue(id: 'hotel', label: 'Hotel'),
    FacetValue(id: 'restaurant', label: 'Restaurant'),
  ];

  testWidgets('renders one chip per value', (tester) async {
    await tester.pumpWidget(
      _app(
        FacetChipWrap(
          values: values,
          selected: const {},
          onToggle: (_, __) {},
        ),
      ),
    );
    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('Restaurant'), findsOneWidget);
    expect(find.byType(PillChip), findsNWidgets(2));
  });

  testWidgets('selected chips reflect the selected set', (tester) async {
    await tester.pumpWidget(
      _app(
        FacetChipWrap(
          values: values,
          selected: const {'hotel'},
          onToggle: (_, __) {},
        ),
      ),
    );
    final hotelChip = tester.widget<PillChip>(
      find.widgetWithText(PillChip, 'Hotel'),
    );
    expect(hotelChip.selected, isTrue);
    final restaurantChip = tester.widget<PillChip>(
      find.widgetWithText(PillChip, 'Restaurant'),
    );
    expect(restaurantChip.selected, isFalse);
  });

  testWidgets('tapping a chip toggles it with the correct next state',
      (tester) async {
    final calls = <(String, bool)>[];
    await tester.pumpWidget(
      _app(
        FacetChipWrap(
          values: values,
          selected: const {'hotel'},
          onToggle: (id, selected) => calls.add((id, selected)),
        ),
      ),
    );
    await tester.tap(find.text('Hotel'));
    await tester.tap(find.text('Restaurant'));
    expect(calls, [('hotel', false), ('restaurant', true)]);
  });

  testWidgets('renders an icon when iconOf is provided', (tester) async {
    await tester.pumpWidget(
      _app(
        FacetChipWrap(
          values: values,
          selected: const {},
          onToggle: (_, __) {},
          iconOf: (id) =>
              id == 'hotel' ? Icons.hotel_outlined : Icons.restaurant_outlined,
        ),
      ),
    );
    expect(find.byIcon(Icons.hotel_outlined), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
  });
}
