import 'package:flutter/foundation.dart';

/// Order is stable — stored as index in the DB. Append only.
enum DocumentCategory {
  passportId,
  visa,
  flight,
  stay,
  insurance,
  transport,
  other,
}

@immutable
class Document {
  const Document({
    required this.id,
    required this.title,
    required this.category,
    this.filePath,
    this.mimeType,
    this.expiryDate,
    this.isGlobal = false,
    this.isPinned = false,
    this.details = const {},
    this.tripIds = const [],
  });

  final String id;
  final String title;
  final DocumentCategory category;

  /// Null = manual record (confirmation code typed in, no file).
  final String? filePath;
  final String? mimeType;
  final DateTime? expiryDate;
  final bool isGlobal;
  final bool isPinned;

  /// Category-specific fields: flightNumber, confirmationCode, bookingRef…
  final Map<String, String> details;

  /// Trips this document is linked to (global docs link to many).
  final List<String> tripIds;

  bool get hasFile => filePath != null;

  Document copyWith({
    String? title,
    DocumentCategory? category,
    String? Function()? filePath,
    String? Function()? mimeType,
    DateTime? Function()? expiryDate,
    bool? isGlobal,
    bool? isPinned,
    Map<String, String>? details,
    List<String>? tripIds,
  }) {
    return Document(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      filePath: filePath == null ? this.filePath : filePath(),
      mimeType: mimeType == null ? this.mimeType : mimeType(),
      expiryDate: expiryDate == null ? this.expiryDate : expiryDate(),
      isGlobal: isGlobal ?? this.isGlobal,
      isPinned: isPinned ?? this.isPinned,
      details: details ?? this.details,
      tripIds: tripIds ?? this.tripIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Document &&
      other.id == id &&
      other.title == title &&
      other.category == category &&
      other.filePath == filePath &&
      other.mimeType == mimeType &&
      other.expiryDate == expiryDate &&
      other.isGlobal == isGlobal &&
      other.isPinned == isPinned &&
      mapEquals(other.details, details) &&
      listEquals(other.tripIds, tripIds);

  @override
  int get hashCode => Object.hash(
        id,
        title,
        category,
        filePath,
        mimeType,
        expiryDate,
        isGlobal,
        isPinned,
        Object.hashAll(details.entries.map((e) => Object.hash(e.key, e.value))),
        Object.hashAll(tripIds),
      );
}
