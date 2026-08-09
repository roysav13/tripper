import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/domain/journal_photo.dart';
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

/// The color of the card's own hairline/accent border. `Scaffold` wraps
/// its body in its own `Material` with no `shape` set, and it's an
/// ancestor of `PaperCard`'s `Material` — so `find.byType(Material).first`
/// would resolve to Scaffold's, not the card's. Filter for the one whose
/// `shape` is actually a `RoundedRectangleBorder` (PaperCard always sets
/// one — see `lib/core/widgets/paper_card.dart`), same pattern as
/// `test/widget/vault/vault_screen_test.dart`'s `_hasWarningBorder`.
Color _borderColor(WidgetTester tester) {
  final materials = tester.widgetList<Material>(find.byType(Material));
  final card = materials.firstWhere((m) => m.shape is RoundedRectangleBorder);
  return (card.shape! as RoundedRectangleBorder).side.color;
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

  testWidgets(
      'a multi-photo entry does not show a photo-count badge on the '
      'gallery card', (tester) async {
    final entry = JournalEntry(
      id: 'e1',
      tripId: 't1',
      summary: 'irrelevant',
      loggedAt: DateTime(2026, 7, 20),
      createdAt: DateTime(2026, 7, 20),
      photos: const [
        JournalPhoto(id: 'p1', filePath: '/tmp/a.jpg'),
        JournalPhoto(id: 'p2', filePath: '/tmp/b.jpg'),
        JournalPhoto(id: 'p3', filePath: '/tmp/c.jpg'),
      ],
    );
    await tester.pumpWidget(_wrap(JournalGalleryCard(entry: entry)));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
    expect(find.text('2'), findsNothing);
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
