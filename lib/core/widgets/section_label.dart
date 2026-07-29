import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Letter-spaced uppercase section header ("ACTIVE NOW", "PINNED").
/// [accent] renders in teal — used for the wishlist section.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.sectionLabel.copyWith(
        color: accent ? colors.accent : colors.inkMuted,
      ),
    );
  }
}
