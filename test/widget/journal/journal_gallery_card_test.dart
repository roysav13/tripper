import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/paper_card.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _e({String? placeName}) => JournalEntry(
      id: 'e1',
      tripId: 't1',
      summary: 'Some summary text that should not render on the card',
      loggedAt: DateTime(2026, 7, 20),
      createdAt: DateTime(2026, 7, 20),
      placeName: placeName,
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

Color _borderColor(WidgetTester tester) {
  final material = tester.widget<Material>(find.byType(Material).first);
  final shape = material.shape! as RoundedRectangleBorder;
  return shape.side.color;
}

void main() {
  testWidgets('shows date and place, not the summary, tap fires onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryCard(
          entry: _e(placeName: 'Krabi'),
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20 JUL'), findsOneWidget);
    expect(find.text('Krabi'), findsOneWidget);
    expect(
      find.text('Some summary text that should not render on the card'),
      findsNothing,
    );
    expect(find.byIcon(Icons.close), findsNothing); // no inline delete

    await tester.tap(find.byType(JournalGalleryCard));
    expect(tapped, isTrue);
  });

  testWidgets('entry with no placeName shows no place line', (tester) async {
    await tester.pumpWidget(_wrap(JournalGalleryCard(entry: _e())));
    await tester.pumpAndSettle();
    expect(find.text('20 JUL'), findsOneWidget);
  });

  testWidgets('selected renders an accent border, unselected a hairline',
      (tester) async {
    await tester.pumpWidget(_wrap(JournalGalleryCard(entry: _e())));
    await tester.pumpAndSettle();
    final unselectedColor = _borderColor(tester);

    await tester
        .pumpWidget(_wrap(JournalGalleryCard(entry: _e(), selected: true)));
    await tester.pumpAndSettle();
    final selectedColor = _borderColor(tester);

    expect(selectedColor, isNot(unselectedColor));
  });
}
