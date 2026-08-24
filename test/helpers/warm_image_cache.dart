import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:tripper/core/files/file_vault_service.dart';
import 'package:tripper/core/widgets/local_images.dart';

/// Decodes the file at [storageKey] and seats it in the global
/// [imageCache] via a real event-loop turn.
///
/// `flutter test`'s default binding runs widget code inside a fake-async
/// zone, so a disk-backed image never finishes decoding through plain
/// `pump`/`pumpAndSettle` alone — and photo_view's loading state is an
/// indeterminate [CircularProgressIndicator] whose repeating animation
/// then keeps `pumpAndSettle` from ever settling. Warming the cache here
/// (inside [WidgetTester.runAsync], which briefly runs in the real zone)
/// means the widget's own later `resolve()` is a cache hit that completes
/// synchronously within the same build pass.
///
/// Must be called inside `tester.runAsync`.
///
/// The store passed to [LocalFileImage] is irrelevant to cache identity —
/// equality is on the key alone — and `FileVaultService.read` opens the
/// key as an absolute path without consulting its base directory, so the
/// throwaway one below reads the same bytes the widget under test will.
Future<void> warmLocalImageCache(String storageKey) {
  final provider = LocalFileImage(
    storageKey,
    FileVaultService(() async => Directory.systemTemp),
  );
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, synchronousCall) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    },
    onError: (error, stackTrace) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return completer.future;
}
