import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../places/data/geocoding_service.dart';
import '../../places/data/place_summary_service.dart';
import '../../places/domain/place.dart';
import '../../places/presentation/map_style.dart';
import '../../places/presentation/place_providers.dart';

class JournalLocationPick {
  const JournalLocationPick({
    required this.lat,
    required this.lng,
    this.placeName,
    this.placeId,
  });

  final double lat;
  final double lng;
  final String? placeName;
  final String? placeId;
}

/// Full-screen location picker for a journal entry: pick one of this trip's
/// existing locations, search as you type (network-enhanced), or long-press
/// the map to drop a pin (fully offline) — same dual-path pattern as
/// AddPlaceScreen, so search failing never blocks picking a location
/// (CLAUDE.md: network may enhance, never gate). A brand-new named location
/// picked via search is automatically added to the trip's Places on save.
class JournalLocationPicker extends ConsumerStatefulWidget {
  const JournalLocationPicker({
    super.key,
    required this.tripId,
    this.initialLat,
    this.initialLng,
    this.initialPlaceName,
    this.initialPlaceId,
    this.renderMap = true,
  });

  final String tripId;
  final double? initialLat;
  final double? initialLng;
  final String? initialPlaceName;
  final String? initialPlaceId;

  /// False in widget tests: Google Maps needs a platform view.
  final bool renderMap;

  static Future<JournalLocationPick?> open(
    BuildContext context, {
    required String tripId,
    double? initialLat,
    double? initialLng,
    String? initialPlaceName,
    String? initialPlaceId,
  }) {
    return Navigator.of(context, rootNavigator: true)
        .push<JournalLocationPick?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => JournalLocationPicker(
          tripId: tripId,
          initialLat: initialLat,
          initialLng: initialLng,
          initialPlaceName: initialPlaceName,
          initialPlaceId: initialPlaceId,
        ),
      ),
    );
  }

  @override
  ConsumerState<JournalLocationPicker> createState() =>
      _JournalLocationPickerState();
}

class _JournalLocationPickerState extends ConsumerState<JournalLocationPicker> {
  GoogleMapController? _mapController;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  List<GeoResult> _results = const [];
  bool _searching = false;
  String? _searchError;

  LatLng? _picked;
  String? _placeName;

  /// Set when the pick came from the trip's existing Places (chip tap) —
  /// skips auto-adding a duplicate Place on save.
  String? _pickedPlaceId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
    }
    _placeName = widget.initialPlaceName;
    _pickedPlaceId = widget.initialPlaceId;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final tripPlaces =
        (ref.watch(tripPlacesProvider(widget.tripId)).valueOrNull ??
                const <Place>[])
            .where((p) => p.hasLocation)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _search,
          focusNode: _searchFocus,
          autofocus: _picked == null,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.mapSearchHint,
            border: InputBorder.none,
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _onQueryChanged,
          onSubmitted: (_) => _runSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.renderMap)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _picked ?? const LatLng(25, 15),
                zoom: _picked == null ? 2 : 13,
              ),
              style: Theme.of(context).brightness == Brightness.dark
                  ? kMapStyleDark
                  : kMapStyleLight,
              mapToolbarEnabled: false,
              zoomControlsEnabled: true,
              onMapCreated: (controller) => _mapController = controller,
              onLongPress: (latLng) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _picked = latLng;
                  _placeName = null;
                  _pickedPlaceId = null;
                  _results = const [];
                  _searchError = null;
                });
              },
              markers: {
                if (_picked != null)
                  Marker(
                    markerId: const MarkerId('picked'),
                    position: _picked!,
                  ),
              },
            )
          else
            ColoredBox(color: colors.paper, child: const SizedBox.expand()),
          if (_results.isEmpty && _searchError == null && tripPlaces.isNotEmpty)
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: Material(
                color: colors.surface,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Text(
                          l10n.journalTripLocations,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          children: [
                            for (final place in tripPlaces)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: AppSpacing.sm,
                                ),
                                child: ChoiceChip(
                                  label: Text(place.name),
                                  selected: _pickedPlaceId == place.id,
                                  onSelected: (_) => _selectTripPlace(place),
                                ),
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: Text(l10n.journalNewLocation),
                              onPressed: () => _searchFocus.requestFocus(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_picked == null && _results.isEmpty && tripPlaces.isEmpty)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 24,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.hairline, width: 0.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      l10n.pickOnMapHint,
                      style:
                          TextStyle(fontSize: 13, color: colors.inkSecondary),
                    ),
                  ),
                ),
              ),
            ),
          if (_results.isNotEmpty || _searchError != null)
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: Material(
                color: colors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_searchError != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                        child: Text(
                          _searchError!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.inkSecondary,
                          ),
                        ),
                      ),
                    for (final result in _results)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: colors.accent,
                        ),
                        title: Text(
                          result.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          result.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: colors.inkMuted),
                        ),
                        onTap: () => _selectResult(result),
                      ),
                    Divider(height: 0.5, color: colors.hairline),
                  ],
                ),
              ),
            ),
          if (_picked != null)
            PositionedDirectional(
              start: AppSpacing.md,
              end: AppSpacing.md,
              bottom: 0,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(context).viewPadding.bottom + AppSpacing.md,
                ),
                child: FilledButton(
                  onPressed: _saving ? null : () => _confirmPick(tripPlaces),
                  child: Text(l10n.save),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 500), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _search.text.trim();
    if (query.isEmpty || _searching) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await ref.read(geocoderProvider).search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searchError = results.isEmpty ? l10n.mapSearchNoResults : null;
      });
    } on GeocodingException catch (e) {
      debugPrint('[journal] location search failed: $e');
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searchError = l10n.mapSearchOffline;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectResult(GeoResult result) async {
    FocusScope.of(context).unfocus();
    var resolved = result;
    if (result.needsDetails) {
      setState(() => _searching = true);
      try {
        resolved =
            await ref.read(geocoderProvider).details(result.placeId!) ?? result;
      } on GeocodingException catch (e) {
        debugPrint('[journal] location details failed: $e');
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    }
    if (!mounted || resolved.needsDetails) return;

    setState(() {
      _picked = LatLng(resolved.lat, resolved.lon);
      _placeName = resolved.name;
      _pickedPlaceId = null;
      _results = const [];
      _searchError = null;
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(resolved.lat, resolved.lon), 14),
    );
  }

  Future<void> _selectTripPlace(Place place) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _picked = LatLng(place.lat!, place.lng!);
      _placeName = place.name;
      _pickedPlaceId = place.id;
      _results = const [];
      _searchError = null;
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place.lat!, place.lng!), 14),
    );
  }

  /// A brand-new named location (search result, not one of the trip's
  /// existing Places) is added to the trip's Places on save, so it shows
  /// up as visited on future pickers, the Places tab, and the globe. An
  /// existing trip Place picked via chip that isn't visited yet is now
  /// also marked visited here (previously only brand-new places were).
  /// A bare map pin has no name to give a Place, so it's stored on the
  /// entry only.
  Future<void> _confirmPick(List<Place> tripPlaces) async {
    final picked = _picked!;
    final name = _placeName;
    final isNewNamedPlace = _pickedPlaceId == null &&
        name != null &&
        !tripPlaces.any(
          (p) => p.name.trim().toLowerCase() == name.trim().toLowerCase(),
        );

    var placeId = _pickedPlaceId;
    if (isNewNamedPlace) {
      setState(() => _saving = true);
      final places = ref.read(placeRepositoryProvider);
      // Read before the awaits below — `ref` isn't safe to touch once
      // this screen has popped and disposed, but the summary fetch below
      // deliberately keeps running after that (see `unawaited`).
      final summaryFetcher = ref.read(placeSummaryFetcherProvider);
      placeId = await places.createPlace(
        name: name,
        lat: picked.latitude,
        lng: picked.longitude,
        tripId: widget.tripId,
      );
      await places.setVisited(
        placeId,
        visited: true,
        visitedOn: ref.read(clockProvider)(),
      );
      // Enhancement, not a gate (CLAUDE.md hard rule 4) — doesn't block
      // this flow, and any failure just leaves the summary empty.
      unawaited(
        fetchAndStorePlaceSummary(
          fetcher: summaryFetcher,
          repo: places,
          placeId: placeId,
          name: name,
          lat: picked.latitude,
          lng: picked.longitude,
        ),
      );
    } else if (placeId != null) {
      final existing = tripPlaces.firstWhere((p) => p.id == placeId);
      if (!existing.isVisited) {
        setState(() => _saving = true);
        await ref.read(placeRepositoryProvider).setVisited(
              placeId,
              visited: true,
              visitedOn: ref.read(clockProvider)(),
            );
      }
    }

    if (mounted) {
      Navigator.of(context).pop(
        JournalLocationPick(
          lat: picked.latitude,
          lng: picked.longitude,
          placeName: _placeName,
          placeId: placeId,
        ),
      );
    }
  }
}
