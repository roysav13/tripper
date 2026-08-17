import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/error_state.dart';
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
  Widget errorState() => ErrorState(
        title: 'Something went wrong',
        body: 'Could not load this.',
        onRetry: () {},
      );

  testWidgets(
      'does not overflow when squeezed into a shorter-than-natural parent',
      (tester) async {
    await tester.pumpWidget(
      _app(SizedBox(height: 150, child: errorState())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('renders normally (icon, title, body, retry) in a roomy parent',
      (tester) async {
    await tester.pumpWidget(_app(errorState()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Could not load this.'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
