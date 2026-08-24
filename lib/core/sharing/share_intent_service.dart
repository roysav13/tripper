import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'share_intent_source_io.dart'
    if (dart.library.js_interop) 'share_intent_source_web.dart';

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

/// Shares arriving from the OS. Android delivers real ones; the web build
/// has no equivalent and this never emits (see
/// `share_intent_source_web.dart`).
final incomingSharesProvider =
    StreamProvider<IncomingShare>((ref) => watchIncomingShares());
