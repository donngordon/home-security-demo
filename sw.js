// Lets the demo open even without internet after the first visit.
const CACHE = "home-security-demo-v11";
const FILES = ["./", "index.html", "security.webmanifest", "security-icon-192.png", "security-icon-512.png", "security-icon-180.png"];
self.addEventListener("install", (e) => e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FILES))));
self.addEventListener("activate", (e) => e.waitUntil(
  caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))));
self.addEventListener("fetch", (e) => e.respondWith(
  fetch(e.request).then((r) => { const copy = r.clone(); caches.open(CACHE).then((c) => c.put(e.request, copy)); return r; })
    .catch(() => caches.match(e.request))));
