import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Blurred glass chrome for nav/tab/top bars sitting over a photo or
/// gradient hero (redesign spec §4, component rule 3). Never use this for
/// regular content cards — those stay solid ([PaperCard]) for reliable
/// contrast and cheap repaint.
class GlassChrome extends StatelessWidget {
  const GlassChrome({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The shadow lives on this outer DecoratedBox, deliberately outside
    // the ClipRRect below: a BoxShadow paints outside its box's bounds
    // (offset/blurRadius), and ClipRRect clips to exactly those bounds —
    // nesting the shadow inside the clip would make it invisible.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          // Tinted with the app's own dark tone, never a flat
          // gray/black — this is the one place in the redesign
          // shadows are allowed at all (glass-over-imagery only,
          // component rule 3 / spec §3.4).
          BoxShadow(
            color: AppColors.dark.paper.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.55),
              borderRadius: borderRadius,
              border: Border.all(
                color: colors.hairline,
                width: AppShape.hairlineWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
