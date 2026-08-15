import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/files/file_vault_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_form_screen.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_trip_repository.dart';

final _today = DateTime(2026, 7, 19);

/// A [FileVaultService] whose `delete` is an instant no-op. This screen's
/// tests exist to verify UI + state wiring, not real file-deletion
/// mechanics (already covered, with no `Image.file` involved, by
/// `file_vault_service_test.dart`) — using the real, disk-backed service
/// here made these tests dependent on Windows file-lock timing after
/// `Image.file` decodes a photo, which proved unreliable across multiple
/// attempts to fix. `import`/`exists`/`sweepOrphans` stay inherited from
/// the real implementation; they're unexercised by these tests.
class _InstantDeleteFileVaultService extends FileVaultService {
  _InstantDeleteFileVaultService()
      : super(() async => Directory.systemTemp, subfolder: 'covers-noop');

  @override
  Future<void> delete(String vaultPath) async {}
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trip_form_cover_test');
  });

  tearDown(() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows may still hold a lock a beat after the image cache is
      // cleared — it's a temp dir, so the OS reclaims it eventually.
    }
  });

  // _save() pops via go_router's context.pop() (GoRouterHelper), which
  // requires a real GoRouter ancestor — unlike Navigator.pop(), it throws
  // "No GoRouter found in context" under a plain MaterialApp. Mirrors the
  // nested /trips/new and /trips/:id/edit routes from app_router.dart, and
  // the same test pattern already used in trip_list_screen_test.dart.
  GoRouter router({Trip? initial}) => GoRouter(
        initialLocation:
            initial == null ? '/trips/new' : '/trips/${initial.id}/edit',
        routes: [
          GoRoute(
            path: '/trips',
            builder: (context, state) =>
                const Scaffold(body: Text('trips-list')),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => TripFormScreen(initial: initial),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    const Scaffold(body: Text('trip-detail')),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) =>
                        TripFormScreen(initial: initial),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  Future<Widget> app(FakeTripRepository repo, {Trip? initial}) async =>
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repo),
          coverPhotoFileServiceProvider
              .overrideWithValue(_InstantDeleteFileVaultService()),
          clockProvider.overrideWithValue(() => _today),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router(initial: initial),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      );

  File writeCoverPhoto() {
    return File('${tempDir.path}/source-cover.png')
      ..writeAsBytesSync(const <int>[137, 80, 78, 71]);
  }

  testWidgets('new trip shows the empty cover-photo placeholder',
      (tester) async {
    await tester.pumpWidget(await app(FakeTripRepository([])));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
      'editing a trip with an existing cover photo shows it and a clear button',
      (tester) async {
    final photo = writeCoverPhoto();
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    await tester.pumpWidget(
      await app(FakeTripRepository([trip]), initial: trip),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
  });

  testWidgets('clearing the cover photo reverts to the empty placeholder',
      (tester) async {
    final photo = writeCoverPhoto();
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    await tester.pumpWidget(
      await app(FakeTripRepository([trip]), initial: trip),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
  });

  testWidgets('saving without touching the photo keeps it unchanged',
      (tester) async {
    final photo = writeCoverPhoto();
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    final repo = FakeTripRepository([trip]);
    await tester.pumpWidget(await app(repo, initial: trip));
    await tester.pumpAndSettle();

    // The cover-photo section pushes Save below the default test viewport
    // (it's still onscreen on a real device — this is a scrollable form).
    await tester.ensureVisible(find.text('Save', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getTrip('t1');
    expect(saved!.coverPhotoPath, photo.path);
  });

  testWidgets('saving after clearing the photo persists null', (tester) async {
    final photo = writeCoverPhoto();
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      coverPhotoPath: photo.path,
    );
    final repo = FakeTripRepository([trip]);
    await tester.pumpWidget(await app(repo, initial: trip));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    // The cover-photo section pushes Save below the default test viewport
    // (it's still onscreen on a real device — this is a scrollable form).
    await tester.ensureVisible(find.text('Save', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getTrip('t1');
    expect(saved!.coverPhotoPath, isNull);
  });
}
