import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_provider.dart';
import '../data/packing_dao.dart';
import '../data/packing_repository.dart';
import '../domain/packing_template.dart';
import '../domain/trip_packing_item.dart';

const _uuid = Uuid();

final packingDaoProvider =
    Provider<PackingDao>((ref) => ref.watch(databaseProvider).packingDao);

final packingRepositoryProvider = Provider<PackingRepository>(
  (ref) => DriftPackingRepository(ref.watch(packingDaoProvider), _uuid.v4),
);

final packingTemplatesProvider = StreamProvider<List<PackingTemplate>>(
  (ref) => ref.watch(packingRepositoryProvider).watchTemplates(),
);

final packingTemplateItemsProvider =
    StreamProvider.family<List<PackingTemplateItem>, String>(
  (ref, templateId) =>
      ref.watch(packingRepositoryProvider).watchTemplateItems(templateId),
);

final tripPackingItemsProvider =
    StreamProvider.family<List<TripPackingItem>, String>(
  (ref, tripId) => ref.watch(packingRepositoryProvider).watchTripItems(tripId),
);
