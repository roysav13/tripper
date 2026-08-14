import 'package:flutter/material.dart';

/// The Tripper palette — "Immersive Golden Hour"
/// (docs/superpowers/specs/2026-08-14-tripper-redesign-design.md §3). The
/// ONLY file allowed to contain raw Color(0xFF...) values.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.paper,
    required this.surface,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkMuted,
    required this.hairline,
    required this.accent,
    required this.warning,
    required this.error,
    required this.success,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.mapWater,
    required this.mapLand,
  });

  /// App background. Dark mode: near-black night tone. Light mode: warm
  /// off-white, never pure white.
  final Color paper;

  /// Cards and sheets — solid content, never glass.
  final Color surface;

  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkMuted;

  /// Dividers and card borders — hairlines survive under the new skin.
  final Color hairline;

  /// Coral — the one accent. Actions, active states, "want to go"
  /// pins/dots. Never a second accent alongside [warning].
  final Color accent;

  /// Amber — expiry/danger-adjacent warnings only. Also reused for map
  /// labels — no separate "map gold" token.
  final Color warning;

  final Color error;
  final Color success;

  /// Cover scrims and generated trip-cover art only — never buttons, text
  /// backgrounds, or flat surfaces (component rule 2).
  final Color heroGradientStart;
  final Color heroGradientEnd;

  /// Custom Google Maps style base (map_style.dart, Phase 3) — replaces
  /// Google's stock/Night colors.
  final Color mapWater;
  final Color mapLand;

  static const light = AppColors(
    paper: Color(0xFFFAF3EC),
    surface: Color(0xFFFFFFFF),
    inkPrimary: Color(0xFF1B1A22),
    inkSecondary: Color(0xFF5B5A66),
    inkMuted: Color(0xFF8A8894),
    hairline: Color(0xFFE7E1D8),
    accent: Color(0xFFE85A4E),
    warning: Color(0xFFC97A1B),
    error: Color(0xFFC23B34),
    success: Color(0xFF1F9A6E),
    heroGradientStart: Color(0xFFFAF3EC),
    heroGradientEnd: Color(0xFFE85A4E),
    mapWater: Color(0xFFDCEAE6),
    mapLand: Color(0xFFEFE7D8),
  );

  static const dark = AppColors(
    paper: Color(0xFF12141C),
    surface: Color(0xFF1C1F2B),
    inkPrimary: Color(0xFFF5F1EA),
    inkSecondary: Color(0xFFA9AEBD),
    inkMuted: Color(0xFF6E7386),
    hairline: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    accent: Color(0xFFFF6B5E),
    warning: Color(0xFFF2A93C),
    error: Color(0xFFE5484D),
    success: Color(0xFF34D399),
    heroGradientStart: Color(0xFF171A2E),
    heroGradientEnd: Color(0xFFFF6B5E),
    mapWater: Color(0xFF17263C),
    mapLand: Color(0xFF242F3E),
  );

  @override
  AppColors copyWith({
    Color? paper,
    Color? surface,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkMuted,
    Color? hairline,
    Color? accent,
    Color? warning,
    Color? error,
    Color? success,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? mapWater,
    Color? mapLand,
  }) {
    return AppColors(
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      success: success ?? this.success,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      mapWater: mapWater ?? this.mapWater,
      mapLand: mapLand ?? this.mapLand,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      paper: Color.lerp(paper, other.paper, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      heroGradientStart:
          Color.lerp(heroGradientStart, other.heroGradientStart, t)!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      mapWater: Color.lerp(mapWater, other.mapWater, t)!,
      mapLand: Color.lerp(mapLand, other.mapLand, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
