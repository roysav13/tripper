import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../files/local_file_store.dart';

/// `pickedFileImage(source)` — a preview of a file the user just picked
/// but that has not been stored yet. Android hands pickers a filesystem
/// path, the web hands them a `blob:` URL, and the two need different
/// [ImageProvider]s.
export 'picked_file_image_io.dart'
    if (dart.library.js_interop) 'picked_file_image_web.dart'
    show pickedFileImage;

/// Displays a file held by a [LocalFileStore], by its storage key.
///
/// This exists because `Image.file` cannot work on the web, where our
/// files live in IndexedDB rather than on a filesystem. Going through the
/// store keeps every photo widget platform-agnostic and, unlike
/// `FileImage`, also covers `photo_view`, which insists on an
/// [ImageProvider] rather than a widget.
///
/// Reading the whole file before decoding costs one extra copy versus
/// `FileImage` on Android. That is deliberate: stored files are capped at
/// [kMaxVaultFileBytes] and the decoded bitmap dwarfs the encoded bytes
/// anyway, so a single implementation beats two divergent ones.
@immutable
class LocalFileImage extends ImageProvider<LocalFileImage> {
  const LocalFileImage(this.storageKey, this.store, {this.scale = 1.0});

  /// Key as handed out by [store] and persisted in the database.
  final String storageKey;

  final LocalFileStore store;
  final double scale;

  @override
  Future<LocalFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<LocalFileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    LocalFileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _decode(key, decode),
      scale: key.scale,
      debugLabel: key.storageKey,
      informationCollector: () => [
        ErrorDescription('Local file key: ${key.storageKey}'),
      ],
    );
  }

  Future<ui.Codec> _decode(
    LocalFileImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await key.store.read(key.storageKey);
    if (bytes == null || bytes.isEmpty) {
      // Evict so a later retry (after a backup restore, say) re-reads
      // instead of being served this failure out of the image cache.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      throw StateError('No stored file for key "${key.storageKey}"');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  // The store is deliberately not part of identity: a key already names
  // its namespace, so two stores can never hand out the same one, and
  // leaving it out keeps cache hits working across rebuilds that
  // construct a fresh store object.
  @override
  bool operator ==(Object other) =>
      other is LocalFileImage &&
      other.storageKey == storageKey &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(storageKey, scale);

  @override
  String toString() => 'LocalFileImage("$storageKey", scale: $scale)';
}
