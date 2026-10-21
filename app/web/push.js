// Notifications on this device (Web Push), called from Dart
// (lib/core/platform/push_web.dart). Each function returns a promise.
//   mdtPush.state()            'unsupported' | 'needs-home-screen' | 'denied' | 'off' | 'on'
//   mdtPush.enable(publicKey)  asks for permission (must follow a tap), subscribes
//                              with our VAPID key, resolves to the subscription as JSON
//   mdtPush.disable()          unsubscribes; resolves to the endpoint removed, or ''
(function () {
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
    const registration = await navigator.serviceWorker.getRegistration();
    return registration ? registration.pushManager.getSubscription() : null;
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
    const registration = await navigator.serviceWorker.register('push_sw.js');
    await navigator.serviceWorker.ready;
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

  window.mdtPush = { state, enable, disable };
})();
