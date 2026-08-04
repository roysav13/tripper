import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/files/file_vault_service.dart';
import '../../places/domain/place.dart';
import '../../places/presentation/place_providers.dart';
import '../data/journal_dao.dart';
import '../data/journal_repository.dart';
import '../domain/journal_entry.dart';

final journalDaoProvider =
    Provider<JournalDao>((ref) => ref.watch(databaseProvider).journalDao);

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => DriftJournalRepository(
    ref.watch(journalDaoProvider),
    ref.watch(fileVaultServiceProvider),
    ref.watch(clockProvider),
    () => const Uuid().v4(),
  ),
);

final tripJournalProvider = StreamProvider.family<List<JournalEntry>, String>(
  (ref, tripId) => ref.watch(journalRepositoryProvider).watchForTrip(tripId),
);

/// Feeds the globe/map — reuses Places' data, scoped to the trip and
/// filtered to visited+located. Journal never owns place data.
final tripVisitedPlacesProvider = Provider.family<List<Place>, String>((
  ref,
  tripId,
) {
  final places = ref.watch(tripPlacesProvider(tripId)).valueOrNull ?? const [];
  return places.where((p) => p.isVisited && p.hasLocation).toList();
});

/// Timeline <-> map toggle on the Journal tab, session-scoped. Mirrors
/// placesMapModeProvider.
final journalMapModeProvider = StateProvider<bool>((ref) => false);
