import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../data/geocoding_service.dart' show GeocodingException;
import '../domain/nearby_place.dart';
import '../domain/place_sort.dart';
import 'nearby_place_detail_sheet.dart';
import 'place_providers.dart';
import 'place_widgets.dart';

enum _LoadState { initial, loading, loaded, error }

/// Pull-based results screen for Near By: no auto-fetch on open, no
/// refetch-on-anything (§5.10) — a single explicit "Find nearby" action.
class NearbyPlacesScreen extends ConsumerStatefulWidget {
  const NearbyPlacesScreen({
    super.key,
    required this.anchorLat,
    required this.anchorLng,
    this.tripId,
  });

  final double anchorLat;
  final double anchorLng;
  final String? tripId;

  @override
  ConsumerState<NearbyPlacesScreen> createState() =>
      _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends ConsumerState<NearbyPlacesScreen> {
  _LoadState _state = _LoadState.initial;
  List<NearbyPlaceResult> _results = const [];

  Future<void> _fetch() async {
    setState(() => _state = _LoadState.loading);
    try {
      final results = await ref.read(nearbyPlacesServiceProvider).search(
            lat: widget.anchorLat,
            lng: widget.anchorLng,
          );
      if (!mounted) return;
      setState(() {
        _results = results;
        _state = _LoadState.loaded;
      });
    } on GeocodingException catch (e) {
      debugPrint('[places] nearby search failed: $e');
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.nearbyResultsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _state == _LoadState.loading ? null : _fetch,
                child: _state == _LoadState.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.nearbyFindButton),
              ),
            ),
          ),
          Expanded(child: _body(l10n, colors)),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l10n, AppColors colors) {
    switch (_state) {
      case _LoadState.initial:
      case _LoadState.loading:
        return const SizedBox.shrink();
      case _LoadState.error:
        return ErrorState(onRetry: _fetch);
      case _LoadState.loaded:
        if (_results.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: l10n.nearbyEmptyTitle,
            body: l10n.nearbyEmptyBody,
            ctaLabel: l10n.nearbyFindButton,
            onCta: _fetch,
          );
        }
        return ListView.builder(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          itemCount: _results.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: _NearbyResultCard(
              result: _results[index],
              anchorLat: widget.anchorLat,
              anchorLng: widget.anchorLng,
              tripId: widget.tripId,
            ),
          ),
        );
    }
  }
}

class _NearbyResultCard extends StatelessWidget {
  const _NearbyResultCard({
    required this.result,
    required this.anchorLat,
    required this.anchorLng,
    required this.tripId,
  });

  final NearbyPlaceResult result;
  final double anchorLat;
  final double anchorLng;
  final String? tripId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final category = nearbyCategoryFor(result.primaryType);
    final distanceKm = distanceBetweenKm(
      lat1: anchorLat,
      lng1: anchorLng,
      lat2: result.lat,
      lng2: result.lng,
    );

    return PaperCard(
      onTap: () => showNearbyPlaceDetailSheet(
        context,
        result: result,
        distanceKm: distanceKm,
        tripId: tripId,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            category == null ? Icons.place_outlined : placeCategoryIcon(category),
            size: 20,
            color: colors.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                MonoText(
                  '${result.rating.toStringAsFixed(1)} '
                  '(${result.userRatingCount}) · '
                  '${formatPlaceDistance(l10n, distanceKm)}',
                  muted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
