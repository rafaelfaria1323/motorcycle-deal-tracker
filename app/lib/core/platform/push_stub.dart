import 'package:flutter/services.dart';

import 'push.dart';

/// Outside the browser: the Android app, whose notifications come through
/// Firebase Cloud Messaging (the plugin in packages/android_push). Its
/// device is stored like a browser's, as `fcm:<registration token>` without
/// keys. Elsewhere (tests, an APK built without Firebase) [PushState.nativeApp].
const _channel = MethodChannel('deal_tracker/android_push');

Future<PushState> pushState() async {
  try {
    return switch (await _channel.invokeMethod<String>('state')) {
      'on' => PushState.on,
      'off' => PushState.off,
      'denied' => PushState.denied,
      _ => PushState.nativeApp,
    };
  } on Object catch (_) {
    return PushState.nativeApp;
  }
}

/// The public key is the browsers' (Web Push): FCM needs none.
Future<PushSubscription> enablePush(String publicKey) async {
  final token = await _channel.invokeMethod<String>('enable');
  if (token == null || token.isEmpty) {
    throw StateError('No registration token');
  }
  return (endpoint: '$androidPrefix$token', p256dh: '', auth: '');
}

Future<String?> disablePush() async {
  final token = await _channel.invokeMethod<String>('disable');
  return token == null ? null : '$androidPrefix$token';
}

/// Calls [open] with the page of each notification tapped: the one that
/// started the app, then any tapped while it runs.
Future<void> listenToTaps(void Function(String url) open) async {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'open' && call.arguments is String) {
      open(call.arguments as String);
    }
  });
  try {
    final url = await _channel.invokeMethod<String>('initialUrl');
    if (url != null) open(url);
  } on Object catch (_) {
    // Not the Android app.
  }
}
