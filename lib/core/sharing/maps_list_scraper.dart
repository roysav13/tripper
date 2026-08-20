import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../routing/app_router.dart';

/// What a shared Google Maps list scrapes down to: a title guess and the
/// place names found in its (virtualized) list panel. No coordinates —
/// Google's DOM never carries them, only names/ratings/category text
/// (confirmed during design against a real shared list — see the spec).
@immutable
class ScrapedMapsList {
  const ScrapedMapsList({required this.title, required this.placeNames});

  final String? title;
  final List<String> placeNames;
}

/// Widget/unit tests fake at this boundary — the real implementation talks
/// to a live Google Maps page via a WebView and cannot itself be
/// unit-tested (see the design spec's Testing section).
abstract interface class MapsListScraper {
  /// Returns null on any failure (timeout, offline, unreadable page) —
  /// never throws. [listUrl] is the resolved `MapsListShare.url`.
  Future<ScrapedMapsList?> scrape(String listUrl);
}

/// Strips Google's known " - Google Maps" document-title suffix (present
/// because [WebViewMapsListScraper] forces `hl=en`). Pure, unit-tested
/// separately from the WebView plumbing around it.
String? cleanScrapedListTitle(String? documentTitle) {
  if (documentTitle == null) return null;
  var title = documentTitle;
  const suffix = ' - Google Maps';
  if (title.endsWith(suffix)) {
    title = title.substring(0, title.length - suffix.length);
  }
  title = title.trim();
  return title.isEmpty ? null : title;
}

/// Forces English UI locale on a Google Maps URL — scraped text stays in
/// Latin script regardless of the sharer's Google account locale.
Uri _withEnglishLocale(String url) {
  final uri = Uri.parse(url);
  return uri.replace(
    queryParameters: {...uri.queryParameters, 'hl': 'en'},
  );
}

const _maxScrollIterations = 30;
const _scrapeTimeout = Duration(seconds: 20);

/// Google's list panel — verified during design against a real shared
/// list, but this is exactly the "unstable, obfuscated DOM" the spec
/// flags as this feature's most fragile piece. If a future Maps layout
/// change breaks this selector, `_readVisibleNames` returns an empty
/// batch (not a crash) and `scrape()` degrades to `null` — adjust this
/// constant against a real shared list link if that happens.
const _feedSelector = '[role="feed"]';
const _placeNameSelector =
    '$_feedSelector [role="button"] > div > div:first-child';

/// Scrolls a shared Google Maps list's place panel and reads back place
/// names via an injected JS loop. Every failure mode here (timeout,
/// missing elements, malformed result) degrades to `null`, never a crash
/// or a hang (CLAUDE.md hard rule 4) — this class is explicitly not
/// unit-testable; see the spec's Testing section.
class WebViewMapsListScraper implements MapsListScraper {
  @override
  Future<ScrapedMapsList?> scrape(String listUrl) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return null;

    final controller = WebViewController();
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    final completer = Completer<ScrapedMapsList?>();
    var settled = false;
    void complete(ScrapedMapsList? result) {
      if (settled) return;
      settled = true;
      completer.complete(result);
    }

    unawaited(
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            try {
              complete(await _collect(controller));
            } catch (_) {
              complete(null);
            }
          },
          onWebResourceError: (_) => complete(null),
        ),
      ),
    );

    final route = PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, __, ___) => IgnorePointer(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: WebViewWidget(controller: controller),
            ),
          ),
        ),
      ),
    );
    // MapsListImportScreen.initState() calls scrape() synchronously as part
    // of its own push's build phase, while the navigator is still locked —
    // pushing the invisible WebView route right here would hit
    // "'!navigator._debugLocked': is not true" (confirmed on-device, see
    // Task 3 Step 8's manual-verification note). Defer to the frame after
    // the current build finishes.
    await WidgetsBinding.instance.endOfFrame;
    unawaited(navigator.push(route));

    final overallTimeout = Timer(_scrapeTimeout, () => complete(null));
    unawaited(
      controller.loadRequest(_withEnglishLocale(listUrl)).catchError((_) {
        complete(null);
      }),
    );

    final result = await completer.future;
    overallTimeout.cancel();
    if (navigator.canPop()) navigator.pop();
    return result;
  }

  Future<ScrapedMapsList?> _collect(WebViewController controller) async {
    final rawTitle = await controller.getTitle();
    final names = <String>{};
    for (var i = 0; i < _maxScrollIterations; i++) {
      final before = names.length;
      names.addAll(await _readVisibleNames(controller));
      if (names.length == before && i > 0) break;
      await controller.runJavaScript(
        "document.querySelector('$_feedSelector')?.scrollBy(0, 800);",
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (names.isEmpty) return null;
    return ScrapedMapsList(
      title: cleanScrapedListTitle(rawTitle),
      placeNames: names.toList(),
    );
  }

  Future<List<String>> _readVisibleNames(WebViewController controller) async {
    try {
      final raw = await controller.runJavaScriptReturningResult(
        'JSON.stringify(Array.from(document.querySelectorAll('
        "'$_placeNameSelector')).map(e => e.textContent.trim())"
        '.filter(t => t.length > 0))',
      );
      // Android's WebView can return a JSON-encoded *string literal*
      // (quotes escaped) rather than raw JSON for a runJavaScript result —
      // decode twice when that's the shape.
      var value = raw is String ? raw : raw.toString();
      try {
        final once = jsonDecode(value);
        if (once is String) value = once;
      } catch (_) {
        // Already the right shape.
      }
      final list = jsonDecode(value);
      if (list is List) return list.whereType<String>().toList();
    } catch (_) {
      // Malformed/unexpected JS result — treat as "found nothing this
      // pass", not a fatal error (the loop's stability check handles it).
    }
    return const [];
  }
}

final mapsListScraperProvider = Provider<MapsListScraper>(
  (ref) => WebViewMapsListScraper(),
);
