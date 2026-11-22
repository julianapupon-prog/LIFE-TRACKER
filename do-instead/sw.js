// Offline support. The page itself is fetched network-first so updates show up
// right away; everything else (icons, fonts) is served from cache when possible.
var CACHE = 'doinstead-v1';
var CORE = ['./', 'index.html', 'manifest.webmanifest', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png'];

self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(CORE); }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (keys) {
    return Promise.all(keys.filter(function (k) { return k.indexOf('doinstead-') === 0 && k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  var isPage = req.mode === 'navigate';
  var isFont = /fonts\.(googleapis|gstatic)\.com$/.test(url.hostname) || false;
  if (url.origin !== location.origin && !isFont) return;

  function put(res) {
    if (res && (res.ok || res.type === 'opaque')) {
      var copy = res.clone();
      caches.open(CACHE).then(function (c) { c.put(isPage ? 'index.html' : req, copy); });
    }
    return res;
  }

  if (isPage) {
    e.respondWith(fetch(req).then(put).catch(function () { return caches.match('index.html'); }));
  } else {
    e.respondWith(caches.match(req).then(function (hit) { return hit || fetch(req).then(put); }));
  }
});
