import 'dart:convert';

import 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart' as impl;

/// Whether this device can receive notifications, and whether it does.
enum PushState {
  /// The browser has no Web Push.
  unsupported,

  /// iPhone/iPad Safari: only a home-screen app receives them.
  needsHomeScreen,

  /// The user blocked them for this app.
  denied,
  off,
  on,
}

/// This device's push subscription, as the database stores it.
typedef PushSubscription = ({String endpoint, String p256dh, String auth});

/// Web Push on this device (`web/push.js`): its state, turning it on with
/// our public key (asks for permission: call it straight from a tap), and
/// off (returns the endpoint removed, or null).
abstract final class DevicePush {
  static Future<PushState> state() => impl.pushState();

  static Future<PushSubscription> enable(String publicKey) =>
      impl.enablePush(publicKey);

  static Future<String?> disable() => impl.disablePush();
}

/// The browser's PushSubscription.toJSON().
PushSubscription parseSubscription(String json) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  final keys = map['keys'] as Map<String, dynamic>;
  return (
    endpoint: map['endpoint'] as String,
    p256dh: keys['p256dh'] as String,
    auth: keys['auth'] as String,
  );
}
