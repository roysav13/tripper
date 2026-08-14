import 'checkin_notifications.dart' show kDepartureTimeDetailKey;
import 'document.dart';

enum DocumentSortOrder { createdDate, relevantDate }

/// The single date that matters most for a document: its expiry when set
/// (passport/visa/insurance/etc.), else a flight's parsed departure time,
/// else null — a manual record or a flight with no departure logged yet
/// has no relevant date at all.
DateTime? relevantDateOf(Document doc) {
  if (doc.expiryDate != null) return doc.expiryDate;
  if (doc.category != DocumentCategory.flight) return null;
  final raw = doc.details[kDepartureTimeDetailKey];
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

/// Pure — unit-tested without widgets. [DocumentSortOrder.createdDate]
/// orders newest first; [DocumentSortOrder.relevantDate] orders soonest
/// first with dateless documents pushed to the end, tiebroken by
/// createdAt (newest first, matching the createdDate order).
List<Document> sortDocuments(List<Document> docs, DocumentSortOrder order) {
  final sorted = [...docs];
  switch (order) {
    case DocumentSortOrder.createdDate:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case DocumentSortOrder.relevantDate:
      sorted.sort((a, b) {
        final ad = relevantDateOf(a), bd = relevantDateOf(b);
        if (ad == null && bd == null) return b.createdAt.compareTo(a.createdAt);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
  }
  return sorted;
}

/// Documents matching the filter: an empty set means no filtering.
/// Pure — unit-tested without widgets.
List<Document> filterDocumentsByCategory(
  List<Document> docs,
  Set<DocumentCategory> categories,
) {
  return [
    for (final d in docs)
      if (categories.isEmpty || categories.contains(d.category)) d,
  ];
}
