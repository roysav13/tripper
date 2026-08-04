import 'package:flutter/material.dart';

/// Three families, five sizes (SPEC §4.3). Family names resolve once the
/// bundled fonts are added (assets/fonts/README.md); until then Flutter
/// falls back to system serif/sans/mono.
abstract final class AppFonts {
  static const serif = 'Fraunces';
  static const sans = 'IBM Plex Sans';
  static const mono = 'IBM Plex Mono';
}

abstract final class AppTypeScale {
  static const display = 28.0;
  static const title = 22.0;
  static const body = 15.0;
  static const label = 13.0;
  static const caption = 11.0;
}

abstract final class AppTextStyles {
  /// Serif — screen titles, trip and place names.
  /// Only 400/600 exist as Fraunces statics; using those exact weights keeps
  /// the serif crisp (synthetic weights smear the strokes).
  static const display = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: AppTypeScale.display,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Trip and place names — regular reads more like a printed journal.
  static const title = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: AppTypeScale.title,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );

  static const body = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: AppTypeScale.body,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const label = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: AppTypeScale.label,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Letter-spaced uppercase section labels ("ACTIVE NOW").
  static const sectionLabel = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: AppTypeScale.caption,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    height: 1.3,
  );

  /// Mono — dates, codes, coordinates, metadata rows.
  static const mono = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: AppTypeScale.caption,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );
}
