// Tripper's offline cache.
//
// Flutter stopped generating a caching service worker (the one it still
// emits only unregisters itself), so this is hand-written. It has to be:
// an installed Tripper is a local-first travel app, and "works on a plane"
// is the reason the web build exists at all.
//
// BUILD_ID is rewritten by tool/build_web.ps1 on every release build. It
// names the cache, so a new build starts from an empty one and the old
// one is dropped on activate — that, rather than per-file revalidation, is
// what makes a deploy take effect.
const BUILD_ID = '__BUILD_ID__';
const CACHE = 'tripper-' + BUILD_ID;

// Everything needed to render the first frame with no network, plus the
// SQLite engine — without those two the app opens to a blank page or an
// empty database, which is worse than not opening. The rest (CanvasKit
// variants, fonts, the globe texture, pdf.js) is cached on first use
// below: reaching the install prompt already means one online load, and
// that load fetches them.
const PRECACHE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/apple-touch-icon-180.png',
  'sqlite3.wasm',
  'drift_worker.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      // Individually, not addAll: addAll rejects the whole install if any
      // single entry 404s, which would leave the app with no cache at all
      // over one renamed file.
      await Promise.all(
        PRECACHE.map((path) =>
          cache.add(new Request(path, { cache: 'reload' })).catch((error) => {
            console.warn('Could not precache', path, error);
          })
        )
      );
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name.startsWith('tripper-') && name !== CACHE)
          .map((name) => caches.delete(name))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // Cross-origin (the Google Maps JS API) is never cached: it is the one
  // thing here that is allowed to need the network, and it degrades to
  // "no map" on its own.
  if (url.origin !== self.location.origin) return;

  // Navigations resolve to the app shell so a cold offline launch from the
  // home screen renders, whatever path the PWA was installed at.
  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        const cached = await caches.match('index.html', { ignoreSearch: true });
        if (cached) return cached;
        return fetch(request);
      })()
    );
    return;
  }

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      // Cache-first is safe because the cache name carries BUILD_ID: a new
      // deploy can never be served a stale asset from an old build.
      const cached = await cache.match(request, { ignoreSearch: true });
      if (cached) return cached;

      try {
        const response = await fetch(request);
        // Only full, same-origin 200s. A partial (206) or an opaque
        // response would poison the cache with something unreplayable.
        if (response.ok && response.status === 200) {
          cache.put(request, response.clone());
        }
        return response;
      } catch (error) {
        // Offline and never fetched before — let the caller see the
        // failure rather than a fabricated empty body.
        throw error;
      }
    })()
  );
});
