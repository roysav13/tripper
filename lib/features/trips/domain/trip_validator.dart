enum TripValidationError {
  nameRequired,
  noDestination,
  endWithoutStart,
  datesInverted,
  tooLong,
}

/// Pure validation. Dates are optional (planned trips, one-way tickets);
/// when both exist they must be ordered and sane.
List<TripValidationError> validateTrip({
  required String name,
  required List<String> destinations,
  required DateTime? startDate,
  required DateTime? endDate,
  int maxLengthDays = 365,
}) {
  final errors = <TripValidationError>[];
  if (name.trim().isEmpty) errors.add(TripValidationError.nameRequired);
  if (destinations.where((d) => d.trim().isNotEmpty).isEmpty) {
    errors.add(TripValidationError.noDestination);
  }
  if (endDate != null && startDate == null) {
    errors.add(TripValidationError.endWithoutStart);
  }
  if (startDate != null && endDate != null) {
    if (endDate.isBefore(startDate)) {
      errors.add(TripValidationError.datesInverted);
    } else if (endDate.difference(startDate).inDays + 1 > maxLengthDays) {
      errors.add(TripValidationError.tooLong);
    }
  }
  return errors;
}
