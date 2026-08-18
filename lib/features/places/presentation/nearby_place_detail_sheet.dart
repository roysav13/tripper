import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/trip_providers.dart';
import '../data/place_summary_service.dart';
import '../domain/nearby_place.dart';
import 'place_providers.dart';
import 'place_widgets.dart';

/// Detail sheet reached by tapping a Near By result: rating/distance,
/// a lazily-fetched Wikipedia summary to help decide, an editable name,
/// an optional day tag (only for a fully-dated trip), and the "Add to
/// wishlist" action.
Future<void> showNearbyPlaceDetailSheet(
  BuildContext context, {
  required NearbyPlaceResult result,
  required double distanceKm,
  String? tripId,
}) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _NearbyPlaceDetailSheet(
        result: result,
        distanceKm: distanceKm,
        tripId: tripId,
      ),
    ),
  );
}

class _NearbyPlaceDetailSheet extends ConsumerStatefulWidget {
  const _NearbyPlaceDetailSheet({
    required this.result,
    required this.distanceKm,
    required this.tripId,
  });

  final NearbyPlaceResult result;
  final double distanceKm;
  final String? tripId;

  @override
  ConsumerState<_NearbyPlaceDetailSheet> createState() =>
      _NearbyPlaceDetailSheetState();
}

class _NearbyPlaceDetailSheetState
    extends ConsumerState<_NearbyPlaceDetailSheet> {
  late final TextEditingController _name;
  DateTime? _plannedDate;
  bool _saving = false;

  bool _summaryLoading = true;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.result.name);
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    final summary = await ref.read(placeSummaryFetcherProvider).fetchSummary(
          name: widget.result.name,
          lat: widget.result.lat,
          lng: widget.result.lng,
        );
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _summaryLoading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final category = nearbyCategoryFor(widget.result.primaryType);

    Trip? trip;
    if (widget.tripId != null) {
      for (final t
          in ref.watch(tripListProvider).valueOrNull ?? const <Trip>[]) {
        if (t.id == widget.tripId) {
          trip = t;
          break;
        }
      }
    }
    final showDayPicker =
        trip != null && trip.startDate != null && trip.endDate != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  category == null
                      ? Icons.place_outlined
                      : placeCategoryIcon(category),
                  color: colors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.result.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            MonoText(
              '${widget.result.rating.toStringAsFixed(1)} '
              '(${widget.result.userRatingCount}) · '
              '${formatPlaceDistance(l10n, widget.distanceKm)}',
              muted: true,
            ),
            if (_summaryLoading) ...[
              const SizedBox(height: AppSpacing.md),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else if (_summary != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_summary!, style: TextStyle(color: colors.inkSecondary)),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.placeFormName),
            ),
            if (showDayPicker) ...[
              const SizedBox(height: AppSpacing.md),
              _DayPicker(
                trip: trip,
                value: _plannedDate,
                onChanged: (date) => setState(() => _plannedDate = date),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.nearbyAddToWishlist),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Read the repo/fetcher before the await — `ref` isn't safe to touch
    // once this state has been popped and disposed, but the fetch below
    // deliberately keeps running after that (see `unawaited` below).
    final repo = ref.read(placeRepositoryProvider);
    final summaryFetcher = ref.read(placeSummaryFetcherProvider);
    final name = _name.text.trim().isEmpty ? widget.result.name : _name.text;
    final id = await repo.createPlace(
      name: name,
      lat: widget.result.lat,
      lng: widget.result.lng,
      tripId: widget.tripId,
      category: nearbyCategoryFor(widget.result.primaryType),
      plannedDate: _plannedDate,
    );
    if (!_summaryLoading) {
      await repo.setSummary(id, summary: _summary);
    } else {
      // The summary hasn't resolved yet — same fire-and-forget path the
      // manual add flow uses; the save itself doesn't wait on it.
      unawaited(
        fetchAndStorePlaceSummary(
          fetcher: summaryFetcher,
          repo: repo,
          placeId: id,
          name: widget.result.name,
          lat: widget.result.lat,
          lng: widget.result.lng,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.trip,
    required this.value,
    required this.onChanged,
  });

  final Trip trip;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayLabel = value == null
        ? l10n.nearbyDayPickerPrompt
        : l10n.nearbyDayNumber(trip.dayNumber(value!)!);

    return OutlinedButton.icon(
      icon: const Icon(Icons.event_outlined, size: 16),
      label: Text(dayLabel),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? trip.startDate!,
          firstDate: trip.startDate!,
          lastDate: trip.endDate!,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
