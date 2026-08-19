import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/facet.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/filtering/facet_checklist.dart';
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

List<FacetValue> _values(List<String> names) =>
    [for (final n in names) FacetValue(id: n, label: n)];

void main() {
  testWidgets('no search box when at or below the threshold', (tester) async {
    await tester.pumpWidget(
      _app(
        FacetChecklist(
          values: _values(['Thailand', 'Japan']),
          selected: const {},
          onChanged: (_) {},
          searchHint: 'Search countries',
          noResultsLabel: 'No countries match',
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('search box appears above the threshold and filters rows',
      (tester) async {
    const names = [
      'Argentina',
      'Brazil',
      'Canada',
      'Denmark',
      'Egypt',
      'France',
      'Germany',
    ];
    await tester.pumpWidget(
      _app(
        FacetChecklist(
          values: _values(names),
          selected: const {},
          onChanged: (_) {},
          searchHint: 'Search countries',
          noResultsLabel: 'No countries match',
        ),
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
    for (final name in names) {
      expect(find.text(name), findsOneWidget);
    }

    await tester.enterText(find.byType(TextField), 'arg');
    await tester.pumpAndSettle();
    expect(find.text('Argentina'), findsOneWidget);
    for (final name in names.where((n) => n != 'Argentina')) {
      expect(find.text(name), findsNothing);
    }
  });

  testWidgets('shows the no-results message when nothing matches the query',
      (tester) async {
    const names = [
      'Argentina',
      'Brazil',
      'Canada',
      'Denmark',
      'Egypt',
      'France',
      'Germany',
    ];
    await tester.pumpWidget(
      _app(
        FacetChecklist(
          values: _values(names),
          selected: const {},
          onChanged: (_) {},
          searchHint: 'Search countries',
          noResultsLabel: 'No countries match',
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('NO COUNTRIES MATCH'), findsOneWidget);
  });

  testWidgets('tapping a row toggles selection and reflects it on the chip',
      (tester) async {
    Set<String> selected = {};
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => FacetChecklist(
            values: _values(['Thailand', 'Japan']),
            selected: selected,
            onChanged: (next) => setState(() => selected = next),
            searchHint: 'Search',
            noResultsLabel: 'No results',
          ),
        ),
      ),
    );
    expect(
      tester.widget<PillChip>(find.widgetWithText(PillChip, 'Japan')).selected,
      isFalse,
    );
    await tester.tap(find.text('Japan'));
    await tester.pump();
    expect(
      tester.widget<PillChip>(find.widgetWithText(PillChip, 'Japan')).selected,
      isTrue,
    );
  });
}
