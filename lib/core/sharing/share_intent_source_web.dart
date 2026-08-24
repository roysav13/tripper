import 'share_intent_service.dart';

/// Browsers have no "share into this app" intent that an installed PWA
/// can receive without a server-side share_target handler, so the web
/// build simply never sees an incoming share. Everything downstream
/// already treats "no shares" as the normal case.
Stream<IncomingShare> watchIncomingShares() =>
    const Stream<IncomingShare>.empty();
