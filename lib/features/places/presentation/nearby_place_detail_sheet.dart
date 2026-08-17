import 'package:flutter/material.dart';

import '../domain/nearby_place.dart';

/// Placeholder — replaced by the full implementation in the next plan
/// task.
Future<void> showNearbyPlaceDetailSheet(
  BuildContext context, {
  required NearbyPlaceResult result,
  required double distanceKm,
  String? tripId,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => const SizedBox(),
  );
}
