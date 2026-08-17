import 'package:flutter/material.dart';

/// Placeholder — replaced by the full implementation in the next plan
/// task. Exists only so nearby_anchor_sheet.dart compiles and its own
/// tests (which never navigate past the sheet) can run.
class NearbyPlacesScreen extends StatelessWidget {
  const NearbyPlacesScreen({
    super.key,
    required this.anchorLat,
    required this.anchorLng,
    this.tripId,
  });

  final double anchorLat;
  final double anchorLng;
  final String? tripId;

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}
