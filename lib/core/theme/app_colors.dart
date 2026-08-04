import 'package:flutter/material.dart';

/// The Tripper palette (SPEC §4.2). The ONLY file allowed to contain
/// raw Color(0xFF...) values.
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
  });

  /// App background — warm off-white, never pure white.
  final Color paper;

  /// Cards and sheets.
  final Color surface;

  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkMuted;

  /// Dividers and card borders.
  final Color hairline;

  /// Deep teal — the single accent. Actions, active states, wishlist pins.
  final Color accent;

  /// Rust — warnings only (document expiry). Never for place states.
  final Color warning;

  final Color error;
  final Color success;

  static const light = AppColors(
    paper: Color(0xFFF7F4EE),
    surface: Color(0xFFFFFFFF),
    inkPrimary: Color(0xFF1C2422),
    inkSecondary: Color(0xFF5B6462),
    // 4.8:1 on paper — mono metadata is informational, so it must clear
    // WCAG AA. The old #8C948F sat at 2.8:1 (M4 audit).
    inkMuted: Color(0xFF666D68),
    hairline: Color(0xFFDEDACD),
    accent: Color(0xFF2B6E6B),
    warning: Color(0xFFB5562D),
    error: Color(0xFFA23B2E),
    success: Color(0xFF3F7A52),
  );

  // Lifted a step from true black — "dim paper", not void.
  static const dark = AppColors(
    paper: Color(0xFF1B1F21),
    surface: Color(0xFF24292B),
    inkPrimary: Color(0xFFEDEAE2),
    inkSecondary: Color(0xFFB0B6B1),
    // 5.2:1 on dark paper (was 3.9:1).
    inkMuted: Color(0xFF8A918B),
    hairline: Color(0xFF3A4043),
    accent: Color(0xFF5AA6A2),
    warning: Color(0xFFD37D53),
    error: Color(0xFFC05B4D),
    success: Color(0xFF5E9A72),
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
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
