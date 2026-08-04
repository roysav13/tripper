import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/presentation/journal_globe.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/l10n/app_localizations.dart';

Place _p(String name, double lat, double lng) => Place(
      id: name,
      name: name,
      lat: lat,
      lng: lng,
      status: PlaceStatus.beenThere,
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
  testWidgets('renders one tappable icon per place, tap fires the callback',
      (tester) async {
    Place? tapped;
    await tester.pumpWidget(
      _wrap(
        JournalGlobe(
          renderGlobe: false,
          onPlaceTap: (p) => tapped = p,
          places: [_p('Railay', 8.0, 98.8), _p('Phi Phi', 7.7, 98.7)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.public), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.public).first);
    await tester.pump();
    expect(tapped?.name, 'Railay');
  });

  testWidgets('zero places renders without crashing', (tester) async {
    await tester
        .pumpWidget(_wrap(const JournalGlobe(renderGlobe: false, places: [])));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.public), findsNothing);
  });
}
