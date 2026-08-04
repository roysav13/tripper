import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/domain/journal_photo.dart';
import 'package:tripper/features/journal/presentation/journal_map_view.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _entry(
  String id,
  String summary, {
  double? lat,
  double? lng,
  bool withPhoto = false,
}) =>
    JournalEntry(
      id: id,
      tripId: 'trip-1',
      summary: summary,
      loggedAt: DateTime(2026, 7, 20),
      createdAt: DateTime(2026, 7, 20),
      lat: lat,
      lng: lng,
      photos: withPhoto
          ? [const JournalPhoto(id: 'p1', filePath: '/tmp/does-not-exist.jpg')]
          : const [],
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
  // renderMap: false — Google Maps needs a platform view that widget tests
  // can't create (and we never hit the network here).
  testWidgets(
      'unlocated entries are excluded, photo vs plain entries are '
      'distinguishable', (tester) async {
    await tester.pumpWidget(
      _wrap(
        JournalMapView(
          renderMap: false,
          entries: [
            _entry('e1', 'Arrived', lat: 8.0, lng: 98.8),
            _entry('e2', 'Beach day', lat: 7.7, lng: 98.7, withPhoto: true),
            _entry('e3', 'No location yet'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera), findsOneWidget);
  });

  testWidgets('no located entries renders nothing without crashing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        JournalMapView(
          renderMap: false,
          entries: [_entry('e1', 'No location yet')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.circle), findsNothing);
    expect(find.byIcon(Icons.photo_camera), findsNothing);
  });
}
