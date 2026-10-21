import 'push.dart';

/// Outside the browser: the Android app (or tests).
Future<PushState> pushState() async => PushState.nativeApp;

Future<PushSubscription> enablePush(String publicKey) =>
    throw UnsupportedError('Web Push needs a browser');

Future<String?> disablePush() async => null;
