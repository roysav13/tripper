import 'checkin_notifications.dart' show kDepartureTimeDetailKey;
import 'document.dart';

/// Append-only — stored nowhere on disk, but new fields should still only
/// ever be appended (matches the append-only discipline used for the
/// persisted enums in this feature).
enum DocumentSortField { createdDate, relevantDate }

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

int compareDocumentsByCreatedDate(Document a, Document b) =>
    a.createdAt.compareTo(b.createdAt);

/// Only ever called on documents with a non-null [relevantDateOf] — the
/// sort engine partitions valueless items out via `hasValue` before this
/// runs.
int compareDocumentsByRelevantDate(Document a, Document b) =>
    relevantDateOf(a)!.compareTo(relevantDateOf(b)!);
