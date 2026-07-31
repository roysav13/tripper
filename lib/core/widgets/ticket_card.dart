import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The signature "Wallet & Ticket" primitive (M7 restyle): a trip or
/// document renders as a physical ticket, not a generic Material card.
///
/// Anatomy, left-to-right in LTR (mirrored automatically in RTL — see
/// below): a colored [stub] carrying the trip's [accentColor] or the
/// document category's icon, a perforated tear line, then the [body].
/// The shape itself — rounded outer corners plus two semicircular notches
/// bitten out of the long edges at the stub/body seam — is cut with
/// [TicketNotchClipper] and elevated with [PhysicalShape], which (unlike a
/// manual BoxShadow) computes a shadow that correctly follows the concave
/// notches instead of boxing around them.
///
/// RTL-safety (hard rule #3): [stub] is always the layout's logical
/// *start* edge because `Row` reorders its children for
/// `Directionality.of(context) == TextDirection.rtl` automatically — the
/// clip path and perforation line read that same `Directionality` so the
/// notch/seam always lines up with wherever the stub actually rendered.
///
/// Motion: the card scales down slightly on press (`_TicketCardState`) —
/// a small "picking up a ticket" tactility, driven by `InkWell`'s own
/// `onHighlightChanged` rather than a second gesture recognizer (an
/// earlier version used a wrapping `GestureDetector` for this, but two
/// independent tap recognizers along the same hit-test path have to share
/// a gesture arena — neither's `onTapDown` fired until the arena's sweep
/// at pointer-up, so the "press" state never appeared while actually
/// pressed). A full drag-to-fan/stack interaction for the trip list
/// (M7.2) was scoped out of M7's first pass as too much unverified
/// gesture code to ship without on-device testing; this press feedback is
/// the deliberately-smaller stand-in.
///
/// Accessibility: [semanticLabel] is announced for the card as one atomic
/// unit. `PhysicalShape`/`Stack`/`CustomPaint`/`AnimatedScale` sitting
/// between the tap target and [stub]/[body]'s text apparently break
/// Flutter's default semantics merge (caught by
/// `labeledTapTargetGuideline` in `accessibility_test.dart` — the
/// underlying content's text wasn't merging into the InkWell's own
/// semantics node once this many paint layers sat in between), so an
/// explicit label is required input rather than an optional nicety.
class TicketCard extends StatefulWidget {
  const TicketCard({
    super.key,
    required this.accentColor,
    required this.stub,
    required this.body,
    required this.semanticLabel,
    this.onTap,
    this.stubWidth = AppShape.ticketStubWidth,
    this.bodyPadding = const EdgeInsetsDirectional.all(AppSpacing.lg),
    this.raised = false,
  });

  /// The trip's `tripPalette` color, or a document category's tint.
  final Color accentColor;

  /// Content painted on the colored stub — a day-count badge, a category
  /// icon. Text/icon color is resolved automatically via
  /// `AppColors.onColor` for contrast against [accentColor].
  final Widget stub;

  final Widget body;
  final VoidCallback? onTap;

  /// Accessible label for the whole card. Required, not optional — see the
  /// class doc for why this can't be left to automatic semantics merging.
  /// Should summarize both [stub] and [body] in one string (e.g. a trip's
  /// name + dates, a document's title + category/expiry).
  final String semanticLabel;

  /// Width of the stub section; also where the tear line/notches sit.
  final double stubWidth;
  final EdgeInsetsGeometry bodyPadding;

  /// True while being dragged in a future trip-stack fan interaction
  /// (M7.2, not yet built) — bumps elevation so the lifted card visibly
  /// separates from the stack. Also bumps elevation on press, today.
  final bool raised;

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brightness = Theme.of(context).brightness;
    final direction = Directionality.of(context);
    final onAccent = colors.onColor(widget.accentColor);

    final clipper = TicketNotchClipper(
      stubWidth: widget.stubWidth,
      notchRadius: AppShape.ticketNotchRadius,
      cornerRadius: AppShape.ticketRadius,
      direction: direction,
    );

    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      // The real tap handler, not just the `button` flag — excludeSemantics
      // below hides the InkWell's own semantics node (the one that would
      // otherwise carry the actual SemanticsAction.tap), so without this,
      // assistive tech would announce a "button" that does nothing when
      // activated.
      onTap: widget.onTap,
      container: true,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: PhysicalShape(
          clipper: clipper,
          color: colors.surface,
          elevation: widget.raised || _pressed
              ? AppElevation.raised(brightness)
              : AppElevation.card(brightness),
          shadowColor: AppElevation.shadowColor(brightness),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              // Fires on the actual down/up-or-cancel of *this* recognizer
              // — see the class doc for why a second, outer GestureDetector
              // doesn't work for this.
              onHighlightChanged: _setPressed,
              child: Stack(
                children: [
                  // IntrinsicHeight forces both Row children to the
                  // body's natural height — without it,
                  // CrossAxisAlignment.stretch has nothing to stretch
                  // against inside a Stack (which gives loose, not tight,
                  // constraints), and the colored stub would collapse
                  // instead of running the card's full height.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: widget.stubWidth,
                          color: widget.accentColor,
                          padding: const EdgeInsetsDirectional.all(
                            AppSpacing.sm,
                          ),
                          child: Center(
                            child: IconTheme.merge(
                              data: IconThemeData(color: onAccent),
                              child: DefaultTextStyle.merge(
                                style: TextStyle(color: onAccent),
                                child: widget.stub,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: widget.bodyPadding,
                            child: widget.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    // Purely decorative — must not steal hits from the
                    // InkWell/content beneath it. Without IgnorePointer,
                    // RenderStack hit-tests top-to-bottom and stops at the
                    // first child whose bounds contain the point, so this
                    // full-size CustomPaint (painted last = on top) was
                    // swallowing every tap before the Row/Text below ever
                    // saw it — harmless only by accident, since it sits
                    // inside the same InkWell and the tap still bubbled up
                    // to the right onTap. Found via a tester.tap() hit-test
                    // warning on a specific Text finder inside the card.
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: TicketPerforationPainter(
                          stubWidth: widget.stubWidth,
                          color: colors.hairline,
                          direction: direction,
                        ),
                      ),
                    ),
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

/// Cuts the ticket silhouette: rounded outer corners + two semicircular
/// notches at the stub/body seam. [direction] flips which physical edge
/// the seam sits on so it always matches [TicketCard]'s `Row`.
@immutable
class TicketNotchClipper extends CustomClipper<Path> {
  const TicketNotchClipper({
    required this.stubWidth,
    required this.notchRadius,
    required this.cornerRadius,
    required this.direction,
  });

  final double stubWidth;
  final double notchRadius;
  final double cornerRadius;
  final TextDirection direction;

  double _seamX(Size size) =>
      direction == TextDirection.rtl ? size.width - stubWidth : stubWidth;

  @override
  Path getClip(Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(cornerRadius),
        ),
      );
    final seamX = _seamX(size);
    final topNotch = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(seamX, 0), radius: notchRadius),
      );
    final bottomNotch = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(seamX, size.height),
          radius: notchRadius,
        ),
      );
    return Path.combine(
      PathOperation.difference,
      Path.combine(PathOperation.difference, outline, topNotch),
      bottomNotch,
    );
  }

  @override
  bool shouldReclip(covariant TicketNotchClipper oldClipper) =>
      oldClipper.stubWidth != stubWidth ||
      oldClipper.notchRadius != notchRadius ||
      oldClipper.cornerRadius != cornerRadius ||
      oldClipper.direction != direction;
}

/// The dashed "tear here" line at the stub/body seam. Painted inside the
/// same clipped shape as the notches, so it reads as interrupted by them
/// rather than drawn on top.
@immutable
class TicketPerforationPainter extends CustomPainter {
  const TicketPerforationPainter({
    required this.stubWidth,
    required this.color,
    required this.direction,
  });

  final double stubWidth;
  final Color color;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final x =
        direction == TextDirection.rtl ? size.width - stubWidth : stubWidth;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + AppShape.ticketPerforationDash),
        paint,
      );
      y += AppShape.ticketPerforationDash + AppShape.ticketPerforationGap;
    }
  }

  @override
  bool shouldRepaint(covariant TicketPerforationPainter oldDelegate) =>
      oldDelegate.stubWidth != stubWidth ||
      oldDelegate.color != color ||
      oldDelegate.direction != direction;
}
