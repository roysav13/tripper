import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/glass_chrome.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';

IconData placeCategoryIcon(PlaceCategory category) => switch (category) {
      PlaceCategory.hotel => Icons.hotel_outlined,
      PlaceCategory.restaurant => Icons.restaurant_outlined,
      PlaceCategory.coffeeShop => Icons.local_cafe_outlined,
      PlaceCategory.bar => Icons.local_bar_outlined,
      PlaceCategory.attraction => Icons.local_activity_outlined,
      PlaceCategory.museum => Icons.museum_outlined,
      PlaceCategory.amusementPark => Icons.attractions_outlined,
      PlaceCategory.trek => Icons.hiking_outlined,
      PlaceCategory.beach => Icons.beach_access_outlined,
      PlaceCategory.shopping => Icons.shopping_bag_outlined,
      PlaceCategory.nature => Icons.park_outlined,
      PlaceCategory.other => Icons.category_outlined,
    };

String placeCategoryLabel(AppLocalizations l10n, PlaceCategory category) =>
    switch (category) {
      PlaceCategory.hotel => l10n.catHotel,
      PlaceCategory.restaurant => l10n.catRestaurant,
      PlaceCategory.coffeeShop => l10n.catCoffeeShop,
      PlaceCategory.bar => l10n.catBar,
      PlaceCategory.attraction => l10n.catAttraction,
      PlaceCategory.museum => l10n.catMuseum,
      PlaceCategory.amusementPark => l10n.catAmusementPark,
      PlaceCategory.trek => l10n.catTrek,
      PlaceCategory.beach => l10n.catBeach,
      // Reuses Expense's category strings where the word is identical —
      // one translation to maintain, not two.
      PlaceCategory.shopping => l10n.catShopping,
      PlaceCategory.nature => l10n.catNature,
      PlaceCategory.other => l10n.catOther,
    };

/// Category + country filter chips — a controlled widget, all state lives
/// in the parent screen. Only categories/countries actually present in
/// [places] render a chip, so there's never a dead-end filter option.
class PlaceFilterBar extends StatelessWidget {
  const PlaceFilterBar({
    super.key,
    required this.places,
    required this.selectedCategories,
    required this.selectedCountries,
    required this.onCategoriesChanged,
    required this.onCountriesChanged,
  });

  final List<Place> places;
  final Set<PlaceCategory> selectedCategories;
  final Set<String> selectedCountries;
  final ValueChanged<Set<PlaceCategory>> onCategoriesChanged;
  final ValueChanged<Set<String>> onCountriesChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = {
      for (final p in places)
        if (p.category != null) p.category!,
    }.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final countries = {
      for (final p in places)
        if (p.country.trim().isNotEmpty) p.country,
    }.toList()
      ..sort();

    if (categories.isEmpty && countries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final category in categories)
                FilterChip(
                  avatar: Icon(placeCategoryIcon(category), size: 16),
                  label: Text(placeCategoryLabel(l10n, category)),
                  selected: selectedCategories.contains(category),
                  onSelected: (selected) => onCategoriesChanged(
                    selected
                        ? {...selectedCategories, category}
                        : selectedCategories
                            .where((c) => c != category)
                            .toSet(),
                  ),
                ),
            ],
          ),
        if (categories.isNotEmpty && countries.isNotEmpty)
          const SizedBox(height: AppSpacing.sm),
        if (countries.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final country in countries)
                FilterChip(
                  label: Text(country),
                  selected: selectedCountries.contains(country),
                  onSelected: (selected) => onCountriesChanged(
                    selected
                        ? {...selectedCountries, country}
                        : selectedCountries.where((c) => c != country).toSet(),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Wishlist row: white card, teal pin, faint check target on the right.
/// Visited row: recessed paper card, gray, visited date, tap check to undo.
class PlaceRowCard extends StatelessWidget {
  const PlaceRowCard({
    super.key,
    required this.place,
    this.tripName,
    this.onToggleVisited,
    this.onTap,
  });

  final Place place;
  final String? tripName;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final visited = place.isVisited;

    final metaParts = <String>[
      if (place.city.isNotEmpty) place.city,
      if (place.country.isNotEmpty) place.country,
      if (visited && place.visitedAt != null)
        l10n.visitedOn(
          DateFormat('dd MMM yyyy', l10n.localeName).format(place.visitedAt!),
        )
      else if (tripName != null)
        tripName!,
    ];

    return PaperCard(
      recessed: visited,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
        end: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            visited ? Icons.check_circle_outline : Icons.place_outlined,
            size: 20,
            color: visited ? colors.inkMuted : colors.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoDirectionText(
                  place.name,
                  style: AppTextStyles.body.copyWith(
                    color: visited ? colors.inkSecondary : colors.inkPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  MonoText(metaParts.join(' · '), muted: true),
                ],
              ],
            ),
          ),
          IconButton(
            // M4.4 — a quiet 250ms cross-fade on tap, not a springy pop;
            // keyed on `visited` so AnimatedSwitcher treats the two states
            // as genuinely different children instead of tweening a shape.
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Icon(
                visited ? Icons.check_circle : Icons.check_circle_outline,
                key: ValueKey(visited),
                size: 20,
                color: visited ? colors.inkMuted : colors.hairline,
              ),
            ),
            tooltip: visited ? l10n.placeUnvisit : l10n.placeMarkVisited,
            onPressed: onToggleVisited,
          ),
        ],
      ),
    );
  }
}

/// M4.4 — a place row settling into its section: quiet 250ms fade + rise,
/// nothing springy. `want`/`been` are separate widget subtrees (two
/// sections, not one reorderable list), so a status flip can't "fly" a row
/// across the screen without adopting AnimatedList; this softens the
/// jump-cut at the moment a row lands in its new section instead. Keyed by
/// [placeId] so Flutter treats a status flip as a fresh landing, not a
/// tween of whatever row used to sit at that position.
class RowSettleAnimation extends StatelessWidget {
  const RowSettleAnimation({
    super.key,
    required this.placeId,
    required this.child,
  });

  final String placeId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(placeId),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: child,
        ),
      ),
    );
  }
}

/// Small trigger for [showPlaceFilterSheet] — a plain icon button with a
/// coral dot badge when a category or country filter is active, so the
/// filter state stays visible even while the sheet itself is closed.
class PlaceFilterButton extends StatelessWidget {
  const PlaceFilterButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.tune, color: colors.inkSecondary),
          tooltip: l10n.placesFilterButton,
          onPressed: onPressed,
        ),
        if (active)
          PositionedDirectional(
            top: 8,
            end: 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 8, height: 8),
              ),
            ),
          ),
      ],
    );
  }
}

/// Opens [PlaceFilterBar]'s chips in a glass-chrome modal bottom sheet
/// (redesign spec §5: "glass filter chips on a bottom sheet") instead of
/// always-visible inline — the same GlassChrome-over-content idiom
/// phase2a's trip detail screen used for its floating tab bar.
/// [placesProvider] is watched *inside* the sheet (not passed as a static
/// list) so a chip whose last matching place is edited/deleted away while
/// the sheet is open still disappears live — the same guarantee the
/// pre-sheet inline chips had via the parent screens' own pruning logic.
Future<void> showPlaceFilterSheet(
  BuildContext context, {
  required ProviderListenable<AsyncValue<List<Place>>> placesProvider,
  required Set<PlaceCategory> selectedCategories,
  required Set<String> selectedCountries,
  required ValueChanged<Set<PlaceCategory>> onCategoriesChanged,
  required ValueChanged<Set<String>> onCountriesChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _PlaceFilterSheet(
      placesProvider: placesProvider,
      initialCategories: selectedCategories,
      initialCountries: selectedCountries,
      onCategoriesChanged: onCategoriesChanged,
      onCountriesChanged: onCountriesChanged,
    ),
  );
}

class _PlaceFilterSheet extends ConsumerStatefulWidget {
  const _PlaceFilterSheet({
    required this.placesProvider,
    required this.initialCategories,
    required this.initialCountries,
    required this.onCategoriesChanged,
    required this.onCountriesChanged,
  });

  final ProviderListenable<AsyncValue<List<Place>>> placesProvider;
  final Set<PlaceCategory> initialCategories;
  final Set<String> initialCountries;
  final ValueChanged<Set<PlaceCategory>> onCategoriesChanged;
  final ValueChanged<Set<String>> onCountriesChanged;

  @override
  ConsumerState<_PlaceFilterSheet> createState() => _PlaceFilterSheetState();
}

class _PlaceFilterSheetState extends ConsumerState<_PlaceFilterSheet> {
  late Set<PlaceCategory> _categories = widget.initialCategories;
  late Set<String> _countries = widget.initialCountries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final places =
        ref.watch(widget.placesProvider).valueOrNull ?? const <Place>[];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassChrome(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppShape.radius),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(l10n.placesFilterSheetTitle),
                  const SizedBox(height: AppSpacing.md),
                  PlaceFilterBar(
                    places: places,
                    selectedCategories: _categories,
                    selectedCountries: _countries,
                    onCategoriesChanged: (v) {
                      setState(() => _categories = v);
                      widget.onCategoriesChanged(v);
                    },
                    onCountriesChanged: (v) {
                      setState(() => _countries = v);
                      widget.onCountriesChanged(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
