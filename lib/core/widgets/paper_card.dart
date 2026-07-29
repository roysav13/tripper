import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The universal card: surface + hairline border, no shadow.
/// [recessed] renders on the paper tone instead of white — used for
/// past trips and visited places.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.recessed = false,
    this.borderColor,
    this.onTap,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.lg),
  });

  final Widget child;
  final bool recessed;
  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = Material(
      color: recessed ? colors.paper : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.radius),
        side: BorderSide(
          color: borderColor ?? colors.hairline,
          width: borderColor != null ? 1.0 : AppShape.hairlineWidth,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShape.radius),
        child: Padding(padding: padding, child: child),
      ),
    );
    return card;
  }
}
