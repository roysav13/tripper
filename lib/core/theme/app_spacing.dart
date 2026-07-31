import 'package:flutter/material.dart';

/// Spacing and shape tokens (SPEC §4.4, "Wallet & Ticket" restyle).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppShape {
  /// General-purpose corner radius — plain surfaces (PaperCard, sheets,
  /// buttons) that aren't a ticket shape. Bumped up from the old 10.0 for
  /// the softer, less boxy M7 look.
  static const radius = 14.0;

  /// Hairline width — dividers and the tab bar rule only now. Cards use
  /// [AppElevation] shadow for separation instead (SPEC §4.4, revised).
  static const hairlineWidth = 0.5;

  /// Outer corner radius on a [TicketCard].
  static const ticketRadius = 16.0;

  /// Radius of the semicircle notches cut into a ticket's long edges at
  /// the stub/body boundary — the classic "torn from a roll" detail.
  static const ticketNotchRadius = 8.0;

  /// Width of a ticket's colored stub section (day badge, category icon).
  static const ticketStubWidth = 84.0;

  /// Dash pattern for the perforation line between stub and body.
  static const ticketPerforationDash = 4.0;
  static const ticketPerforationGap = 3.0;
}

/// Shadow tokens replacing the old flat-hairline-only card style. Kept as
/// a plain elevation double (not a hand-rolled BoxShadow list) so it feeds
/// directly into [PhysicalShape]/[Material], which computes a shadow that
/// correctly follows a concave clip path (the ticket notches) — a manual
/// BoxShadow would just box around the notches and look wrong.
abstract final class AppElevation {
  /// Resting elevation for a ticket/paper card.
  static double card(Brightness brightness) =>
      brightness == Brightness.dark ? 1.5 : 3.0;

  /// Pressed/dragged state (trip card fan interaction, M7.2).
  static double raised(Brightness brightness) =>
      brightness == Brightness.dark ? 4.0 : 8.0;

  /// Material's default shadow is pure black at full elevation, which
  /// blows out on dark paper — soften it a touch in dark mode. `Colors.black`
  /// is a named Material constant, not a raw hex literal, so this doesn't
  /// violate the "no Color(0xFF...) outside app_colors.dart" rule.
  static Color shadowColor(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.6)
          : Colors.black;
}
