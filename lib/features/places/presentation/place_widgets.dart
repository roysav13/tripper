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

/// A horizontal strip of active-filter pills shown above the list — the
/// same "chips row" pattern real map/list apps (Google Maps, Airbnb) use
/// to keep active facets visible and one-tap removable, instead of hidden
/// entirely behind an icon until the sheet is reopened. Renders nothing
/// when nothing is active. Horizontally scrollable rather than wrapping,
/// so an active-heavy filter never pushes the list down by more than one
/// row's height.
class ActiveFilterStrip extends StatelessWidget {
  const ActiveFilterStrip({
    super.key,
    required this.categories,
    required this.countries,
    required this.onRemoveCategory,
    required this.onRemoveCountry,
    required this.onClearAll,
  });

  final Set<PlaceCategory> categories;
  final Set<String> countries;
  final ValueChanged<PlaceCategory> onRemoveCategory;
  final ValueChanged<String> onRemoveCountry;
  final VoidCallback onClearAll;

  static const _height = 36.0;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty && countries.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final sortedCategories = categories.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final sortedCountries = countries.toList()..sort();

    return SizedBox(
      height: _height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final category in sortedCategories)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: _FilterPill(
                label: placeCategoryLabel(l10n, category),
                onRemove: () => onRemoveCategory(category),
              ),
            ),
          for (final country in sortedCountries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: _FilterPill(
                label: country,
                onRemove: () => onRemoveCountry(country),
              ),
            ),
          if (categories.length + countries.length > 1)
            Center(
              child: TextButton(
                onPressed: onClearAll,
                child: Text(l10n.placesFilterEmptyCta),
              ),
            ),
        ],
      ),
    );
  }
}

/// One removable active-filter pill: label + a tappable close glyph, coral
/// outline on a solid surface (never a filled coral background — that's
/// reserved for the one true CTA per screen, the sheet's "Show N places").
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.pillRadius),
        side: BorderSide(color: colors.accent, width: AppShape.hairlineWidth),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.pillRadius),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.md,
            end: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AutoDirectionText(
                label,
                style: AppTextStyles.label.copyWith(color: colors.accent),
              ),
              const SizedBox(width: 2),
              Icon(Icons.close, size: 14, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Country facet as a searchable single-column checklist rather than a
/// wall of pill chips — a wrap of chips reads fine for a small, bounded
/// set (category has 12 fixed values) but degrades into an unpredictable,
/// hard-to-scan block once the set is large and dynamic (a trip log can
/// easily carry 20-30 countries). A search box only appears once the list
/// is long enough to need one.
class _CountryChecklist extends StatefulWidget {
  const _CountryChecklist({
    required this.countries,
    required this.selected,
    required this.onChanged,
  });

  final List<String> countries;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  static const searchThreshold = 6;

  @override
  State<_CountryChecklist> createState() => _CountryChecklistState();
}

class _CountryChecklistState extends State<_CountryChecklist> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.countries
        : widget.countries
            .where((c) => c.toLowerCase().contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.countries.length > _CountryChecklist.searchThreshold)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.placesFilterSearchCountry,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.md,
            ),
            child: MonoText(l10n.placesFilterSearchNoResults, muted: true),
          )
        else
          for (final country in visible)
            InkWell(
              onTap: () {
                final next = widget.selected.contains(country)
                    ? widget.selected.where((c) => c != country).toSet()
                    : {...widget.selected, country};
                widget.onChanged(next);
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AutoDirectionText(
                        country,
                        style: AppTextStyles.body
                            .copyWith(color: colors.inkPrimary),
                      ),
                    ),
                    if (widget.selected.contains(country))
                      Icon(Icons.check, color: colors.accent, size: 20),
                  ],
                ),
              ),
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

/// Opens the category/country filters in a glass-chrome modal bottom sheet
/// (redesign spec §5: "glass filter chips on a bottom sheet") instead of
/// always-visible inline — the same GlassChrome-over-content idiom
/// phase2a's trip detail screen used for its floating tab bar.
/// [placesProvider] is watched *inside* the sheet (not passed as a static
/// list) so a facet whose last matching place is edited/deleted away while
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

  void _setCategories(Set<PlaceCategory> next) {
    setState(() => _categories = next);
    widget.onCategoriesChanged(next);
  }

  void _setCountries(Set<String> next) {
    setState(() => _countries = next);
    widget.onCountriesChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final places =
        ref.watch(widget.placesProvider).valueOrNull ?? const <Place>[];

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
    final matchCount =
        filterPlaces(places, categories: _categories, countries: _countries)
            .length;

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
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  l10n.placesFilterSheetTitle,
                  color: colors.inkPrimary,
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category stays a chip grid — 12 fixed values is
                        // exactly the small, bounded set chips suit well.
                        if (categories.isNotEmpty) ...[
                          SectionLabel(
                            l10n.placesFilterCategorySection,
                            color: colors.inkPrimary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final category in categories)
                                FilterChip(
                                  avatar: Icon(
                                    placeCategoryIcon(category),
                                    size: 16,
                                  ),
                                  label: Text(
                                    placeCategoryLabel(l10n, category),
                                  ),
                                  selected: _categories.contains(category),
                                  onSelected: (selected) => _setCategories(
                                    selected
                                        ? {..._categories, category}
                                        : _categories
                                            .where((c) => c != category)
                                            .toSet(),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (categories.isNotEmpty && countries.isNotEmpty)
                          const SizedBox(height: AppSpacing.lg),
                        // Country is dynamic and can be long — a
                        // searchable checklist scans far better than a
                        // wall of variable-width chips at that size.
                        if (countries.isNotEmpty) ...[
                          SectionLabel(
                            l10n.placesFilterCountrySection,
                            color: colors.inkPrimary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _CountryChecklist(
                            countries: countries,
                            selected: _countries,
                            onChanged: _setCountries,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    TextButton(
                      onPressed: _categories.isEmpty && _countries.isEmpty
                          ? null
                          : () {
                              _setCategories({});
                              _setCountries({});
                            },
                      child: Text(l10n.placesFilterEmptyCta),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.surface,
                      ),
                      child: Text(l10n.placesFilterShowResults(matchCount)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
