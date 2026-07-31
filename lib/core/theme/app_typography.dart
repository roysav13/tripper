import 'package:flutter/material.dart';

/// Three families, seven sizes (SPEC §4.3, widened for M7's "Wallet &
/// Ticket" restyle). The old 5-size scale read flat on hero moments — a
/// trip's name on its own detail screen should not be the same size as a
/// section header. [hero] and [statValue] are the two additions; the
/// original five are unchanged so every existing screen keeps working.
///
/// Family names resolve once the bundled fonts are added
/// (assets/fonts/README.md); until then Flutter falls back to system
/// serif/sans/mono.
abstract final class AppFonts {
  static const serif = 'Fraunces';
  static const sans = 'IBM Plex Sans';
  static const mono = 'IBM Plex Mono';
}

abstract final class AppTypeScale {
  /// Trip name on its own detail hero, big empty-state headlines.
  static const hero = 40.0;
  static const display = 28.0;
  static const title = 22.0;
  static const body = 15.0;
  static const label = 13.0;
  static const caption = 11.0;

  /// The big number in a stat tile (countries visited, days traveled).
  static const statValue = 34.0;
}

abstract final class AppTextStyles {
  /// Serif, largest tier — reserved for a screen's single hero moment
  /// (trip detail header, a landing empty state). Only one per screen.
  /// Weight 600 is Fraunces' heaviest static, so it stays crisp at size.
  static const hero = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: AppTypeScale.hero,
    fontWeight: FontWeight.w600,
    height: 1.05,
    letterSpacing: -0.5,
  );

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

  /// Mono, large — the headline number in a stats tile. Tabular figures so
  /// a digit change never reflows the layout around it.
  static const statValue = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: AppTypeScale.statValue,
    fontWeight: FontWeight.w500,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
