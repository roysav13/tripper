import 'package:flutter/foundation.dart';

@immutable
class JournalPhoto {
  const JournalPhoto({required this.id, required this.filePath});

  final String id;

  /// Vault path — see FileVaultService.
  final String filePath;

  @override
  bool operator ==(Object other) =>
      other is JournalPhoto && other.id == id && other.filePath == filePath;

  @override
  int get hashCode => Object.hash(id, filePath);
}
