import 'package:flutter/foundation.dart';

import '../data/journal_photo_exif.dart';

/// What to apply to the entry-creation form after a photo's EXIF data
/// clears [PhotoAutoFillPolicy.consider] — a field left `null` here means
/// "leave the form's own value alone", not "clear it".
@immutable
class PhotoAutoFillResult {
  const PhotoAutoFillResult({this.loggedAt, this.lat, this.lng});

  final DateTime? loggedAt;
  final double? lat;
  final double? lng;
}

/// The "fill from the first photo that has something to give, and only
/// once" rule for the journal entry-creation form: every added photo is
/// offered to [consider] until one actually supplies a time and/or a
/// location, after which every later photo is ignored regardless of what
/// its own EXIF data holds. A field the user has already set by hand
/// ([loggedAtTouched] / [locationTouched]) is never overwritten — but a
/// photo that could only have filled an already-touched field doesn't
/// count as a use of the "first photo" slot, since it supplied nothing.
class PhotoAutoFillPolicy {
  bool _done = false;
  bool loggedAtTouched = false;
  bool locationTouched = false;

  bool get done => _done;

  PhotoAutoFillResult? consider(PhotoExifData exif) {
    if (_done) return null;

    final loggedAt = loggedAtTouched ? null : exif.takenAt;
    final hasLocation = !locationTouched && exif.hasLocation;

    if (loggedAt == null && !hasLocation) return null;

    _done = true;
    return PhotoAutoFillResult(
      loggedAt: loggedAt,
      lat: hasLocation ? exif.lat : null,
      lng: hasLocation ? exif.lng : null,
    );
  }
}
