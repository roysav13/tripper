// Custom bootstrap template — `flutter build web` fills in the two
// placeholders below and copies this to build/web/flutter_bootstrap.js.
//
// It exists to replace Flutter's own service-worker registration, which is
// deprecated: as of Flutter 3.35 the generated `flutter_service_worker.js`
// does nothing but unregister itself, so an app that wants to work offline
// has to bring its own. Ours is `sw.js`, and offline is not optional here —
// Tripper is local-first, and the whole point of the installed web build is
// a travel app that opens on a plane.
{{flutter_js}}
{{flutter_build_config}}

if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('sw.js').catch(function (error) {
      // Not fatal: without a service worker the app still runs online.
      console.warn('Offline cache unavailable:', error);
    });
  });
}

// No `serviceWorkerSettings` — passing one would register Flutter's
// deprecated stub alongside ours and log a deprecation warning.
_flutter.loader.load();
