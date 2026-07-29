import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/settings/settings_service.dart';
import '../domain/exchange_rates.dart';

/// Cached rates live here rather than in Drift on purpose: they're a
/// disposable cache, not user data. Losing them costs one refetch, and
/// they must NOT end up in the backup archive (M4.5) as if they were
/// something worth restoring.
const _kRatesCache = 'exchange_rates_cache_v1';

/// Refetch at most this often. Conversions are stored per expense at
/// spend time, so a slightly stale rate only affects newly-added
/// expenses — no need to hammer the endpoint.
const kRatesMaxAge = Duration(hours: 12);

abstract interface class ExchangeRateSource {
  /// Rates for [base], or null on any failure (offline, bad response,
  /// rate-limited). Never throws — callers treat null as "not now".
  Future<ExchangeRateSnapshot?> fetch(String base);
}

/// open.er-api.com: free, no API key, ~160 currencies (wider than the
/// ECB-based alternatives, which matters for travel — THB, VND, AED).
///
/// NOTE: the endpoint shape could not be verified from the build
/// sandbox (no network). If conversion never populates on device, check
/// this response parsing first — the `[rates]` debug line below prints
/// what actually came back.
class ErApiExchangeRateSource implements ExchangeRateSource {
  ErApiExchangeRateSource(this._client, this._clock);

  final http.Client _client;
  final DateTime Function() _clock;

  @override
  Future<ExchangeRateSnapshot?> fetch(String base) async {
    try {
      final response = await _client
          .get(Uri.https('open.er-api.com', '/v6/latest/$base'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[rates] HTTP ${response.statusCode}');
        }
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final rawRates = decoded['rates'];
      if (rawRates is! Map<String, dynamic>) return null;

      final rates = <String, double>{};
      for (final entry in rawRates.entries) {
        final value = entry.value;
        if (value is num) rates[entry.key.toUpperCase()] = value.toDouble();
      }
      if (rates.isEmpty) return null;
      return ExchangeRateSnapshot(
        base: base.toUpperCase(),
        rates: rates,
        fetchedAt: _clock(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[rates] fetch failed: $e');
      return null;
    }
  }
}

/// Wraps a source with a prefs-backed cache so the app can convert
/// without a network round-trip on every launch.
class ExchangeRateService {
  ExchangeRateService(this._source, this._prefs, this._clock);

  final ExchangeRateSource _source;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  ExchangeRateSnapshot? readCached() {
    final raw = _prefs.getString(_kRatesCache);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final rates = <String, double>{};
      final rawRates = decoded['rates'];
      if (rawRates is! Map<String, dynamic>) return null;
      for (final entry in rawRates.entries) {
        final value = entry.value;
        if (value is num) rates[entry.key] = value.toDouble();
      }
      return ExchangeRateSnapshot(
        base: decoded['base'] as String,
        rates: rates,
        fetchedAt:
            DateTime.fromMillisecondsSinceEpoch(decoded['fetchedAt'] as int),
      );
    } catch (_) {
      return null; // corrupt cache is just a cache miss
    }
  }

  Future<void> _write(ExchangeRateSnapshot snapshot) async {
    await _prefs.setString(
      _kRatesCache,
      jsonEncode({
        'base': snapshot.base,
        'rates': snapshot.rates,
        'fetchedAt': snapshot.fetchedAt.millisecondsSinceEpoch,
      }),
    );
  }

  /// Cached rates for [base] if fresh; otherwise tries the network and
  /// falls back to whatever is cached (even stale) rather than nothing —
  /// a rate from yesterday converts far better than no rate at all.
  Future<ExchangeRateSnapshot?> ratesFor(String base) async {
    final target = base.toUpperCase();
    final cached = readCached();
    final usable = cached != null &&
        cached.base == target &&
        !cached.isStale(_clock(), kRatesMaxAge);
    if (usable) return cached;

    final fresh = await _source.fetch(target);
    if (fresh != null) {
      await _write(fresh);
      return fresh;
    }
    return cached != null && cached.base == target ? cached : null;
  }
}

final exchangeRateSourceProvider = Provider<ExchangeRateSource>(
  (ref) => ErApiExchangeRateSource(http.Client(), ref.watch(clockProvider)),
);

final exchangeRateServiceProvider = Provider<ExchangeRateService>(
  (ref) => ExchangeRateService(
    ref.watch(exchangeRateSourceProvider),
    ref.watch(sharedPreferencesProvider),
    ref.watch(clockProvider),
  ),
);
