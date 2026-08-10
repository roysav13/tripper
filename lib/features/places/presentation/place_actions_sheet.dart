import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/sharing/maps_link.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/presentation/trip_providers.dart';
import '../domain/place.dart';
import 'place_providers.dart';
import 'place_visit_actions.dart';
import 'place_widgets.dart';

/// Tap a place row or map pin -> actions: toggle visited, edit, delete.
Future<void> showPlaceActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Place place,
) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    builder: (context) => _PlaceActions(place: place),
  );
}

class _PlaceActions extends ConsumerWidget {
  const _PlaceActions({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final repo = ref.read(placeRepositoryProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                place.isVisited
                    ? Icons.check_circle_outline
                    : Icons.place_outlined,
                color: place.isVisited ? colors.inkMuted : colors.accent,
              ),
              title: Text(place.name),
              subtitle: Text(
                [
                  if (place.city.isNotEmpty) place.city,
                  if (place.country.isNotEmpty) place.country,
                ].join(' · '),
              ),
            ),
            if (place.notes.trim().isNotEmpty)
              Padding(
                key: const Key('place-description'),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  place.notes,
                  style: TextStyle(color: colors.inkSecondary),
                ),
              ),
            const Divider(),
            if (place.hasLocation) ...[
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(l10n.placeViewOnMap),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(placesMapModeProvider.notifier).state = true;
                  ref.read(selectedPlaceIdProvider.notifier).state = place.id;
                  // Works whether we're already on the Places tab (list
                  // view -> map view) or opened from a trip's Places tab
                  // (jumps to the Places branch of the bottom-nav shell).
                  context.go('/places');
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.placeOpenInGoogleMaps),
                onTap: () async {
                  // Resolve everything from context BEFORE the await —
                  // this sheet's own context becomes unreliable once the
                  // pop below settles, and launchUrl is a real async gap.
                  final messenger = ScaffoldMessenger.of(context);
                  final failedMessage = l10n.placeOpenMapsFailed;
                  Navigator.of(context).pop();
                  final launched = await launchUrl(
                    googleMapsUri(place.lat!, place.lng!),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched) {
                    messenger
                        .showSnackBar(SnackBar(content: Text(failedMessage)));
                  }
                },
              ),
            ],
            ListTile(
              leading: Icon(
                place.isVisited
                    ? Icons.remove_done
                    : Icons.check_circle_outline,
              ),
              title: Text(
                place.isVisited ? l10n.placeUnvisit : l10n.placeMarkVisited,
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await markPlaceVisited(ref, place, visited: !place.isVisited);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.menuEdit),
              onTap: () {
                Navigator.of(context).pop();
                _showEditSheet(context, ref, place);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.error),
              title: Text(
                l10n.menuDelete,
                style: TextStyle(color: colors.error),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.deletePlaceTitle),
                    content: Text(l10n.deletePlaceBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.menuDelete),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) await repo.deletePlace(place.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, Place place) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditPlaceForm(place: place),
      ),
    );
  }
}

class _EditPlaceForm extends ConsumerStatefulWidget {
  const _EditPlaceForm({required this.place});

  final Place place;

  @override
  ConsumerState<_EditPlaceForm> createState() => _EditPlaceFormState();
}

class _EditPlaceFormState extends ConsumerState<_EditPlaceForm> {
  late final TextEditingController _name;
  late final TextEditingController _country;
  late final TextEditingController _city;
  final _description = TextEditingController();
  String? _tripId;
  PlaceCategory? _category;
  bool _nameError = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.place.name);
    _country = TextEditingController(text: widget.place.country);
    _city = TextEditingController(text: widget.place.city);
    _tripId = widget.place.tripId;
    _description.text = widget.place.notes;
    _category = widget.place.category;
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _city.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trips = (ref.watch(tripListProvider).valueOrNull ?? [])
        .where((t) => !t.archived)
        .toList();

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Text(
          l10n.editPlaceTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.placeFormName,
            errorText: _nameError ? l10n.errNameRequired : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.placeFormCity),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _country,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.placeFormCountry),
              ),
            ),
          ],
        ),
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
          decoration: InputDecoration(labelText: l10n.placeFormDescription),
        ),
        if (trips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.placeFormTrip),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(l10n.placeFormNoTrip),
                selected: _tripId == null,
                onSelected: (_) => setState(() => _tripId = null),
              ),
              for (final trip in trips)
                ChoiceChip(
                  label: Text(trip.name),
                  selected: _tripId == trip.id,
                  onSelected: (_) => setState(() => _tripId = trip.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    setState(() => _saving = true);
    await ref.read(placeRepositoryProvider).updatePlace(
          widget.place.copyWith(
            name: _name.text,
            country: _country.text,
            city: _city.text,
            tripId: () => _tripId,
            category: () => _category,
            notes: _description.text,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }
}
