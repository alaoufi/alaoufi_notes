/**
 * Syanah service worker.
 *
 * Strategy:
 *   - Static assets / fonts → cache-first (precached on install)
 *   - Navigation requests   → network-first with cached /offline fallback
 *   - API and Supabase calls → network only (never cache user data)
 *
 * Bump CACHE_VERSION whenever the precache list changes so old caches get
 * pruned in `activate`.
 */

const CACHE_VERSION = "syanah-v1";
const PRECACHE = [
  "/",
  "/offline",
  "/icon.svg",
  "/apple-icon.svg",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE_VERSION)
      .then((cache) => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
      .catch(() => {
        // If precache fails (offline first install), still install — runtime cache will take over.
      }),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k))),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);

  // Never intercept Supabase, auth, or external APIs.
  if (
    url.hostname.includes("supabase.co") ||
    url.hostname.includes("googleapis.com") ||
    url.pathname.startsWith("/api/") ||
    url.pathname.startsWith("/_next/data/")
  ) {
    return;
  }

  // Navigation requests → network-first with offline fallback.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then((c) => c.put(request, copy)).catch(() => {});
          return res;
        })
        .catch(() =>
          caches.match(request).then((cached) => cached || caches.match("/offline")),
        ),
    );
    return;
  }

  // Static assets → cache-first.
  if (
    url.pathname.startsWith("/_next/static/") ||
    /\.(?:js|css|woff2?|svg|png|jpg|jpeg|gif|webp|ico)$/.test(url.pathname)
  ) {
    event.respondWith(
      caches.match(request).then(
        (cached) =>
          cached ||
          fetch(request)
            .then((res) => {
              if (res && res.status === 200 && res.type === "basic") {
                const copy = res.clone();
                caches.open(CACHE_VERSION).then((c) => c.put(request, copy)).catch(() => {});
              }
              return res;
            })
            .catch(() => cached),
      ),
    );
  }
});

// Push notification handler — wired in but inert until VAPID + a push backend
// land. Until then nothing calls registration.pushManager.subscribe.
self.addEventListener("push", (event) => {
  if (!event.data) return;
  let payload;
  try {
    payload = event.data.json();
  } catch {
    payload = { title: "Syanah", body: event.data.text() };
  }
  const title = payload.title || "Syanah";
  const options = {
    body: payload.body || "",
    icon: "/icon.svg",
    badge: "/icon.svg",
    data: { url: payload.url || "/" },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = event.notification.data?.url || "/";
  event.waitUntil(
    self.clients.matchAll({ type: "window" }).then((wins) => {
      for (const w of wins) {
        if (w.url.includes(target) && "focus" in w) return w.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow(target);
    }),
  );
});
