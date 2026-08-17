import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/location/location_providers.dart';
import 'package:tripper/core/location/location_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/presentation/place_distance_sort_status.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_location_service.dart';

class _NeverCompletingLocationService implements LocationService {
  @override
  Future<LocationFix> getCurrentLocation() => Completer<LocationFix>().future;
}

Widget _app(LocationService service) => ProviderScope(
      overrides: [locationServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: PlaceDistanceSortStatus()),
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
  testWidgets('shows a fetching status before the fix resolves',
      (tester) async {
    await tester.pumpWidget(_app(_NeverCompletingLocationService()));
    await tester.pump();
    expect(find.text('Fetching your location…'), findsOneWidget);
  });

  testWidgets('renders nothing once a fix is available', (tester) async {
    await tester.pumpWidget(
      _app(FakeLocationService(const LocationAvailable(1, 1))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fetching your location…'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('permission denied shows a message and a working Retry',
      (tester) async {
    final service = FakeLocationService(
      const LocationUnavailable(LocationUnavailableReason.permissionDenied),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(
      find.text('Allow location access to sort by distance'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.callCount, 2);
  });

  testWidgets('service disabled shows a Settings action', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeLocationService(
          const LocationUnavailable(
            LocationUnavailableReason.serviceDisabled,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Turn on location services to sort by distance'),
      findsOneWidget,
    );
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('permission denied forever shows a Settings action',
      (tester) async {
    await tester.pumpWidget(
      _app(
        FakeLocationService(
          const LocationUnavailable(
            LocationUnavailableReason.permissionDeniedForever,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Allow location access to sort by distance'),
      findsOneWidget,
    );
    expect(find.text('Settings'), findsOneWidget);
  });
}
