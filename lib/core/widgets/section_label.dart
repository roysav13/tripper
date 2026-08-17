import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Letter-spaced uppercase section header ("ACTIVE NOW", "PINNED").
/// [accent] renders in coral — used for the wishlist section. [color]
/// overrides the computed default entirely — use when the label sits on a
/// backdrop where the default `inkMuted`/`accent` pairing doesn't hold
/// (e.g. a translucent `GlassChrome` panel where the composited background
/// isn't the plain card surface `inkMuted` is calibrated against).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.accent = false, this.color});

  final String text;
  final bool accent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.sectionLabel.copyWith(
        color: color ?? (accent ? colors.accent : colors.inkMuted),
      ),
    );
  }
}
