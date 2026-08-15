import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_card.dart';
import 'package:tripper/l10n/app_localizations.dart';

final _today = DateTime(2026, 7, 19);

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
  testWidgets('no cover photo renders the generated gradient fallback',
      (tester) async {
    const trip =
        Trip(id: 'no-photo', name: 'Thailand', destinations: ['Krabi']);
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.planned, today: _today)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient is LinearGradient,
      ),
      findsWidgets,
    );
  });

  testWidgets('a cover photo renders as an Image, not the gradient',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('trip_card_cover');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    final photo = File('${dir.path}/cover.png')
      ..writeAsBytesSync(const <int>[137, 80, 78, 71]);
    final trip = Trip(
      id: 'with-photo',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.planned, today: _today)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('both the cover and the name carry their Hero tags',
      (tester) async {
    const trip = Trip(id: 'h1', name: 'Japan', destinations: ['Tokyo']);
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.planned, today: _today)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == 'trip-cover-h1'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == 'trip-name-h1'),
      findsOneWidget,
    );
  });

  testWidgets('active trip shows the day-count pill', (tester) async {
    final trip = Trip(
      id: 'a1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      startDate: DateTime(2026, 7, 16),
      endDate: DateTime(2026, 7, 27),
    );
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.active, today: _today)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day 4 of 12'), findsOneWidget);
  });

  testWidgets('tapping the card fires onTap', (tester) async {
    const trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);
    var tapped = false;
    await tester.pumpWidget(
      _app(
        TripCard(
          trip: trip,
          status: TripStatus.planned,
          today: _today,
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TripCard));
    expect(tapped, isTrue);
  });
}
