import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

const _summaryText = 'A quiet limestone cove reachable only by boat.';

const _withSummary = Place(
  id: 'p1',
  name: 'Railay Beach',
  summary: _summaryText,
);

Widget _app(Place place, {VoidCallback? onTap}) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: PlaceRowCard(place: place, onTap: onTap)),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

void main() {
  testWidgets('no summary toggle when the place has none yet', (
    tester,
  ) async {
    const place = Place(id: 'p1', name: 'Railay Beach');
    await tester.pumpWidget(_app(place));

    expect(find.text('VIEW SUMMARY'), findsNothing);
  });

  testWidgets('no summary toggle when fetched but empty', (tester) async {
    final place = Place(
      id: 'p1',
      name: 'Railay Beach',
      summaryFetchedAt: DateTime(2026, 8, 17),
    );
    await tester.pumpWidget(_app(place));

    expect(find.text('VIEW SUMMARY'), findsNothing);
  });

  testWidgets(
      'summary starts collapsed (text not in the tree) and expands '
      'on tap', (tester) async {
    await tester.pumpWidget(_app(_withSummary));

    expect(find.text('VIEW SUMMARY'), findsOneWidget);
    expect(find.text(_summaryText), findsNothing);

    await tester.tap(find.text('VIEW SUMMARY'));
    await tester.pumpAndSettle();

    expect(find.text('HIDE SUMMARY'), findsOneWidget);
    expect(find.text(_summaryText), findsOneWidget);

    // Tapping again collapses it back.
    await tester.tap(find.text('HIDE SUMMARY'));
    await tester.pumpAndSettle();

    expect(find.text('VIEW SUMMARY'), findsOneWidget);
    expect(find.text(_summaryText), findsNothing);
  });

  testWidgets('tapping the summary toggle does not trigger the card onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_app(_withSummary, onTap: () => tapped = true));

    await tester.tap(find.text('VIEW SUMMARY'));
    await tester.pumpAndSettle();

    expect(tapped, isFalse);
  });
}
