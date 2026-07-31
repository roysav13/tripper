import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/ticket_card.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_card.dart';
import 'package:tripper/l10n/app_localizations.dart';

final _today = DateTime(2026, 7, 19);

Trip _trip({int colorTag = 3, DateTime? start, DateTime? end}) => Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi', 'Bangkok'],
      startDate: start,
      endDate: end,
      colorTag: colorTag,
    );

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('active trip stub shows the day count', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 7, 16),
      end: DateTime(2026, 7, 27),
    );
    await tester.pumpWidget(
      _app(
        TripCard(trip: trip, status: TripStatus.active, today: _today),
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('OF 12'), findsOneWidget);
    expect(find.text('Thailand'), findsOneWidget);
  });

  for (final entry in {
    TripStatus.upcoming: Icons.event_outlined,
    TripStatus.planned: Icons.explore_outlined,
    TripStatus.past: Icons.check_circle_outline,
  }.entries) {
    testWidgets('${entry.key} trip stub shows a status icon, not a number', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          TripCard(trip: _trip(), status: entry.key, today: _today),
        ),
      );

      expect(find.byIcon(entry.value), findsOneWidget);
    });
  }

  testWidgets('renders with the trip\'s identity color when not past', (
    tester,
  ) async {
    final trip = _trip(colorTag: 5);
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.upcoming, today: _today)),
    );

    final ticket = tester.widget<TicketCard>(find.byType(TicketCard));
    final context = tester.element(find.byType(TicketCard));
    expect(ticket.accentColor, context.colors.tripPalette[5]);
  });

  testWidgets('fades the identity color once the trip is past', (
    tester,
  ) async {
    final trip = _trip(colorTag: 5);
    await tester.pumpWidget(
      _app(TripCard(trip: trip, status: TripStatus.past, today: _today)),
    );

    final ticket = tester.widget<TicketCard>(find.byType(TicketCard));
    final context = tester.element(find.byType(TicketCard));
    expect(ticket.accentColor, isNot(context.colors.tripPalette[5]));
  });

  testWidgets('forwards tap to onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        TripCard(
          trip: _trip(),
          status: TripStatus.planned,
          today: _today,
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(TicketCard));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
