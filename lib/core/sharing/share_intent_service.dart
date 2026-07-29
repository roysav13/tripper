import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// A file shared into Tripper from another app (Gmail attachment, gallery…).
class IncomingSharedFile {
  const IncomingSharedFile(this.path);

  final String path;
}

/// One batch of shared content: document files and/or plain text
/// (Google Maps links become places; other text is ignored downstream).
class IncomingShare {
  const IncomingShare({this.files = const [], this.texts = const []});

  final List<IncomingSharedFile> files;
  final List<String> texts;

  bool get isEmpty => files.isEmpty && texts.isEmpty;
}

/// Pure mapping, unit-testable.
IncomingShare mapSharedMedia(List<SharedMediaFile> media) {
  return IncomingShare(
    files: [
      for (final m in media)
        if (m.type == SharedMediaType.file || m.type == SharedMediaType.image)
          IncomingSharedFile(m.path),
    ],
    texts: [
      for (final m in media)
        if (m.type == SharedMediaType.text || m.type == SharedMediaType.url)
          m.path,
    ],
  );
}

/// Emits both the cold-start share (app launched by the intent) and warm
/// shares (app already running) — Android delivers them differently.
final incomingSharesProvider = StreamProvider<IncomingShare>((ref) {
  final controller = StreamController<IncomingShare>();
  StreamSubscription<List<SharedMediaFile>>? sub;

  // The plugin has no implementation off-device (tests, desktop): treat any
  // failure as "nothing was shared" rather than letting it surface.
  try {
    ReceiveSharingIntent.instance.getInitialMedia().then((media) {
      final share = mapSharedMedia(media);
      if (!share.isEmpty && !controller.isClosed) controller.add(share);
      // Consume so a hot restart doesn't re-deliver.
      ReceiveSharingIntent.instance.reset();
    }).catchError((Object _) {});

    sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (media) {
        final share = mapSharedMedia(media);
        if (!share.isEmpty && !controller.isClosed) controller.add(share);
      },
      onError: (Object _) {},
      cancelOnError: false,
    );
  } catch (_) {
    // Missing plugin — the app simply never receives shares.
  }

  ref.onDispose(() {
    sub?.cancel();
    controller.close();
  });
  return controller.stream;
});
