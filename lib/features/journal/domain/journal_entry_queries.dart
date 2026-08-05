import 'journal_entry.dart';

/// The chronologically-latest located entry, or null if none are located.
/// Used by the globe to decide what to focus on when it opens or when a
/// new entry is logged.
JournalEntry? latestLocatedEntry(List<JournalEntry> entries) {
  JournalEntry? latest;
  for (final entry in entries) {
    if (!entry.hasLocation) continue;
    if (latest == null || entry.loggedAt.isAfter(latest.loggedAt)) {
      latest = entry;
    }
  }
  return latest;
}

/// Consecutive pairs of located entries in chronological order — the
/// journey line's segments on the globe.
List<(JournalEntry, JournalEntry)> journeyConnections(
  List<JournalEntry> entries,
) {
  final located = entries.where((e) => e.hasLocation).toList()
    ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  return [
    for (var i = 0; i < located.length - 1; i++) (located[i], located[i + 1]),
  ];
}

/// [entries] grouped by the local calendar day of [JournalEntry.loggedAt],
/// oldest day first; entries within a day keep their relative order from
/// [entries] (the caller is expected to already pass entries in
/// chronological order — [JournalRepository.watchForTrip] does). Used by
/// the gallery timeline to decide which entries share one day-slot.
List<List<JournalEntry>> groupEntriesByDay(List<JournalEntry> entries) {
  final byDay = <DateTime, List<JournalEntry>>{};
  final order = <DateTime>[];
  for (final entry in entries) {
    final day = DateTime(
      entry.loggedAt.year,
      entry.loggedAt.month,
      entry.loggedAt.day,
    );
    if (!byDay.containsKey(day)) {
      order.add(day);
      byDay[day] = [];
    }
    byDay[day]!.add(entry);
  }
  order.sort();
  return [for (final day in order) byDay[day]!];
}
