// Offline support. The page itself is fetched network-first so updates show up
// right away; everything else (icons, fonts) is served from cache when possible.
var CACHE = 'lifelog-v5';
var CORE = ['./', 'index.html', 'manifest.webmanifest', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png'];

self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(CORE); }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (keys) {
    return Promise.all(keys.filter(function (k) { return k.indexOf('lifelog-') === 0 && k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  var isPage = req.mode === 'navigate';
  var isFont = /fonts\.(googleapis|gstatic)\.com$/.test(url.hostname) || url.hostname === 'cdn.jsdelivr.net';
  if (url.origin !== location.origin && !isFont) return;

  function put(res) {
    if (res && (res.ok || res.type === 'opaque')) {
      var copy = res.clone();
      caches.open(CACHE).then(function (c) { c.put(isPage ? 'index.html' : req, copy); });
    }
    return res;
  }

  if (isPage) {
    // cache: 'no-cache' asks GitHub for the newest page every time (its own cache lasts 10 minutes)
    e.respondWith(fetch(req, { cache: 'no-cache' }).then(put).catch(function () { return caches.match('index.html'); }));
  } else {
    e.respondWith(caches.match(req).then(function (hit) { return hit || fetch(req).then(put); }));
  }
});
