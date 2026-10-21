import 'dart:js_interop';

import 'push.dart';

@JS('mdtPush.state')
external JSPromise<JSString> _state();

@JS('mdtPush.enable')
external JSPromise<JSString> _enable(JSString publicKey);

@JS('mdtPush.disable')
external JSPromise<JSString> _disable();

Future<PushState> pushState() async => switch ((await _state().toDart).toDart) {
  'needs-home-screen' => PushState.needsHomeScreen,
  'denied' => PushState.denied,
  'off' => PushState.off,
  'on' => PushState.on,
  _ => PushState.unsupported,
};

Future<PushSubscription> enablePush(String publicKey) async =>
    parseSubscription((await _enable(publicKey.toJS).toDart).toDart);

Future<String?> disablePush() async {
  final endpoint = (await _disable().toDart).toDart;
  return endpoint.isEmpty ? null : endpoint;
}

/// The browser opens a tapped notification's page itself (web/push.js).
Future<void> listenToTaps(void Function(String url) open) async {}
