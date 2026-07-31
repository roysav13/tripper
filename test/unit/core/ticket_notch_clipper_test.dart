import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/widgets/ticket_card.dart';

void main() {
  const size = Size(240, 96);
  const stubWidth = 84.0;
  const notchRadius = 8.0;
  const cornerRadius = 16.0;

  TicketNotchClipper clipper(TextDirection direction) => TicketNotchClipper(
        stubWidth: stubWidth,
        notchRadius: notchRadius,
        cornerRadius: cornerRadius,
        direction: direction,
      );

  test('the body, well away from any edge, stays part of the shape', () {
    final path = clipper(TextDirection.ltr).getClip(size);
    expect(path.contains(const Offset(150, 48)), isTrue);
  });

  test('bites a semicircular notch out of the seam in LTR', () {
    final path = clipper(TextDirection.ltr).getClip(size);
    // Just inside the top notch at the stub/body seam.
    expect(path.contains(const Offset(stubWidth, notchRadius / 2)), isFalse);
    // Mirror notch on the bottom edge.
    expect(
      path.contains(Offset(stubWidth, size.height - notchRadius / 2)),
      isFalse,
    );
  });

  test('moves the seam to the opposite physical edge in RTL', () {
    final ltrSeamPoint = const Offset(stubWidth, notchRadius / 2);
    final rtlSeamPoint = Offset(size.width - stubWidth, notchRadius / 2);

    final ltr = clipper(TextDirection.ltr).getClip(size);
    final rtl = clipper(TextDirection.rtl).getClip(size);

    // What was cut away in LTR is untouched in RTL, and vice versa — the
    // clip path tracks Directionality rather than a hardcoded left edge
    // (hard rule #3: RTL-safe layouts).
    expect(ltr.contains(ltrSeamPoint), isFalse);
    expect(rtl.contains(ltrSeamPoint), isTrue);

    expect(rtl.contains(rtlSeamPoint), isFalse);
    expect(ltr.contains(rtlSeamPoint), isTrue);
  });

  test('shouldReclip is true only when a geometry input actually changes', () {
    final a = clipper(TextDirection.ltr);
    final bSame = clipper(TextDirection.ltr);
    final cDifferentDirection = clipper(TextDirection.rtl);

    expect(a.shouldReclip(bSame), isFalse);
    expect(a.shouldReclip(cDifferentDirection), isTrue);
  });
}
