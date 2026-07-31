import 'package:flutter/material.dart';

/// The Tripper palette (SPEC §4.2, "Wallet & Ticket" system, M7 restyle).
/// The ONLY file allowed to contain raw Color(0xFF...) values.
///
/// Two tiers of color now exist, deliberately kept apart:
/// - Neutrals + semantic colors ([paper] through [success]) — the same
///   ink-on-paper base as before, still the only colors used for system
///   meaning (errors, warnings, confirmations).
/// - [tripPalette] — 8 saturated "stamp ink" hues used purely for identity:
///   each trip is tagged with one (via `Trip.colorTag`), and that color
///   follows it everywhere the trip shows up (ticket stub, header, map
///   pin). None of these hues overlap the semantic ones, so a colored
///   trip tag is never mistaken for a warning or an error.
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
    required this.tripPalette,
  });

  /// App background — warm off-white, never pure white.
  final Color paper;

  /// Cards and sheets.
  final Color surface;

  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkMuted;

  /// Dividers only now — cards separate with [AppElevation] shadow instead
  /// (SPEC §4.4, revised). Still used for the tab bar rule and hairline
  /// dividers between list rows.
  final Color hairline;

  /// Deep teal — the default/neutral action color: primary buttons, the
  /// "want to go" wishlist state, anything that isn't tied to a specific
  /// trip's identity. Trip-specific surfaces use [tripPalette] instead.
  final Color accent;

  /// Rust — warnings only (document expiry). Never a trip tag color.
  final Color warning;

  final Color error;
  final Color success;

  /// 8 stamp-ink hues for trip identity (`Trip.colorTag` indexes into this,
  /// mod length so old data never goes out of range). Order is fixed —
  /// changing it silently re-colors every existing trip, so append, don't
  /// reorder.
  final List<Color> tripPalette;

  /// Resolves a `Trip.colorTag` to its color, safe against any int value.
  Color tripAccent(int colorTag) => tripPalette[colorTag % tripPalette.length];

  /// Legible text/icon color to place on top of [background] — most of
  /// [tripPalette] is dark/saturated enough to want white, but marigold
  /// (the one deliberately pale hue) reads better with near-black text.
  /// Perceptive luminance, not a naive RGB average.
  Color onColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.42 ? inkPrimary : surface;
  }

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
    tripPalette: [
      Color(0xFF2B6E6B), // Harbor teal — the sea, default trip color
      // Marigold — deliberately the palette's one pale hue (sun-baked
      // desert stamps); its onColor() reads inkPrimary, not surface, so
      // this is also the swatch that exercises that branch.
      Color(0xFFE0B24A),
      Color(0xFFA63D63), // Berry — warm, but cooler/pinker than the
      // warning/error rust so a trip tag never reads as an alert
      Color(0xFF3E5490), // Indigo — night flights
      Color(0xFF5B7A3A), // Moss — trail, olive-green (kept distinct from
      // status.success's blue-green)
      Color(0xFF6B4E8E), // Plum — dusk
      Color(0xFF2E6E9E), // Cobalt — deep water, more blue than harbor teal
      Color(0xFF52677A), // Slate — overcast coastal town
    ],
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
    tripPalette: [
      Color(0xFF5AA6A2), // Harbor teal
      Color(0xFFE8BE63), // Marigold — same pale-hue role as light mode
      Color(0xFFC97A97), // Berry
      Color(0xFF8098D4), // Indigo
      Color(0xFF8FAE68), // Moss
      Color(0xFFA587C4), // Plum
      Color(0xFF6BA3CC), // Cobalt
      Color(0xFF8CA0B2), // Slate
    ],
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
    List<Color>? tripPalette,
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
      tripPalette: tripPalette ?? this.tripPalette,
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
      tripPalette: tripPalette.length == other.tripPalette.length
          ? [
              for (var i = 0; i < tripPalette.length; i++)
                Color.lerp(tripPalette[i], other.tripPalette[i], t)!,
            ]
          : t < 0.5
              ? tripPalette
              : other.tripPalette,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
