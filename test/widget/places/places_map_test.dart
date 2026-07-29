import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/places_map_view.dart';
import 'package:tripper/l10n/app_localizations.dart';

Place _p(
  String name,
  double? lat,
  double? lng, {
  bool visited = false,
}) =>
    Place(
      id: name,
      name: name,
      lat: lat,
      lng: lng,
      status: visited ? PlaceStatus.beenThere : PlaceStatus.wantToGo,
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
  // can't create (and we never hit the network in tests).
  testWidgets('renders one pin per located place, right icon per status',
      (tester) async {
    Place? tapped;
    await tester.pumpWidget(
      _wrap(
        PlacesMapView(
          renderMap: false,
          onPlaceTap: (p) => tapped = p,
          places: [
            _p('Railay', 8.0, 98.8),
            _p('Phi Phi', 7.7, 98.7, visited: true),
            _p('No location', null, null),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Wishlist pin + visited check; unlocated place has no pin.
    expect(find.byIcon(Icons.place), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.byIcon(Icons.place));
    await tester.pump();
    expect(tapped?.name, 'Railay');
  });

  testWidgets('no located places renders nothing without crashing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        PlacesMapView(
          renderMap: false,
          places: [_p('Somewhere', null, null)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.place), findsNothing);
  });
}
