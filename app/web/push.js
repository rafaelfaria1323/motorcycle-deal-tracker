// Notifications on this device (Web Push), called from Dart
// (lib/core/platform/push_web.dart). Each function returns a promise.
//   mdtPush.state()            'unsupported' | 'needs-home-screen' | 'denied' | 'off' | 'on'
//   mdtPush.enable(publicKey)  asks for permission (must follow a tap), subscribes
//                              with our VAPID key, resolves to the subscription as JSON
//   mdtPush.disable()          unsubscribes; resolves to the endpoint removed, or ''
// It also follows taps on notifications while the app is open (see
// followNotifications).
//
// push_sw.js gets its own scope (SCOPE), apart from Flutter's worker at the
// root: Flutter's loader registers flutter_service_worker.js at "/" on every
// start, and since Flutter 3.41 that worker unregisters itself, which took
// a push worker sharing "/" (and with it the subscription) along when the
// app was closed and opened again. The push worker controls no page, so
// `navigator.serviceWorker.ready` never resolves for it: wait for it to
// activate instead.
(function () {
  const SCOPE = 'push/';

  function supported() {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  }

  // iPhone/iPad Safari has Web Push only in a home-screen app.
  function onIosOutsideHomeScreen() {
    const ios = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    return ios && navigator.standalone !== true;
  }

  function bytes(base64url) {
    const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
    const raw = atob(base64 + '='.repeat((4 - (base64.length % 4)) % 4));
    return Uint8Array.from(raw, (c) => c.charCodeAt(0));
  }

  async function subscription() {
    const registration = await navigator.serviceWorker.getRegistration(SCOPE);
    return registration ? registration.pushManager.getSubscription() : null;
  }

  // Resolves once the registration has an active worker (subscribe needs one).
  function activated(registration) {
    const worker = registration.installing || registration.waiting;
    if (registration.active || !worker) return Promise.resolve();
    return new Promise((resolve) => {
      worker.addEventListener('statechange', () => {
        if (worker.state === 'activated') resolve();
      });
    });
  }

  async function state() {
    if (!supported()) return onIosOutsideHomeScreen() ? 'needs-home-screen' : 'unsupported';
    if (Notification.permission === 'denied') return 'denied';
    if (Notification.permission !== 'granted') return 'off';
    return (await subscription()) ? 'on' : 'off';
  }

  async function enable(publicKey) {
    // First, while the tap still counts as a user gesture (Safari asks for one).
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') throw new Error('permission ' + permission);
    const registration = await navigator.serviceWorker.register('push_sw.js', { scope: SCOPE });
    await activated(registration);
    const key = bytes(publicKey);
    let sub = await registration.pushManager.getSubscription();
    const current = sub && sub.options.applicationServerKey;
    if (sub && current && new Uint8Array(current).toString() !== key.toString()) {
      await sub.unsubscribe(); // made with another key: no longer reachable
      sub = null;
    }
    sub = sub || await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: key,
    });
    return JSON.stringify(sub.toJSON());
  }

  async function disable() {
    const sub = await subscription();
    if (!sub) return '';
    const endpoint = sub.endpoint;
    await sub.unsubscribe();
    return endpoint;
  }

  // A tapped notification while the app is open: push_sw.js can't navigate
  // a page it doesn't control, so it sends the address here. The app's
  // routes live in the hash (Flutter's hash strategy follows its change).
  function followNotifications() {
    if (!('serviceWorker' in navigator)) return;
    navigator.serviceWorker.addEventListener('message', (event) => {
      const data = event.data || {};
      if (data.type !== 'mdt-open' || typeof data.url !== 'string') return;
      const target = new URL(data.url, location.href);
      if (target.origin !== location.origin) return;
      if (target.hash && target.hash !== location.hash) location.hash = target.hash;
    });
    // Messages wait until this is called (addEventListener alone doesn't).
    navigator.serviceWorker.startMessages();
  }

  // The push worker controls no page, so opening the app never makes the
  // browser look for a new push_sw.js (it would wait for a push a day
  // later): ask for it on each start, so a deploy reaches it at once.
  async function updateWorker() {
    if (!supported()) return;
    const registration = await navigator.serviceWorker.getRegistration(SCOPE);
    if (registration) await registration.update();
  }

  followNotifications();
  updateWorker().catch(() => {});
  window.mdtPush = { state, enable, disable };
})();
