# Globe deep-zoom tiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real close-up detail on the globe past a deep zoom threshold, by fetching small covering tiles from NASA's public GIBS service and compositing them onto the existing bundled texture — network as a pure, silently-degrading enhancement, never a requirement.

**Architecture:** A pure tile-coordinate layer (`globe_tile_math.dart`) converts a lat/lng + globe zoom into the GIBS tiles that cover it. A `GlobeTileSource` abstraction (`globe_tile_source.dart`) fetches tile bytes, backed by a disk cache (via `path_provider`'s temp directory) so a previously-seen region works offline the second time and doesn't re-spend data. `journal_globe.dart` composites the fetched tiles onto a copy of the current base texture and feeds the result through the existing `FlutterEarthGlobeController.loadSurface()` call — no shader changes.

**Tech Stack:** Flutter, `package:http` (already a dependency), `package:path_provider` (already a dependency), `dart:ui` (`Canvas`/`PictureRecorder` for compositing).

## Global Constraints

- Local data is always the source of truth; network calls may enhance but never gate a core flow, and must degrade silently and gracefully — no spinner, no error UI, no blocking, on any failure (no connection, timeout, bad response, decode error). The globe's existing bundled tiers remain fully sufficient on their own at every zoom level up to `maxZoom`.
- Tests land in the same commit as the feature. Integration/network-touching tests mock the network boundary explicitly — no test in this codebase hits a real GIBS endpoint.
- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart` (n/a to this plan — no new colors).
- Widget/GPU-dependent rendering code stays manual-verification-only, consistent with every other change in `journal_globe.dart` this session; pull decision/math logic into plain, unit-testable functions instead.

## Verified GIBS API details (confirmed live against the real service during planning — not assumptions)

- **Layer:** `BlueMarble_ShadedRelief_Bathymetry`
- **TileMatrixSet:** `500m`
- **URL pattern (confirmed working, HTTP 200, real JPEG returned):**
  `https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/BlueMarble_ShadedRelief_Bathymetry/default/500m/{level}/{row}/{col}.jpg`
  No date/time component — this layer is a static composite, not date-varying.
- **Tile size:** 512×512px at every level.
- **Grid extent:** every level's `TopLeftCorner` is `-180, 90` (WGS84) — i.e. `col=0` is the international date line going east, `row=0` is the north pole going south. This matches the shader's own UV convention (`uv.x = 1.0 - (lon+PI)/TWO_PI`, `uv.y = (HALF_PI-lat)/PI`) up to the same west/east mirroring the shader comment already documents.
- **Levels 0–7**, `(MatrixWidth, MatrixHeight)` per level:
  `0: (2,1)`, `1: (3,2)`, `2: (5,3)`, `3: (10,5)`, `4: (20,10)`, `5: (40,20)`, `6: (80,40)`, `7: (160,80)`.

## Task 1: Tile-coordinate math (TDD, no network)

**Files:**
- Create: `lib/features/journal/domain/globe_tile_math.dart`
- Test: `test/unit/journal/globe_tile_math_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class GibsTileCoordinate {
    const GibsTileCoordinate({required this.level, required this.row, required this.col});
    final int level;
    final int row;
    final int col;
    String get path => 'BlueMarble_ShadedRelief_Bathymetry/default/500m/$level/$row/$col.jpg';
    @override
    bool operator ==(Object other) => ...
    @override
    int get hashCode => ...
  }

  int gibsLevelForGlobeZoom(double globeZoom);

  List<GibsTileCoordinate> tilesCoveringView({
    required double centerLat,
    required double centerLng,
    required int level,
    int gridSize = 3,
  });
  ```
  Task 2 and Task 3 both consume these three by name and exact signature.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/journal/globe_tile_math_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/journal/domain/globe_tile_math.dart';

void main() {
  group('gibsLevelForGlobeZoom', () {
    test('below tileZoomThreshold-equivalent still returns a valid level', () {
      // The globe's own zoom-gating (tileZoomThreshold) decides WHETHER to
      // call this at all — this function itself just maps any zoom to a
      // level and always returns something in [0, 7].
      expect(gibsLevelForGlobeZoom(0), inInclusiveRange(0, 7));
    });

    test('increases (or stays the same) as globe zoom increases', () {
      final levelAt6 = gibsLevelForGlobeZoom(6.0);
      final levelAt7 = gibsLevelForGlobeZoom(7.0);
      final levelAt8 = gibsLevelForGlobeZoom(8.0);
      expect(levelAt7, greaterThanOrEqualTo(levelAt6));
      expect(levelAt8, greaterThanOrEqualTo(levelAt7));
    });

    test('never exceeds the deepest available GIBS level (7)', () {
      expect(gibsLevelForGlobeZoom(100.0), 7);
    });

    test('never goes below 0', () {
      expect(gibsLevelForGlobeZoom(-100.0), 0);
    });
  });

  group('tilesCoveringView', () {
    test('returns gridSize x gridSize tiles centered near the given point',
        () {
      // Null Island (0,0) at level 3 (10x5 grid): center tile is col 5, row 2
      // (col = (0+180)/360*10 = 5, row = (90-0)/180*5 = 2.5 -> floor 2).
      final tiles = tilesCoveringView(
        centerLat: 0,
        centerLng: 0,
        level: 3,
        gridSize: 3,
      );
      expect(tiles, hasLength(9));
      expect(
        tiles.map((t) => t.row * 100 + t.col),
        contains(2 * 100 + 5),
      );
    });

    test('clamps row at the poles instead of going out of range', () {
      final tiles = tilesCoveringView(
        centerLat: 89.9,
        centerLng: 0,
        level: 2,
        gridSize: 3,
      );
      for (final tile in tiles) {
        expect(tile.row, greaterThanOrEqualTo(0));
      }
    });

    test('wraps column around the antimeridian instead of going out of '
        'range', () {
      // Longitude near +180 at level 2 (5 columns wide) — a 3-wide grid
      // centered there must wrap the rightmost column back to column 0
      // rather than requesting an out-of-range column.
      final tiles = tilesCoveringView(
        centerLat: 0,
        centerLng: 179.9,
        level: 2,
        gridSize: 3,
      );
      for (final tile in tiles) {
        expect(tile.col, inInclusiveRange(0, 4));
      }
    });

    test('all returned tiles share the requested level', () {
      final tiles = tilesCoveringView(
        centerLat: 40.7,
        centerLng: -74.0,
        level: 5,
        gridSize: 3,
      );
      expect(tiles.every((t) => t.level == 5), isTrue);
    });
  });

  group('GibsTileCoordinate', () {
    test('path matches the confirmed-working GIBS URL pattern', () {
      const tile = GibsTileCoordinate(level: 6, row: 10, col: 20);
      expect(
        tile.path,
        'BlueMarble_ShadedRelief_Bathymetry/default/500m/6/10/20.jpg',
      );
    });

    test('equal coordinates are ==', () {
      const a = GibsTileCoordinate(level: 1, row: 1, col: 1);
      const b = GibsTileCoordinate(level: 1, row: 1, col: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/journal/globe_tile_math_test.dart`
Expected: FAIL — `globe_tile_math.dart` doesn't exist yet.

- [ ] **Step 3: Implement `globe_tile_math.dart`**

```dart
import 'dart:math' as math;

/// One GIBS tile: NASA's public Blue Marble WMTS service
/// (`BlueMarble_ShadedRelief_Bathymetry` layer, `500m` TileMatrixSet,
/// EPSG:4326 — plain lat/lon, matching this app's shader's own
/// equirectangular UV mapping directly, no Mercator reprojection).
/// URL pattern and grid dimensions per level were confirmed live against
/// the real service while planning this feature — see
/// docs/superpowers/plans/2026-08-10-globe-deep-zoom-tiles.md.
class GibsTileCoordinate {
  const GibsTileCoordinate({
    required this.level,
    required this.row,
    required this.col,
  });

  final int level;
  final int row;
  final int col;

  /// The path segment appended to
  /// `https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/` to fetch this
  /// tile's JPEG bytes.
  String get path =>
      'BlueMarble_ShadedRelief_Bathymetry/default/500m/$level/$row/$col.jpg';

  @override
  bool operator ==(Object other) =>
      other is GibsTileCoordinate &&
      other.level == level &&
      other.row == row &&
      other.col == col;

  @override
  int get hashCode => Object.hash(level, row, col);

  @override
  String toString() => 'GibsTileCoordinate($level/$row/$col)';
}

/// (MatrixWidth, MatrixHeight) for the BlueMarble_ShadedRelief_Bathymetry
/// layer's `500m` TileMatrixSet, levels 0-7 — confirmed live against
/// GIBS's own capabilities document while planning this feature. Every
/// level's grid evenly divides the full -180..180 / -90..90 extent (each
/// level's TopLeftCorner is -180,90), so no per-level offset is needed.
const _gibsGridDimensions = <(int width, int height)>[
  (2, 1), // level 0
  (3, 2), // level 1
  (5, 3), // level 2
  (10, 5), // level 3
  (20, 10), // level 4
  (40, 20), // level 5
  (80, 40), // level 6
  (160, 80), // level 7
];

/// Maps the globe's own continuous `zoom` (range up to `maxZoom: 8`, see
/// journal_globe.dart) to a GIBS TileMatrix level in [0, 7]. Deliberately
/// simple and clamped at both ends — the globe's own `tileZoomThreshold`
/// decides *whether* this gets called at all (only past deep zoom), so
/// this function just needs to produce a reasonable level for whatever
/// zoom it's given, never to gate anything itself. Starting mapping for
/// on-device tuning, same as every other zoom constant in this file's
/// caller.
int gibsLevelForGlobeZoom(double globeZoom) {
  final level = (5 + (globeZoom - 6.0)).round();
  return level.clamp(0, _gibsGridDimensions.length - 1);
}

/// The [gridSize] x [gridSize] grid of tiles centered on the tile
/// containing ([centerLat], [centerLng]) at the given [level] — a small
/// margin around the exact center tile, not just the one tile, so the
/// composited patch still has coverage right up to its edges without an
/// immediate re-fetch. [gridSize] must be odd (so there's a true center
/// tile); defaults to 3 (a 3x3 grid).
///
/// Column wraps around the antimeridian (GIBS's grid, like the shader's
/// own UV mapping, treats longitude as cyclic). Row is clamped, not
/// wrapped, at the poles (there's no "other side" of the pole to wrap
/// to in an equirectangular grid).
List<GibsTileCoordinate> tilesCoveringView({
  required double centerLat,
  required double centerLng,
  required int level,
  int gridSize = 3,
}) {
  final (matrixWidth, matrixHeight) = _gibsGridDimensions[level];
  final centerCol =
      ((centerLng + 180) / 360 * matrixWidth).floor().clamp(0, matrixWidth - 1);
  final centerRow = ((90 - centerLat) / 180 * matrixHeight)
      .floor()
      .clamp(0, matrixHeight - 1);
  final half = gridSize ~/ 2;
  final tiles = <GibsTileCoordinate>[];
  for (var dRow = -half; dRow <= half; dRow++) {
    final row = (centerRow + dRow).clamp(0, matrixHeight - 1);
    for (var dCol = -half; dCol <= half; dCol++) {
      final col = (centerCol + dCol) % matrixWidth;
      final wrappedCol = col < 0 ? col + matrixWidth : col;
      tiles.add(GibsTileCoordinate(level: level, row: row, col: wrappedCol));
    }
  }
  return tiles;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/journal/globe_tile_math_test.dart`
Expected: PASS — all cases.

- [ ] **Step 5: Run `flutter analyze`**

Run: `flutter analyze lib/features/journal/domain/globe_tile_math.dart test/unit/journal/globe_tile_math_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/journal/domain/globe_tile_math.dart test/unit/journal/globe_tile_math_test.dart
git commit -m "feat(journal): add pure tile-coordinate math for GIBS deep-zoom tiles

GibsTileCoordinate + gibsLevelForGlobeZoom + tilesCoveringView — pure,
unit-tested, no network. Grid dimensions and URL pattern verified live
against the real GIBS service while planning (see the plan doc). Not
yet wired into any fetching or rendering code."
```

## Task 2: Tile fetching with a local disk cache (TDD, network boundary mocked)

**Files:**
- Create: `lib/features/journal/data/globe_tile_source.dart`
- Test: `test/unit/journal/globe_tile_source_test.dart`

**Interfaces:**
- Consumes: `GibsTileCoordinate` from Task 1.
- Produces:
  ```dart
  abstract class GlobeTileSource {
    Future<Uint8List?> fetchTile(GibsTileCoordinate coordinate);
  }

  class HttpGlobeTileSource implements GlobeTileSource {
    HttpGlobeTileSource({http.Client? client, Duration timeout = const Duration(seconds: 5)});
  }

  class CachedGlobeTileSource implements GlobeTileSource {
    CachedGlobeTileSource({
      required GlobeTileSource inner,
      required Directory cacheDirectory,
      int maxCacheBytes = 200 * 1024 * 1024,
    });
  }
  ```
  Task 3 consumes `GlobeTileSource` (the interface, not a concrete type) and constructs a `CachedGlobeTileSource(inner: HttpGlobeTileSource(), cacheDirectory: await getTemporaryDirectory())`.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/journal/globe_tile_source_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/journal/data/globe_tile_source.dart';
import 'package:tripper/features/journal/domain/globe_tile_math.dart';

class _FakeTileSource implements GlobeTileSource {
  _FakeTileSource(this.responses);

  final Map<GibsTileCoordinate, Uint8List?> responses;
  int fetchCount = 0;

  @override
  Future<Uint8List?> fetchTile(GibsTileCoordinate coordinate) async {
    fetchCount++;
    if (!responses.containsKey(coordinate)) {
      throw StateError('Unexpected fetch: $coordinate');
    }
    return responses[coordinate];
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('globe_tile_cache_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CachedGlobeTileSource', () {
    const tile = GibsTileCoordinate(level: 3, row: 2, col: 5);
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    test('fetches from the inner source and caches the result on a miss',
        () async {
      final fake = _FakeTileSource({tile: bytes});
      final cached = CachedGlobeTileSource(
        inner: fake,
        cacheDirectory: tempDir,
      );

      final result = await cached.fetchTile(tile);

      expect(result, bytes);
      expect(fake.fetchCount, 1);
      final cacheFile = File('${tempDir.path}/globe_tiles/${tile.path}');
      expect(await cacheFile.exists(), isTrue);
      expect(await cacheFile.readAsBytes(), bytes);
    });

    test('serves from disk cache on a hit without calling the inner source',
        () async {
      final fake = _FakeTileSource({tile: bytes});
      final cached = CachedGlobeTileSource(
        inner: fake,
        cacheDirectory: tempDir,
      );

      await cached.fetchTile(tile); // populates the cache
      final result = await cached.fetchTile(tile); // should hit cache

      expect(result, bytes);
      expect(fake.fetchCount, 1); // NOT 2 — second call never touched fake
    });

    test('a failed inner fetch (returns null) is not cached, and is '
        'retried on the next call', () async {
      final fake = _FakeTileSource({tile: null});
      final cached = CachedGlobeTileSource(
        inner: fake,
        cacheDirectory: tempDir,
      );

      final first = await cached.fetchTile(tile);
      final second = await cached.fetchTile(tile);

      expect(first, isNull);
      expect(second, isNull);
      expect(fake.fetchCount, 2); // retried both times, nothing wrongly cached
    });

    test('an inner source that throws surfaces as a null result, not an '
        'exception', () async {
      final cached = CachedGlobeTileSource(
        inner: _ThrowingTileSource(),
        cacheDirectory: tempDir,
      );

      final result = await cached.fetchTile(tile);

      expect(result, isNull);
    });

    test('evicts the least-recently-used file once the cache exceeds '
        'maxCacheBytes', () async {
      final fake = _FakeTileSource({
        const GibsTileCoordinate(level: 0, row: 0, col: 0): Uint8List(60),
        const GibsTileCoordinate(level: 0, row: 0, col: 1): Uint8List(60),
      });
      final cached = CachedGlobeTileSource(
        inner: fake,
        cacheDirectory: tempDir,
        maxCacheBytes: 100, // both tiles together (120 bytes) exceed this
      );

      await cached.fetchTile(const GibsTileCoordinate(level: 0, row: 0, col: 0));
      // A small real delay, not just a microtask gap — guarantees the two
      // files' modified timestamps are distinguishable even on a
      // filesystem/OS with coarse (e.g. 1-second) timestamp granularity,
      // so the LRU ordering this test asserts on isn't flaky.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await cached.fetchTile(const GibsTileCoordinate(level: 0, row: 0, col: 1));

      final firstStillCached = await File(
        '${tempDir.path}/globe_tiles/${const GibsTileCoordinate(level: 0, row: 0, col: 0).path}',
      ).exists();
      final secondStillCached = await File(
        '${tempDir.path}/globe_tiles/${const GibsTileCoordinate(level: 0, row: 0, col: 1).path}',
      ).exists();

      // The older (first-written) file should have been evicted to stay
      // under the cap; the newer one should remain.
      expect(firstStillCached, isFalse);
      expect(secondStillCached, isTrue);
    });
  });
}

class _ThrowingTileSource implements GlobeTileSource {
  @override
  Future<Uint8List?> fetchTile(GibsTileCoordinate coordinate) async {
    throw Exception('network error');
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/journal/globe_tile_source_test.dart`
Expected: FAIL — `globe_tile_source.dart` doesn't exist yet.

- [ ] **Step 3: Implement `globe_tile_source.dart`**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/globe_tile_math.dart';

/// Fetches a single GIBS tile's raw JPEG bytes, or null on any failure.
/// Never throws — every implementation catches its own errors, since a
/// failed tile fetch must degrade silently (see this plan's Global
/// Constraints) rather than propagate as an exception the caller has to
/// remember to catch.
abstract class GlobeTileSource {
  Future<Uint8List?> fetchTile(GibsTileCoordinate coordinate);
}

/// Fetches tiles over the network from GIBS's public WMTS endpoint.
class HttpGlobeTileSource implements GlobeTileSource {
  HttpGlobeTileSource({
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  static const _baseUrl = 'https://gibs.earthdata.nasa.gov/wmts/epsg4326/best';

  final http.Client _client;
  final Duration timeout;

  @override
  Future<Uint8List?> fetchTile(GibsTileCoordinate coordinate) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/${coordinate.path}'))
          .timeout(timeout);
      if (response.statusCode != 200) {
        debugPrint(
          'HttpGlobeTileSource: $coordinate returned ${response.statusCode}',
        );
        return null;
      }
      return response.bodyBytes;
    } catch (e) {
      debugPrint('HttpGlobeTileSource: failed to fetch $coordinate: $e');
      return null;
    }
  }
}

/// Wraps another [GlobeTileSource] with a disk cache under
/// `<cacheDirectory>/globe_tiles/<tile path>` — a previously-fetched
/// tile is served from disk without touching the network again, so
/// revisiting a region works offline and doesn't re-spend data (this
/// was the specific ask that added this class — see the design spec's
/// "local disk cache" section). [cacheDirectory] should be
/// `await getTemporaryDirectory()` in real use (OS-clearable, disposable
/// — every cached tile is trivially re-fetchable, so this is the right
/// semantics, same as this app's existing OCR scratch-file caching).
///
/// A failed inner fetch (null or a thrown exception) is never cached —
/// only genuinely successful tile bytes are written to disk — so a
/// transient failure is retried on the next attempt instead of being
/// "poisoned" permanently.
class CachedGlobeTileSource implements GlobeTileSource {
  CachedGlobeTileSource({
    required GlobeTileSource inner,
    required Directory cacheDirectory,
    int maxCacheBytes = 200 * 1024 * 1024,
  })  : _inner = inner,
        _cacheDir = Directory('${cacheDirectory.path}/globe_tiles'),
        _maxCacheBytes = maxCacheBytes;

  final GlobeTileSource _inner;
  final Directory _cacheDir;
  final int _maxCacheBytes;

  @override
  Future<Uint8List?> fetchTile(GibsTileCoordinate coordinate) async {
    final file = File('${_cacheDir.path}/${coordinate.path}');
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        // Touch the file's modified time so LRU eviction below sees this
        // as recently used, not stale.
        await file.setLastModified(DateTime.now());
        return bytes;
      } catch (e) {
        debugPrint('CachedGlobeTileSource: failed to read cached $coordinate: $e');
        // Fall through to re-fetch — a corrupt cache entry shouldn't be
        // a permanent dead end.
      }
    }

    final bytes = await _inner.fetchTile(coordinate);
    if (bytes == null) return null;

    try {
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      await _evictIfOverCap();
    } catch (e) {
      debugPrint('CachedGlobeTileSource: failed to write cache for $coordinate: $e');
      // Not fatal — the caller still gets the bytes, we just failed to
      // persist them for next time.
    }
    return bytes;
  }

  Future<void> _evictIfOverCap() async {
    if (!await _cacheDir.exists()) return;
    final files = await _cacheDir
        .list(recursive: true)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    var totalBytes = 0;
    final withStats = <(File file, int size, DateTime modified)>[];
    for (final file in files) {
      final stat = await file.stat();
      totalBytes += stat.size;
      withStats.add((file, stat.size, stat.modified));
    }
    if (totalBytes <= _maxCacheBytes) return;

    // Oldest-modified first — least-recently-used eviction.
    withStats.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (file, size, _) in withStats) {
      if (totalBytes <= _maxCacheBytes) break;
      try {
        await file.delete();
        totalBytes -= size;
      } catch (e) {
        debugPrint('CachedGlobeTileSource: failed to evict ${file.path}: $e');
      }
    }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/journal/globe_tile_source_test.dart`
Expected: PASS — all cases, including the eviction test.

- [ ] **Step 5: Run `flutter analyze`**

Run: `flutter analyze lib/features/journal/data/globe_tile_source.dart test/unit/journal/globe_tile_source_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/journal/data/globe_tile_source.dart test/unit/journal/globe_tile_source_test.dart
git commit -m "feat(journal): add GlobeTileSource with a local disk cache

HttpGlobeTileSource (real network fetch, never throws — failures return
null) + CachedGlobeTileSource (disk-backed, path_provider temp dir in
real use, size-capped LRU eviction) so a previously-viewed region works
offline and doesn't re-spend data. Fully tested against a fake inner
source and a real temp directory — no test touches the network. Not yet
wired into any rendering code."
```

## Task 3: Compositing and wiring into the globe

**Files:**
- Modify: `lib/features/journal/presentation/journal_globe.dart`

**Interfaces:**
- Consumes: `gibsLevelForGlobeZoom`, `tilesCoveringView`, `GibsTileCoordinate` (Task 1); `GlobeTileSource`, `HttpGlobeTileSource`, `CachedGlobeTileSource` (Task 2).
- Produces: no new public interface — this is the integration endpoint.

This task is GPU-rendering-dependent and has no automated test of its own, consistent with the plan's Global Constraints and every other rendering change in this file this session.

- [ ] **Step 1: Add the new zoom constants and state**

Change `maxZoom: 7,` (currently whatever the working tree has locally — search for `maxZoom:` in `_buildController`) to `maxZoom: 8,` and update its surrounding comment to mention the new deep-zoom-tile tier past `tileZoomThreshold`, following the same pattern the `highResGlobeZoomThreshold` comment already uses for documenting *why* a threshold sits where it does.

Add near the other top-level zoom/texture constants (alongside `highResGlobeZoomThreshold`):

```dart
// The zoom level past which the globe fetches real satellite tiles from
// NASA's public GIBS service instead of relying on the bundled texture
// tiers alone — see docs/superpowers/specs/2026-08-10-globe-deep-zoom-tiles-design.md
// for why this needs network at all (genuine close-up detail needs more
// source resolution than any single bundled file can safely hold — see
// PATCHES.md's account of the 233MP texture that never finished
// decoding). Sits above maxZoom's old ceiling (5) so the existing
// bundled tiers still cover the whole range they were tuned for; tiles
// only add detail past where those tiers run out. Starting value for
// on-device tuning, same as every other zoom constant in this file.
const tileZoomThreshold = 6.0;
```

In `_JournalGlobeState`, add new fields alongside `_lastClusters`/`_lastClusterBand`:

```dart
  /// The tile source deep-zoom compositing fetches through — constructed
  /// once `didChangeDependencies` has app-level context available (needs
  /// `getTemporaryDirectory()`, an async call, so it's built lazily on
  /// first use rather than in initState/didChangeDependencies directly).
  GlobeTileSource? _tileSource;

  /// The entry whose coordinates deep-zoom tiles were last composited
  /// around — re-composite is triggered when this changes (a proxy for
  /// "where the camera is centered": this app already tracks whichever
  /// entry is focused/selected via _focusedEntryId, and zooming in deep
  /// enough to trigger tiles almost always follows focusing on a
  /// specific entry first, so reusing that existing signal avoids
  /// needing to reach into the vendored package's private rotation
  /// state for a true camera-center readout).
  String? _tiledEntryId;

  /// Guards against overlapping fetch+composite operations if zoom or
  /// focus changes again while one is still in flight.
  bool _compositingTiles = false;
```

- [ ] **Step 2: Add the tile-source lazy getter and the composite method**

Add these new methods near `_handleZoomChanged`:

```dart
  Future<GlobeTileSource> _getTileSource() async {
    final existing = _tileSource;
    if (existing != null) return existing;
    final cacheDir = await getTemporaryDirectory();
    final source = CachedGlobeTileSource(
      inner: HttpGlobeTileSource(),
      cacheDirectory: cacheDir,
    );
    _tileSource = source;
    return source;
  }

  /// Fetches and composites deep-zoom tiles around [entry]'s coordinates
  /// onto a copy of the currently-loaded base texture, then loads the
  /// result the same way the tiered-zoom-texture feature already does —
  /// via controller.loadSurface(), wrapping the pre-built composite in
  /// [_PrebuiltImageProvider] so it flows through that exact method
  /// rather than duplicating its surface/surfaceProcessed-together
  /// assignment (see PATCHES.md's "close the surface/surfaceProcessed
  /// race" fix) or calling ChangeNotifier's @protected notifyListeners()
  /// directly from outside the controller class — flutter analyze
  /// correctly flags the latter (invalid_use_of_protected_member) since
  /// FlutterEarthGlobeController extends ChangeNotifier and this file is
  /// external to that class. Every failure (network, decode,
  /// compositing) is caught and silently ignored, leaving whatever
  /// texture is already loaded in place — see this file's onError-wired
  /// loadSurface for the same established pattern.
  Future<void> _compositeTilesAround(JournalEntry entry, double zoom) async {
    if (_compositingTiles) return;
    if (!entry.hasLocation) return;
    _compositingTiles = true;
    try {
      final controller = _controller;
      final baseSurface = controller?.surface;
      if (controller == null || baseSurface == null) return;

      final source = await _getTileSource();
      final level = gibsLevelForGlobeZoom(zoom);
      final tiles = tilesCoveringView(
        centerLat: entry.lat!,
        centerLng: entry.lng!,
        level: level,
      );

      final decodedTiles = <(GibsTileCoordinate coord, ui.Image image)>[];
      for (final coord in tiles) {
        final bytes = await source.fetchTile(coord);
        if (bytes == null) continue;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        decodedTiles.add((coord, frame.image));
      }
      if (decodedTiles.isEmpty) return; // no connection / all failed — bail silently

      final composite = await _drawComposite(baseSurface, decodedTiles);
      if (!mounted) return;
      controller.loadSurface(_PrebuiltImageProvider(composite));
    } catch (e) {
      debugPrint('JournalGlobe: deep-zoom tile compositing failed: $e');
    } finally {
      _compositingTiles = false;
    }
  }

  /// Draws [tiles] onto a copy of [base] at their correct equirectangular
  /// position (matching the shader's own UV convention: x=0 is -180deg
  /// longitude, y=0 is +90deg latitude, both increasing linearly), at
  /// base's own resolution scaled up proportionally to the tiles'
  /// combined coverage — so the result is one image the existing
  /// surface-loading path can use exactly like any bundled texture.
  Future<ui.Image> _drawComposite(
    ui.Image base,
    List<(GibsTileCoordinate coord, ui.Image image)> tiles,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = base.width.toDouble();
    final height = base.height.toDouble();
    canvas.drawImageRect(
      base,
      Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
      Rect.fromLTWH(0, 0, width, height),
      Paint(),
    );
    for (final (coord, image) in tiles) {
      final (matrixWidth, matrixHeight) = gibsGridDimensionsForLevel(coord.level);
      final destLeft = coord.col / matrixWidth * width;
      final destTop = coord.row / matrixHeight * height;
      final destWidth = width / matrixWidth;
      final destHeight = height / matrixHeight;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(destLeft, destTop, destWidth, destHeight),
        Paint(),
      );
    }
    final picture = recorder.endRecording();
    return picture.toImage(base.width, base.height);
  }
```

Add this new private class at the end of the file (alongside `_PhotoDot`/`_ClusterDot`'s former location — after the last class in the file):

```dart
/// Wraps an already-decoded [ui.Image] as an [ImageProvider], so a
/// synthesized image (the deep-zoom tile composite above) can be fed
/// through [FlutterEarthGlobeController.loadSurface] exactly like any
/// bundled [AssetImage] — reusing that method's existing
/// surface/surfaceProcessed-together assignment instead of duplicating
/// it, and avoiding a call to [ChangeNotifier]'s `@protected`
/// `notifyListeners()` from outside the controller class. Verified
/// against this project's installed Flutter SDK (3.44.6) — `loadImage`
/// takes an `ImageDecoderCallback` in this version; the callback is
/// never invoked here since there's nothing left to decode.
class _PrebuiltImageProvider extends ImageProvider<_PrebuiltImageProvider> {
  const _PrebuiltImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_PrebuiltImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _PrebuiltImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image)));
  }
}
```

- [ ] **Step 3: Expose `gibsGridDimensionsForLevel` from Task 1's file**

`_drawComposite` above needs the same per-level grid dimensions
`tilesCoveringView` already uses internally. Add this to
`lib/features/journal/domain/globe_tile_math.dart` (from Task 1),
alongside the existing private `_gibsGridDimensions` table:

```dart
/// Public accessor for [_gibsGridDimensions] — journal_globe.dart's
/// compositing step needs the same per-level grid to know where a tile
/// belongs on the destination canvas.
(int width, int height) gibsGridDimensionsForLevel(int level) =>
    _gibsGridDimensions[level];
```

- [ ] **Step 4: Trigger compositing from `_handleZoomChanged`**

In `_handleZoomChanged`, after the existing connection-refresh logic
(added in the previous plan) and before the method ends, add:

```dart
    if (zoom > tileZoomThreshold) {
      final focused = widget.entries.where((e) => e.id == _focusedEntryId).firstOrNull;
      final target = focused ?? latestLocatedEntry(widget.entries);
      if (target != null && target.id != _tiledEntryId) {
        _tiledEntryId = target.id;
        unawaited(_compositeTilesAround(target, zoom));
      }
    }
```

Add these imports to the top of the file: `import 'dart:async';` (for
`unawaited`), `import 'dart:ui' as ui;` (for `ui.Image`,
`ui.instantiateImageCodec`, `ui.PictureRecorder` — not currently
imported in this file; `Canvas`/`Paint`/`Rect` are already available via
the existing `package:flutter/material.dart` import, no separate import
needed for those), `import '../data/globe_tile_source.dart';`,
`import '../domain/globe_tile_math.dart';`, and
`import 'package:path_provider/path_provider.dart';`.

- [ ] **Step 5: Run the existing widget test suite for this file**

Run: `flutter test test/widget/journal/journal_globe_test.dart test/widget/journal/trip_journal_tab_test.dart`
Expected: PASS — the `renderGlobe: false` scaffold doesn't exercise any of this new code (it's all inside the real-controller path), so nothing here should regress.

- [ ] **Step 6: Run `flutter analyze`**

Run: `flutter analyze lib/features/journal/presentation/journal_globe.dart lib/features/journal/domain/globe_tile_math.dart`
Expected: No issues found.

- [ ] **Step 7: Manual on-device verification**

GPU-rendering- and network-dependent, cannot be automated (see CLAUDE.md's Verification section). With a real device and a real connection:
- Focus on an entry, zoom in past `tileZoomThreshold` (6.0), and confirm the globe visibly gets sharper in that region within a few seconds (not instantly — this is a real network fetch).
- Turn off the device's connection, repeat — confirm the globe still renders fine at the bundled tiers, with no spinner, no error, no crash, no hang. It just doesn't get any sharper past the threshold.
- Reconnect, zoom into the *same* previously-tiled region again — confirm it's fast this time (served from the disk cache, not re-fetched) — check `adb logcat` for the absence of new `HttpGlobeTileSource` fetch activity if the vendored `debugPrint`s make that visible, or just note the qualitative speed difference.
- Zoom into a *different* region past the threshold and confirm new tiles load for that region too (compositing isn't stuck on the first region fetched).

Report back the observed behavior before proceeding to commit.

- [ ] **Step 8: Commit**

```bash
git add lib/features/journal/presentation/journal_globe.dart lib/features/journal/domain/globe_tile_math.dart
git commit -m "feat(journal): fetch and composite real satellite tiles past deep zoom

Past tileZoomThreshold (6.0, with maxZoom raised 7->8), fetches GIBS
tiles covering the currently-focused entry's location and composites
them onto the loaded base texture via the existing loadSurface() path.
Every failure mode (no connection, timeout, decode error) silently
leaves the current texture in place. Manually verified on-device per
docs/superpowers/plans/2026-08-10-globe-deep-zoom-tiles.md, including
the offline-fallback and disk-cache-reuse paths specifically."
```

## Self-Review Notes

- **Spec coverage:** GIBS as source (Task 3, with API details verified live and baked into Task 1 rather than left as an open item), viewport→tiles math (Task 1), fetch+local disk cache (Task 2), compositing via existing `loadSurface` (Task 3), CLAUDE.md-compliant silent degradation (every catch block in Task 2/3 falls back without surfacing an error), testing (Tasks 1-2 fully automated and network-mocked; Task 3 manual per established pattern). "Out of scope" items from the design (CPU-fallback support, continuous pan-following, other GIBS layers, a Wi-Fi-only setting) — none introduced.
- **Re-trigger mechanism refined from the design doc:** the design's "re-trigger on pan/rotate" section assumed reading the camera's true rotation-derived center; this plan uses `_focusedEntryId` instead (a signal the app already tracks and reacts to elsewhere) to avoid reaching into the vendored package's private `RotatingGlobeState.rotationX/Y/Z` fields for a fragile, unsupported readout. This is a deliberate simplification within the design's intent (re-fetch when where-you're-looking changes), not a contradiction of it.
- **Placeholder scan:** no TBD/TODO; every step has complete code. The GIBS API details section replaces what would otherwise have been the design's "open verification item" with confirmed, concrete facts (layer name, URL pattern, grid dimensions per level) obtained via a live request during planning.
- **Type consistency:** `GibsTileCoordinate`, `gibsLevelForGlobeZoom`, `tilesCoveringView`, `gibsGridDimensionsForLevel` (Task 1) are consumed with matching signatures in Task 3. `GlobeTileSource`/`HttpGlobeTileSource`/`CachedGlobeTileSource` (Task 2) are consumed identically in Task 3's `_getTileSource`.
- **Caught during planning, fixed inline:** an earlier draft of Task 3 Step 2 set `controller.surface` directly and called `controller.notifyListeners()` — `ChangeNotifier.notifyListeners()` is `@protected`, and `FlutterEarthGlobeController` extends `ChangeNotifier`, so calling it from `journal_globe.dart` (external to that class) would have been flagged by `flutter analyze` as `invalid_use_of_protected_member`, only surfacing at Task 3 Step 6, after the rest of the compositing logic was already written against the wrong assumption. Fixed by wrapping the composite in a small custom `ImageProvider` (`_PrebuiltImageProvider`) and routing it through the existing, already-correct `controller.loadSurface()` instead — verified the exact `ImageProvider.loadImage`/`OneFrameImageStreamCompleter` signatures directly against this project's installed Flutter SDK (3.44.6) rather than assuming an API shape that might have changed across versions. Also added a small real delay to Task 2's LRU eviction test, which would otherwise risk flakiness on filesystems with coarse timestamp granularity.
