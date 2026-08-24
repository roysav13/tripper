import 'package:flutter/foundation.dart';

/// Whether data written locally actually survives the app being closed.
///
/// On Android this is always [durable] — the app documents directory is
/// real disk. On the web it depends on what the browser grants us: a
/// worker with OPFS or IndexedDB is durable, but a locked-down or
/// private-browsing context can leave drift with nothing but an
/// in-memory database, and the user must be told rather than losing a
/// trip's worth of notes silently (CLAUDE.md hard rule 4 — degrade
/// *visibly*).
enum StorageDurability {
  /// Survives a restart.
  durable,

  /// This session only — the browser refused persistent storage.
  ephemeral,

  /// Not determined yet; the database opens lazily on first query.
  unknown,
}

/// Set once by the platform database connection as it opens. Widgets can
/// listen to surface a warning banner.
final ValueNotifier<StorageDurability> storageDurability =
    ValueNotifier<StorageDurability>(StorageDurability.unknown);
