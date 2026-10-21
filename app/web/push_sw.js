// Service worker for notifications (Web Push), registered by push.js when
// the user turns them on in Mais, in its own scope ("/push/", apart from
// Flutter's worker at the root, see push.js). The collector sends each alert as JSON
// {title, body, url, tag} (collector/lib/src/notify/pending_alert.dart,
// pushMessage); a tap opens `url` (the listing, "/#/deals/<id>") in the
// app, reusing an open window (see notificationclick). The app is not served
// from here: its only cache entry is the last tap (TAP_CACHE).
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data.text() };
  }
  event.waitUntil(
    self.registration.showNotification(data.title || 'Deal Tracker', {
      body: data.body || '',
      tag: data.tag,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { url: data.url || '/' },
    }),
  );
});

// The last tapped notification's address, for push.js to read when the app
// comes to the front (same names there).
const TAP_CACHE = 'mdt-push-tap';
const TAP_KEY = '/push/last-tap';

// This worker controls no page (its scope is "/push/"), so it can't
// navigate an open window (`client.navigate` only works on pages it
// controls), and `openWindow` on an app that is already open just brings it
// forward (the iPhone's home-screen app). So the address is first kept in
// Cache Storage, which push.js reads when the app is shown (the iPhone
// doesn't reliably list or message a window this worker doesn't control),
// then an open window is also messaged and focused; only without one is a
// window opened at `url`.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL(event.notification.data.url, self.registration.scope).href;
  event.waitUntil(
    (async () => {
      try {
        const cache = await caches.open(TAP_CACHE);
        await cache.put(TAP_KEY, new Response(JSON.stringify({ url, at: Date.now() })));
      } catch (_) {
        // No Cache Storage: the message below still moves an open app.
      }
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      const client = windows.find((c) => c.focused) || windows[0];
      if (client) {
        client.postMessage({ type: 'mdt-open', url });
        try {
          await client.focus();
        } catch (_) {
          // Focus refused: the app moves once it is shown.
        }
        return;
      }
      await self.clients.openWindow(url);
    })(),
  );
});
