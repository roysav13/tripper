import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';

/// Inline status shown under the Distance row in the filter/sort sheet
/// (see [SortFieldList.subtitleOf]) while a GPS fix is pending, denied,
/// or failed. Renders nothing once a fix lands — the sort result speaks
/// for itself at that point.
class PlaceDistanceSortStatus extends ConsumerWidget {
  const PlaceDistanceSortStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final fix = ref.watch(currentLocationProvider);

    return fix.when(
      loading: () => _label(colors, l10n.placesSortDistanceFetching),
      error: (_, __) => _StatusRow(
        colors: colors,
        text: l10n.placesSortDistanceError,
        actionLabel: l10n.placesSortDistanceRetry,
        onAction: () => ref.invalidate(currentLocationProvider),
      ),
      data: (value) => switch (value) {
        LocationAvailable() => const SizedBox.shrink(),
        // Nested switch on the plain enum (rather than matching each
        // reason as a field pattern on the outer switch) so exhaustiveness
        // is a simple, unambiguous enum check — one sealed-type switch,
        // one enum switch, each trivially provable on its own.
        LocationUnavailable(:final reason) => switch (reason) {
            LocationUnavailableReason.serviceDisabled => _StatusRow(
                colors: colors,
                text: l10n.placesSortDistanceServiceDisabled,
                actionLabel: l10n.placesSortDistanceOpenSettings,
                onAction: Geolocator.openLocationSettings,
              ),
            LocationUnavailableReason.permissionDenied => _StatusRow(
                colors: colors,
                text: l10n.placesSortDistancePermissionDenied,
                actionLabel: l10n.placesSortDistanceRetry,
                onAction: () => ref.invalidate(currentLocationProvider),
              ),
            LocationUnavailableReason.permissionDeniedForever => _StatusRow(
                colors: colors,
                text: l10n.placesSortDistancePermissionDenied,
                actionLabel: l10n.placesSortDistanceOpenSettings,
                onAction: Geolocator.openAppSettings,
              ),
            LocationUnavailableReason.error => _StatusRow(
                colors: colors,
                text: l10n.placesSortDistanceError,
                actionLabel: l10n.placesSortDistanceRetry,
                onAction: () => ref.invalidate(currentLocationProvider),
              ),
          },
      },
    );
  }

  Widget _label(AppColors colors, String text) => Text(
        text,
        style: AppTextStyles.label.copyWith(color: colors.inkMuted),
      );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.colors,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final AppColors colors;
  final String text;
  final String actionLabel;

  /// `VoidCallback` (not `Future<void> Function()`) because it has to
  /// accept both shapes: `ref.invalidate(...)` returns `void`, while
  /// `Geolocator.openLocationSettings`/`openAppSettings` return
  /// `Future<bool>` — only assignable *to* `void Function()`, never the
  /// other way around.
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.label.copyWith(color: colors.inkMuted),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onAction,
          child: Text(
            actionLabel,
            // inkPrimary + underline, not colors.accent: coral is reserved
            // for this sheet's one true CTA (the "Show N" button —
            // active_filter_strip.dart's _FilterPill has the same note),
            // and — found the hard way via the accessibility test suite —
            // coral-on-glass fails WCAG contrast at this text size anyway.
            style: AppTextStyles.label.copyWith(
              color: colors.inkPrimary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
