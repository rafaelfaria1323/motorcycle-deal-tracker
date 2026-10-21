// Service worker for notifications (Web Push), registered by push.js when
// the user turns them on in Mais. The collector sends each alert as JSON
// {title, body, url, tag} (collector/lib/src/notify/pending_alert.dart,
// pushMessage); a tap opens `url` (the listing, "/#/deals/<id>") in the
// app, reusing an open window. No caching: the app is not served from here.
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

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL(event.notification.data.url, self.registration.scope).href;
  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of windows) {
        try {
          await client.focus();
          await client.navigate(url);
          return;
        } catch (_) {
          // Not ours to steer (or navigate unsupported): open a new one.
        }
      }
      await self.clients.openWindow(url);
    })(),
  );
});
