import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A deterministic gradient fallback for a trip with no cover photo
/// (redesign spec §6). The same trip id always produces the same
/// gradient — no randomness, no network, fully available offline
/// (SPEC §3.1.2/§3.1.3). Only ever uses the two tracked hero-gradient
/// tokens (component rule 2: gradients are scoped, never inventing an
/// untracked hue).
///
/// Caveat: this relies on [String.hashCode], which Dart guarantees is
/// deterministic only within a single build/SDK version, not stably
/// across Dart SDK upgrades. A trip's fallback gradient angle could in
/// principle shift after a future Flutter/Dart bump — purely cosmetic if
/// it happens, not a correctness issue (no stored data depends on the
/// hash value).
LinearGradient generatedCoverGradient(String tripId, AppColors colors) {
  const corners = [
    Alignment.topLeft,
    Alignment.topCenter,
    Alignment.topRight,
    Alignment.centerLeft,
  ];
  final begin = corners[tripId.hashCode.abs() % corners.length];
  final end = Alignment(-begin.x, -begin.y);
  return LinearGradient(
    begin: begin,
    end: end,
    colors: [colors.heroGradientStart, colors.heroGradientEnd],
  );
}
