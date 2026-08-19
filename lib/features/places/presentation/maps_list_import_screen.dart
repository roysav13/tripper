import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sharing/maps_list_scraper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/error_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/presentation/trip_providers.dart';
import '../data/geocoding_service.dart';
import 'place_collection_providers.dart';
import 'place_providers.dart';

enum _Stage { scraping, failed, review, importing }

/// Reviews a scraped Google Maps list and imports the selected places, all
/// grouped into one new [PlaceCollection] named after the list (SPEC:
/// docs/superpowers/specs/2026-08-19-google-maps-list-share-design.md §4).
class MapsListImportScreen extends ConsumerStatefulWidget {
  const MapsListImportScreen({super.key, required this.url, this.nameGuess});

  final String url;
  final String? nameGuess;

  static Future<void> open(
    BuildContext context, {
    required String url,
    String? nameGuess,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) =>
            MapsListImportScreen(url: url, nameGuess: nameGuess),
      ),
    );
  }

  @override
  ConsumerState<MapsListImportScreen> createState() =>
      _MapsListImportScreenState();
}

class _MapsListImportScreenState extends ConsumerState<MapsListImportScreen> {
  _Stage _stage = _Stage.scraping;
  final _title = TextEditingController();
  bool _titleError = false;
  List<String> _names = const [];
  // Indices into _names, not names themselves -- a Set<String> would
  // collapse two literally-identical place names in the same list into
  // one togglable row, which is wrong (they're still two separate places
  // to import). Index-based selection keeps every row independently
  // checkable regardless of name collisions.
  final Set<int> _checked = {};
  String? _tripId;
  int _geocoded = 0;
  int _geocodeTotal = 0;

  @override
  void initState() {
    super.initState();
    _scrape();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _scrape() async {
    final result = await ref.read(mapsListScraperProvider).scrape(widget.url);
    if (!mounted) return;
    if (result == null || result.placeNames.isEmpty) {
      setState(() => _stage = _Stage.failed);
      return;
    }
    setState(() {
      _title.text = result.title ?? widget.nameGuess ?? '';
      _names = result.placeNames;
      _checked
        ..clear()
        ..addAll(List.generate(_names.length, (i) => i));
      _stage = _Stage.review;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapsListImportTitle)),
      body: switch (_stage) {
        _Stage.scraping => _progress(l10n.mapsListImportScraping),
        _Stage.failed => ErrorState(body: l10n.mapsListImportFailedBody),
        _Stage.review => _reviewBody(l10n),
        _Stage.importing => _progress(
            l10n.mapsListImportProgress(_geocoded, _geocodeTotal),
          ),
      },
    );
  }

  Widget _progress(String label) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(label),
          ],
        ),
      );

  Widget _reviewBody(AppLocalizations l10n) {
    final colors = context.colors;
    final trips = (ref.watch(tripListProvider).valueOrNull ?? [])
        .where((t) => !t.archived)
        .toList();
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.newListDialogNameLabel,
            errorText: _titleError ? l10n.errNameRequired : null,
          ),
        ),
        if (trips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding:
                      const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(l10n.placeFormNoTrip),
                    selected: _tripId == null,
                    onSelected: (_) => setState(() => _tripId = null),
                  ),
                ),
                for (final trip in trips)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(trip.name),
                      selected: _tripId == trip.id,
                      onSelected: (_) => setState(() => _tripId = trip.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // Plain (not MonoText): MonoText force-uppercases its rendered
        // text, which would turn "2 selected" into "2 SELECTED" and break
        // the sentence-case copy this ARB string was written for.
        Text(
          l10n.mapsListImportSelectedCount(_checked.length),
          style: AppTextStyles.mono.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _names.length; i++)
          CheckboxListTile(
            value: _checked.contains(i),
            title: Text(_names[i]),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _checked.add(i);
              } else {
                _checked.remove(i);
              }
            }),
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _checked.isEmpty ? null : _import,
          child: Text(l10n.mapsListImportButton(_checked.length)),
        ),
      ],
    );
  }

  static String _dedupeKey(String name) => name.trim().toLowerCase();

  Future<void> _import() async {
    final selected = [
      for (var i = 0; i < _names.length; i++)
        if (_checked.contains(i)) _names[i],
    ];
    if (selected.isEmpty) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }

    final uniqueKeys = selected.map(_dedupeKey).toSet();
    setState(() {
      _stage = _Stage.importing;
      _geocoded = 0;
      _geocodeTotal = uniqueKeys.length;
    });

    final geocoder = ref.read(geocoderProvider);
    final placeRepo = ref.read(placeRepositoryProvider);
    final collectionRepo = ref.read(placeCollectionRepositoryProvider);
    final tripId = _tripId;

    // One geocode call per *unique* name (SPEC §3) — Nominatim's usage
    // policy forbids bursts, hence the delay between calls.
    final geocoded = <String, GeoResult?>{};
    for (final key in uniqueKeys) {
      if (!mounted) return;
      final name = selected.firstWhere((n) => _dedupeKey(n) == key);
      GeoResult? hit;
      try {
        final results = await geocoder.search(name);
        var first = results.isEmpty ? null : results.first;
        if (first != null && first.needsDetails) {
          first = await geocoder.details(first.placeId!) ?? first;
        }
        hit = (first != null && !first.needsDetails) ? first : null;
      } catch (_) {
        hit = null;
      }
      if (!mounted) return;
      geocoded[key] = hit;
      setState(() => _geocoded++);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }

    if (!mounted) return;
    final placeIds = <String>[];
    for (final name in selected) {
      final hit = geocoded[_dedupeKey(name)];
      final id = await placeRepo.createPlace(
        name: name,
        country: hit?.country ?? '',
        city: hit?.city ?? '',
        lat: hit?.lat,
        lng: hit?.lon,
        tripId: tripId,
      );
      if (!mounted) return;
      placeIds.add(id);
    }

    final collectionId = await collectionRepo.createCollection(name: title);
    for (final id in placeIds) {
      if (!mounted) return;
      await collectionRepo.setCollectionsForPlace(id, {collectionId});
    }
    if (mounted) Navigator.of(context).pop();
  }
}
