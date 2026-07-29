import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Mono-styled metadata: dates, codes, coordinates.
/// Renders uppercase by convention ("16 JUL – 27 JUL · KRABI").
class MonoText extends StatelessWidget {
  const MonoText(this.text, {super.key, this.color, this.muted = false});

  final String text;
  final Color? color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.mono.copyWith(
        color: color ?? (muted ? colors.inkMuted : colors.inkSecondary),
      ),
    );
  }
}
