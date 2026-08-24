import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/generated_cover_gradient.dart';
import '../../../core/widgets/local_images.dart';
import '../domain/trip.dart';
import 'trip_providers.dart';

/// The trip's cover image if it has one, else the deterministic gradient
/// fallback (component rule 2: gradients are scoped to hero/cover art
/// only — this is that art). The gradient also stands in when the stored
/// file can't be read, so a cover lost to a half-restored backup degrades
/// to generated art rather than a broken-image box.
///
/// Shared by the trip card and the trip detail hero, which used to carry
/// byte-identical private copies of this.
class TripCoverBackground extends ConsumerWidget {
  const TripCoverBackground({
    super.key,
    required this.trip,
    required this.colors,
  });

  final Trip trip;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: generatedCoverGradient(trip.id, colors),
      ),
    );
    final path = trip.coverPhotoPath;
    if (path == null) return fallback;
    return Image(
      image: LocalFileImage(path, ref.watch(coverPhotoFileServiceProvider)),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
