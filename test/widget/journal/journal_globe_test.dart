import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_globe.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _e(String id, double lat, double lng) => JournalEntry(
      id: id,
      tripId: 't1',
      summary: id,
      loggedAt: DateTime(2026, 7, 19),
      createdAt: DateTime(2026, 7, 19),
      lat: lat,
      lng: lng,
    );

Widget _wrap(Widget child) => MaterialApp(
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
  // renderGlobe: false — flutter_earth_globe needs a GPU shader surface
  // that widget tests can't create (and we never hit the network here).
  testWidgets(
      'renders one tappable icon per located entry, tap fires the callback',
      (tester) async {
    JournalEntry? tapped;
    await tester.pumpWidget(
      _wrap(
        JournalGlobe(
          renderGlobe: false,
          onEntryTap: (e) => tapped = e,
          entries: [_e('a', 8.0, 98.8), _e('b', 7.7, 98.7)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.circle).first);
    await tester.pump();
    expect(tapped?.id, 'a');
  });

  testWidgets('entries without a location render no icon', (tester) async {
    final unlocated = JournalEntry(
      id: 'u',
      tripId: 't1',
      summary: 'no pin',
      loggedAt: DateTime(2026, 7, 19),
      createdAt: DateTime(2026, 7, 19),
    );
    await tester.pumpWidget(
      _wrap(JournalGlobe(renderGlobe: false, entries: [unlocated])),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.circle), findsNothing);
    expect(find.byIcon(Icons.photo_camera), findsNothing);
  });

  testWidgets('zero entries renders without crashing', (tester) async {
    await tester
        .pumpWidget(_wrap(const JournalGlobe(renderGlobe: false, entries: [])));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.circle), findsNothing);
  });
}
