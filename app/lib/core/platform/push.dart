import 'dart:convert';

import 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart' as impl;

/// Whether this device can receive notifications, and whether it does.
enum PushState {
  /// The browser has no Web Push.
  unsupported,

  /// The Android app built without Firebase (or not in a browser at all):
  /// no notifications there.
  nativeApp,

  /// iPhone/iPad Safari: only a home-screen app receives them.
  needsHomeScreen,

  /// The user blocked them for this app.
  denied,
  off,
  on,
}

/// This device's push subscription, as the database stores it.
typedef PushSubscription = ({String endpoint, String p256dh, String auth});

/// The endpoint prefix of an Android app's device (its FCM token follows).
const androidPrefix = 'fcm:';

/// Notifications on this device: Web Push in the browser (`web/push.js`),
/// Firebase Cloud Messaging in the Android app. Its state, turning it on
/// with our public key (asks for permission: call it straight from a tap),
/// and off (returns the endpoint removed, or null).
abstract final class DevicePush {
  static Future<PushState> state() => impl.pushState();

  static Future<PushSubscription> enable(String publicKey) =>
      impl.enablePush(publicKey);

  static Future<String?> disable() => impl.disablePush();

  /// In the Android app, [open] gets the page (the message's url) of each
  /// notification tapped; the browser opens it by itself.
  static Future<void> listenToTaps(void Function(String url) open) =>
      impl.listenToTaps(open);
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
