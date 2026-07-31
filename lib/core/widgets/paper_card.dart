import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The universal simple card: surface + soft shadow (SPEC §4.4, revised —
/// shadows replaced the flat hairline border in the M7 "Wallet & Ticket"
/// restyle). For a trip/document "travel object" card, use [TicketCard]
/// instead; PaperCard remains for plain list rows, forms, and settings
/// tiles that shouldn't carry the ticket die-cut.
///
/// [recessed] renders on the paper tone with no shadow instead — used for
/// past trips and visited places, so they visually sit back in the list.
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
    final brightness = Theme.of(context).brightness;
    final card = Material(
      color: recessed ? colors.paper : colors.surface,
      elevation: recessed ? 0 : AppElevation.card(brightness),
      shadowColor: AppElevation.shadowColor(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.radius),
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!, width: 1.0),
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
