import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/filtering/filter_sort_button.dart';
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

Finder _badgeFinder() => find.descendant(
      of: find.byType(FilterSortButton),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );

void main() {
  testWidgets('no badge when nothing is active', (tester) async {
    await tester.pumpWidget(
      _app(FilterSortButton(active: false, onPressed: () {})),
    );
    expect(_badgeFinder(), findsNothing);
  });

  testWidgets('shows a badge when active', (tester) async {
    await tester.pumpWidget(
      _app(FilterSortButton(active: true, onPressed: () {})),
    );
    expect(_badgeFinder(), findsOneWidget);
  });

  testWidgets('tapping the button invokes onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(FilterSortButton(active: false, onPressed: () => tapped = true)),
    );
    await tester.tap(find.byIcon(Icons.tune));
    expect(tapped, isTrue);
  });
}
