import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/ticket_card.dart';
import 'package:tripper/l10n/app_localizations.dart';

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('renders stub and body content and responds to tap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TicketCard(
            accentColor: context.colors.tripPalette[0],
            stub: const Text('12'),
            body: const Text('Krabi'),
            semanticLabel: 'Krabi trip, day 12',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('Krabi'), findsOneWidget);

    await tester.tap(find.byType(TicketCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('lays out and paints without error in RTL', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TicketCard(
            accentColor: context.colors.tripPalette[2],
            stub: const Icon(Icons.flight),
            body: const Text('טיסה לבנגקוק'),
            semanticLabel: 'Flight to Bangkok',
          ),
        ),
        direction: TextDirection.rtl,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('טיסה לבנגקוק'), findsOneWidget);
  });

  testWidgets('stub content contrasts with the pale marigold accent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            final colors = context.colors;
            return TicketCard(
              // Index 1 is the deliberately pale hue (see app_colors.dart)
              // — its stub text must resolve to ink, not white-on-white.
              accentColor: colors.tripPalette[1],
              stub: const Text('SUN'),
              body: const Text('Marigold trip'),
              semanticLabel: 'Marigold trip',
            );
          },
        ),
      ),
    );

    final textWidget = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('SUN'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    final context = tester.element(find.text('SUN'));
    final colors = context.colors;
    expect(textWidget.style.color, colors.inkPrimary);
  });

  testWidgets('scales down while pressed and back up on release', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TicketCard(
            accentColor: context.colors.tripPalette[0],
            stub: const Text('1'),
            body: const Text('Press me'),
            semanticLabel: 'Press me',
            onTap: () {},
          ),
        ),
      ),
    );

    AnimatedScale scaleWidget() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale));

    expect(scaleWidget().scale, 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TicketCard)),
    );
    await tester.pump();
    expect(scaleWidget().scale, lessThan(1.0));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(scaleWidget().scale, 1.0);
  });

  testWidgets('does not enter a pressed state when onTap is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TicketCard(
            accentColor: context.colors.tripPalette[0],
            stub: const Text('1'),
            body: const Text('Not tappable'),
            semanticLabel: 'Not tappable',
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TicketCard)),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.0,
    );
    await gesture.up();
  });

  testWidgets(
    'exposes a single labeled tap target — regression test for the bug '
    'where PhysicalShape/Stack/CustomPaint/AnimatedScale broke automatic '
    'semantics merging (caught in accessibility_test.dart, fixed by making '
    'semanticLabel required input instead of relying on merging)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TicketCard(
              accentColor: context.colors.tripPalette[0],
              stub: const Text('4'),
              body: const Text('Krabi trip'),
              semanticLabel: 'Krabi trip, day 4 of 12',
              onTap: () {},
            ),
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );
}
