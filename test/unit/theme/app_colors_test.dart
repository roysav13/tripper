import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_spacing.dart';

/// Locks the "Immersive Golden Hour" token values (redesign spec §3) so a
/// future edit can't silently drift the palette back toward the old
/// teal/rust field-journal system without a test failing here first.
void main() {
  test('dark palette matches the Immersive Golden Hour spec', () {
    expect(AppColors.dark.paper, const Color(0xFF12141C));
    expect(AppColors.dark.surface, const Color(0xFF1C1F2B));
    expect(AppColors.dark.inkPrimary, const Color(0xFFF5F1EA));
    expect(AppColors.dark.inkSecondary, const Color(0xFFA9AEBD));
    expect(AppColors.dark.inkMuted, const Color(0xFF6E7386));
    expect(AppColors.dark.hairline, const Color(0x14FFFFFF));
    expect(AppColors.dark.accent, const Color(0xFFFF6B5E));
    expect(AppColors.dark.warning, const Color(0xFFF2A93C));
    expect(AppColors.dark.error, const Color(0xFFE5484D));
    expect(AppColors.dark.success, const Color(0xFF34D399));
    expect(AppColors.dark.heroGradientStart, const Color(0xFF171A2E));
    expect(AppColors.dark.heroGradientEnd, const Color(0xFFFF6B5E));
    expect(AppColors.dark.mapWater, const Color(0xFF17263C));
    expect(AppColors.dark.mapLand, const Color(0xFF242F3E));
  });

  test('light palette matches the Immersive Golden Hour spec', () {
    expect(AppColors.light.paper, const Color(0xFFFAF3EC));
    expect(AppColors.light.surface, const Color(0xFFFFFFFF));
    expect(AppColors.light.inkPrimary, const Color(0xFF1B1A22));
    expect(AppColors.light.inkSecondary, const Color(0xFF5B5A66));
    expect(AppColors.light.inkMuted, const Color(0xFF8A8894));
    expect(AppColors.light.hairline, const Color(0xFFE7E1D8));
    expect(AppColors.light.accent, const Color(0xFFE85A4E));
    expect(AppColors.light.warning, const Color(0xFFC97A1B));
    expect(AppColors.light.error, const Color(0xFFC23B34));
    expect(AppColors.light.success, const Color(0xFF1F9A6E));
    expect(AppColors.light.heroGradientStart, const Color(0xFFFAF3EC));
    expect(AppColors.light.heroGradientEnd, const Color(0xFFE85A4E));
    expect(AppColors.light.mapWater, const Color(0xFFDCEAE6));
    expect(AppColors.light.mapLand, const Color(0xFFEFE7D8));
  });

  test('card/sheet corner radius grows to 14px (spec §3.4)', () {
    expect(AppShape.radius, 14.0);
  });

  test('pill radius token exists for chips/tab indicators (spec §3.4)', () {
    expect(AppShape.pillRadius, 999.0);
  });
}
