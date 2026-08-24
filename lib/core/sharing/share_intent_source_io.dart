import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'share_intent_service.dart';

/// Emits both the cold-start share (app launched by the intent) and warm
/// shares (app already running) — Android delivers them differently.
Stream<IncomingShare> watchIncomingShares() {
  final controller = StreamController<IncomingShare>();
  StreamSubscription<List<SharedMediaFile>>? sub;

  // The plugin has no implementation off-device (tests, desktop): treat
  // any failure as "nothing was shared" rather than letting it surface.
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

  controller.onCancel = () async {
    await sub?.cancel();
  };
  return controller.stream;
}

/// Pure mapping, unit-testable. Lives here because [SharedMediaFile] is
/// an Android-plugin type that cannot be named in web-facing code.
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
