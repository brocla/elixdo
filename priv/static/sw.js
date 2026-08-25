self.addEventListener("push", (event) => {
  const data = event.data?.json() ?? {};
  event.waitUntil(
    self.registration.showNotification(data.title ?? "Elixdo", {
      body: data.body ?? "",
      icon: "/images/web-app-manifest-192x192.png",
      badge: "/images/badge-96x96_2.0.png"
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow("/"));
});

const CACHE = "elixdo-shell-v1";
const SHELL = ["/assets/css/app.css", "/assets/js/app.js"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  // Skip non-GET, cross-origin, API routes, and LiveView transports. The socket
  // lives at /live/websocket and /live/longpoll, not /live itself, so this has
  // to be a prefix match. Nothing reaches it today — WebSocket upgrades do not
  // fire fetch events, and app.js configures no long-poll fallback — but it
  // becomes load-bearing the moment that fallback is enabled, since an
  // intercepted poll resolves to an uncached miss on any network hiccup.
  if (
    e.request.method !== "GET" ||
    url.origin !== self.location.origin ||
    url.pathname.startsWith("/api") ||
    url.pathname === "/live" ||
    url.pathname.startsWith("/live/")
  ) return;

  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok && SHELL.includes(url.pathname)) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});
