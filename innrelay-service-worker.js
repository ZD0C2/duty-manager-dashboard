const CACHE_NAME = "innrelay-prototype-v9";
const APP_SHELL = [
  "./innrelay-prototype.html",
  "./innrelay-guest.html",
  "./innrelay.webmanifest",
  "./innrelay-guest.webmanifest",
  "./innrelay-issue-catalog.js",
  "./innrelay-supabase-config.js",
  "./innrelay-qr.js?v=9",
  "./innrelay-icon.svg"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  const requestUrl = new URL(event.request.url);
  const needsFreshCopy = event.request.mode === "navigate" ||
    requestUrl.pathname.endsWith("innrelay-supabase-config.js") ||
    requestUrl.pathname.endsWith("innrelay-qr.js");
  if (needsFreshCopy) {
    event.respondWith(
      fetch(event.request).then((response) => {
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        return response;
      }).catch(() => caches.match(event.request))
    );
    return;
  }
  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request))
  );
});
