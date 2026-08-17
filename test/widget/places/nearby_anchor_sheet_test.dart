import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/location/location_providers.dart';
import 'package:tripper/core/location/location_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/nearby_anchor_sheet.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_location_service.dart';

Place _p(String name, {double? lat, double? lng}) => Place(
      id: name,
      name: name,
      lat: lat,
      lng: lng,
    );

class _OpenSheetButton extends ConsumerWidget {
  const _OpenSheetButton({required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => showNearbyAnchorSheet(context, ref, places: places),
      child: const Text('open'),
    );
  }
}

Widget _app(List<Place> places, {LocationFix? locationFix}) => ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            locationFix ??
                const LocationUnavailable(LocationUnavailableReason.error),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: _OpenSheetButton(places: places)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('Near me is disabled when location is unavailable',
      (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Near me'),
    );
    expect(tile.enabled, isFalse);
    expect(find.text('Turn on location to use this'), findsOneWidget);
  });

  testWidgets('Near me is enabled once a fix is available', (tester) async {
    await tester.pumpWidget(
      _app(const [], locationFix: const LocationAvailable(8.0119, 98.8378)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Near me'),
    );
    expect(tile.enabled, isTrue);
  });

  testWidgets('Near a saved place is disabled with no located places',
      (tester) async {
    await tester.pumpWidget(_app([_p('No location')]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Near a saved place'),
    );
    expect(tile.enabled, isFalse);
    expect(find.text('No saved places with a location yet'), findsOneWidget);
  });

  testWidgets('Near a saved place lists only located places', (tester) async {
    await tester.pumpWidget(
      _app([
        _p('No location'),
        _p('Hotel', lat: 8.0119, lng: 98.8378),
      ]),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Near a saved place'));
    await tester.pumpAndSettle();

    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('No location'), findsNothing);
  });
}
