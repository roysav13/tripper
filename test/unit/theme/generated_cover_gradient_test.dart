import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/generated_cover_gradient.dart';

void main() {
  test(
      'same trip id always produces the same gradient (deterministic, no '
      'randomness — must work fully offline)', () {
    final a = generatedCoverGradient('trip-123', AppColors.dark);
    final b = generatedCoverGradient('trip-123', AppColors.dark);
    expect(a.begin, b.begin);
    expect(a.end, b.end);
    expect(a.colors, b.colors);
  });

  test(
      'different trip ids produce more than one distinct angle across a '
      'sample set', () {
    final sampleIds = List.generate(20, (i) => 'trip-$i');
    final begins = sampleIds
        .map((id) => generatedCoverGradient(id, AppColors.dark).begin)
        .toSet();
    expect(begins.length, greaterThan(1));
  });

  test(
      'only ever uses the two tracked hero-gradient tokens — never invents '
      'a new hue (component rule 2: gradients are scoped)', () {
    final gradient = generatedCoverGradient('trip-abc', AppColors.light);
    expect(gradient.colors, [
      AppColors.light.heroGradientStart,
      AppColors.light.heroGradientEnd,
    ]);
  });

  test('begin and end are always opposite corners', () {
    final gradient = generatedCoverGradient('trip-xyz', AppColors.dark);
    final begin = gradient.begin as Alignment;
    final end = gradient.end as Alignment;
    expect(end.x, -begin.x);
    expect(end.y, -begin.y);
  });
}
