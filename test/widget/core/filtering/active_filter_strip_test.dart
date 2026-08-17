import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/facet.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/filtering/active_filter_strip.dart';
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
  testWidgets('renders nothing when there is nothing active', (tester) async {
    await tester.pumpWidget(
      _app(
        ActiveFilterStrip(
          active: const [],
          onRemove: (_, __) {},
          onClearAll: () {},
        ),
      ),
    );
    expect(find.byType(ActiveFilterStrip), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('renders one pill per active value', (tester) async {
    await tester.pumpWidget(
      _app(
        ActiveFilterStrip(
          active: const [
            ActiveFilterEntry(
              facetId: 'category',
              value: FacetValue(id: 'hotel', label: 'Hotel'),
            ),
          ],
          onRemove: (_, __) {},
          onClearAll: () {},
        ),
      ),
    );
    expect(find.text('Hotel'), findsOneWidget);
  });

  testWidgets('tapping a pill removes only that value', (tester) async {
    final removed = <(String, String)>[];
    await tester.pumpWidget(
      _app(
        ActiveFilterStrip(
          active: const [
            ActiveFilterEntry(
              facetId: 'category',
              value: FacetValue(id: 'hotel', label: 'Hotel'),
            ),
            ActiveFilterEntry(
              facetId: 'country',
              value: FacetValue(id: 'Japan', label: 'Japan'),
            ),
          ],
          onRemove: (facetId, valueId) => removed.add((facetId, valueId)),
          onClearAll: () {},
        ),
      ),
    );
    await tester.tap(find.text('Hotel'));
    expect(removed, [('category', 'hotel')]);
  });

  testWidgets('Clear appears only once more than one filter is active',
      (tester) async {
    await tester.pumpWidget(
      _app(
        ActiveFilterStrip(
          active: const [
            ActiveFilterEntry(
              facetId: 'category',
              value: FacetValue(id: 'hotel', label: 'Hotel'),
            ),
          ],
          onRemove: (_, __) {},
          onClearAll: () {},
        ),
      ),
    );
    expect(find.text('Clear filters'), findsNothing);

    await tester.pumpWidget(
      _app(
        ActiveFilterStrip(
          active: const [
            ActiveFilterEntry(
              facetId: 'category',
              value: FacetValue(id: 'hotel', label: 'Hotel'),
            ),
            ActiveFilterEntry(
              facetId: 'country',
              value: FacetValue(id: 'Japan', label: 'Japan'),
            ),
          ],
          onRemove: (_, __) {},
          onClearAll: () {},
        ),
      ),
    );
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('a non-default sort renders as a non-removable mono pill',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        ActiveFilterStrip(
          active: const [],
          onRemove: (_, __) {},
          onClearAll: () {},
          sortLabel: 'SORT · NEWEST FIRST',
          onSortTap: () => tapped = true,
        ),
      ),
    );
    expect(find.text('SORT · NEWEST FIRST'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.tap(find.text('SORT · NEWEST FIRST'));
    expect(tapped, isTrue);
  });
}
