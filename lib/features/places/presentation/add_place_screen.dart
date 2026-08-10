import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/presentation/trip_providers.dart';
import '../data/geocoding_service.dart';
import '../domain/place.dart';
import 'map_style.dart';
import 'place_providers.dart';
import 'place_widgets.dart';

/// One-screen add-place flow: search as you type, tap a result and a
/// prefilled save card slides up. Long-press drops a manual pin.
/// Offline / unmappable: "add without location" keeps the flow alive.
class AddPlaceScreen extends ConsumerStatefulWidget {
  const AddPlaceScreen({
    super.key,
    this.tripId,
    this.initialName,
    this.initialLat,
    this.initialLng,
    this.initialCountry,
    this.initialCity,
    this.initialNotes,
    this.renderMap = true,
  });

  final String? tripId;

  /// Prefill from a shared Google Maps link (SPEC §3.1).
  final String? initialName;
  final double? initialLat;
  final double? initialLng;
  final String? initialCountry;
  final String? initialCity;
  final String? initialNotes;

  /// False in widget tests: Google Maps needs a platform view.
  final bool renderMap;

  static Future<void> open(
    BuildContext context, {
    String? tripId,
    String? initialName,
    double? initialLat,
    double? initialLng,
    String? initialCountry,
    String? initialCity,
    String? initialNotes,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => AddPlaceScreen(
          tripId: tripId,
          initialName: initialName,
          initialLat: initialLat,
          initialLng: initialLng,
          initialCountry: initialCountry,
          initialCity: initialCity,
          initialNotes: initialNotes,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  GoogleMapController? _mapController;
  final _search = TextEditingController();
  final _name = TextEditingController();
  Timer? _debounce;

  List<GeoResult> _results = const [];
  bool _searching = false;
  String? _searchError;
  String _lastQuery = '';

  bool _composing = false;
  LatLng? _picked;
  String _country = '';
  String _city = '';
  String? _tripId;
  bool _nameError = false;
  bool _saving = false;

  final _description = TextEditingController();
  PlaceCategory? _category;

  @override
  void initState() {
    super.initState();
    _tripId = widget.tripId;
    // Shared Maps link: jump straight to the save card, prefilled.
    if (widget.initialName != null || widget.initialLat != null) {
      _composing = true;
      _name.text = widget.initialName ?? '';
      _description.text = widget.initialNotes ?? '';
      _country = widget.initialCountry ?? '';
      _city = widget.initialCity ?? '';
      if (widget.initialLat != null && widget.initialLng != null) {
        _picked = LatLng(widget.initialLat!, widget.initialLng!);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    _search.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _search,
          autofocus: true,
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
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: true,
              onMapCreated: (controller) => _mapController = controller,
              onLongPress: (latLng) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _picked = latLng;
                  _composing = true;
                  _country = '';
                  _city = '';
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
          if (!_composing && _picked == null && _results.isEmpty)
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
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.inkSecondary,
                      ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.inkMuted,
                          ),
                        ),
                        onTap: () => _selectResult(result),
                      ),
                    if (_searchError != null || _results.isEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.md,
                          end: AppSpacing.md,
                          bottom: AppSpacing.md,
                        ),
                        child: OutlinedButton(
                          onPressed: _addWithoutLocation,
                          child: Text(
                            l10n.addWithoutLocation(_lastQuery),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    Divider(height: 0.5, color: colors.hairline),
                  ],
                ),
              ),
            ),
          if (_composing)
            PositionedDirectional(
              start: AppSpacing.md,
              end: AppSpacing.md,
              bottom: 0,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                // Keyboard inset OR the system gesture-bar inset (edge-to-
                // edge), whichever is in play — plus breathing room.
                padding: EdgeInsets.only(
                  bottom: (MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context).viewInsets.bottom
                          : MediaQuery.of(context).viewPadding.bottom) +
                      AppSpacing.md,
                ),
                child: _saveCard(l10n, colors),
              ),
            ),
        ],
      ),
    );
  }

  Widget _saveCard(AppLocalizations l10n, AppColors colors) {
    final trips = (ref.watch(tripListProvider).valueOrNull ?? [])
        .where((t) => !t.archived)
        .toList();
    final metaParts = <String>[
      if (_city.isNotEmpty) _city,
      if (_country.isNotEmpty) _country,
      if (_picked == null) l10n.noLocationChip,
    ];
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.placeFormName,
              errorText: _nameError ? l10n.errNameRequired : null,
              isDense: true,
            ),
          ),
          if (metaParts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            MonoText(metaParts.join(' · '), muted: true),
          ],
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
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                      ),
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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final category in PlaceCategory.values)
                ChoiceChip(
                  avatar: Icon(placeCategoryIcon(category), size: 16),
                  label: Text(placeCategoryLabel(l10n, category)),
                  selected: _category == category,
                  onSelected: (_) => setState(
                    () => _category = _category == category ? null : category,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _description,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.placeFormDescription,
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.save),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: Icon(Icons.close, color: colors.inkMuted),
                tooltip: l10n.cancel,
                onPressed: () => setState(() {
                  _composing = false;
                  _picked = null;
                  _nameError = false;
                }),
              ),
            ],
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
      _lastQuery = query;
    });
    try {
      final results = await ref.read(geocoderProvider).search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searchError = results.isEmpty ? l10n.mapSearchNoResults : null;
      });
    } on GeocodingException catch (e) {
      // Reason is diagnostic-only — never shown to the user, but printed so
      // a real API/config error (bad key, API not enabled, no billing) can
      // be told apart from an actual dead network in the debug console.
      debugPrint('[places] search failed: $e');
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
    // Google autocomplete returns no coordinates — resolve them now (this
    // also closes the billing session for the typing that led here).
    if (result.needsDetails) {
      setState(() => _searching = true);
      try {
        resolved =
            await ref.read(geocoderProvider).details(result.placeId!) ?? result;
      } on GeocodingException catch (e) {
        // Keep the name; user can drop a pin manually.
        debugPrint('[places] details failed: $e');
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    }
    if (!mounted) return;

    final hasLocation = !resolved.needsDetails;
    setState(() {
      _picked = hasLocation ? LatLng(resolved.lat, resolved.lon) : null;
      _composing = true;
      _name.text = resolved.name;
      _country = resolved.country;
      _city = resolved.city;
      _results = const [];
      _searchError = null;
    });
    if (hasLocation) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(resolved.lat, resolved.lon), 14),
      );
    }
  }

  void _addWithoutLocation() {
    FocusScope.of(context).unfocus();
    setState(() {
      _picked = null;
      _composing = true;
      if (_name.text.trim().isEmpty) _name.text = _lastQuery;
      _country = '';
      _city = '';
      _results = const [];
      _searchError = null;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    setState(() => _saving = true);
    await ref.read(placeRepositoryProvider).createPlace(
          name: _name.text,
          country: _country,
          city: _city,
          lat: _picked?.latitude,
          lng: _picked?.longitude,
          tripId: _tripId,
          notes: _description.text,
          category: _category,
        );
    if (mounted) Navigator.of(context).pop();
  }
}
