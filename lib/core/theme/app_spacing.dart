/// Spacing and shape tokens (SPEC §4.4).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppShape {
  /// One radius for everything — cards, sheets, buttons.
  static const radius = 10.0;

  /// Hairline borders instead of shadows.
  static const hairlineWidth = 0.5;
}
