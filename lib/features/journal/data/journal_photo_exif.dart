import 'package:cross_file/cross_file.dart';
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';

/// EXIF data pulled off a journal photo — whatever the file happened to
/// carry. Either field may be null; a photo with neither is read as `null`
/// by [readPhotoExifData] rather than an all-null instance of this class.
@immutable
class PhotoExifData {
  const PhotoExifData({this.takenAt, this.lat, this.lng});

  final DateTime? takenAt;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;
}

/// Reads the GPS + capture-time EXIF tags off a photo file. Best-effort —
/// any failure (not a real image, no EXIF segment, corrupt data) degrades
/// to `null`, never throws (CLAUDE.md hard rule 4): this is an enhancement
/// to the journal entry form, not something it can depend on.
Future<PhotoExifData?> readPhotoExifData(String filePath) async {
  try {
    // XFile, not File: [filePath] is a picker handle, which is a `blob:`
    // URL rather than a filesystem path in the browser.
    final bytes = await XFile(filePath).readAsBytes();
    final tags = await readExifFromBytes(bytes);
    final coords = extractGpsCoordinates(tags);
    final takenAt = extractPhotoTakenAt(tags);
    if (coords == null && takenAt == null) return null;
    return PhotoExifData(takenAt: takenAt, lat: coords?.lat, lng: coords?.lng);
  } catch (e) {
    debugPrint('[journal] photo EXIF read failed: $e');
    return null;
  }
}

/// Pure parser — unit-tested directly against constructed [IfdTag] fixtures,
/// no file I/O. Degrees/minutes/seconds convert to decimal degrees; the
/// reference tags (`N`/`S`/`E`/`W`) decide the sign. Null whenever any of
/// the four GPS tags is missing or isn't the ratio triple it should be —
/// never a guess.
({double lat, double lng})? extractGpsCoordinates(Map<String, IfdTag> tags) {
  final lat = _dmsToDecimal(
    tags['GPS GPSLatitude'],
    tags['GPS GPSLatitudeRef'],
    negativeRef: 'S',
  );
  final lng = _dmsToDecimal(
    tags['GPS GPSLongitude'],
    tags['GPS GPSLongitudeRef'],
    negativeRef: 'W',
  );
  if (lat == null || lng == null) return null;
  return (lat: lat, lng: lng);
}

double? _dmsToDecimal(
  IfdTag? dmsTag,
  IfdTag? refTag, {
  required String negativeRef,
}) {
  if (dmsTag == null || refTag == null) return null;
  final values = dmsTag.values;
  if (values is! IfdRatios || values.ratios.length < 3) return null;
  final degrees = values.ratios[0].toDouble();
  final minutes = values.ratios[1].toDouble();
  final seconds = values.ratios[2].toDouble();
  var decimal = degrees + minutes / 60 + seconds / 3600;
  if (refTag.printable.trim().toUpperCase() == negativeRef) {
    decimal = -decimal;
  }
  return decimal;
}

final _exifDateTime =
    RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$');

/// Pure parser — unit-tested directly against constructed [IfdTag] fixtures.
/// `DateTimeOriginal` (when the shutter fired) is preferred over the
/// coarser `Image DateTime` (last file-modified stamp). Null on anything
/// that doesn't match the standard EXIF `yyyy:MM:dd HH:mm:ss` form.
DateTime? extractPhotoTakenAt(Map<String, IfdTag> tags) {
  final raw = tags['EXIF DateTimeOriginal']?.printable.trim() ??
      tags['Image DateTime']?.printable.trim();
  if (raw == null || raw.isEmpty) return null;
  final match = _exifDateTime.firstMatch(raw);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}
