import 'push.dart';

Future<PushState> pushState() async => PushState.unsupported;

Future<PushSubscription> enablePush(String publicKey) =>
    throw UnsupportedError('Web Push needs a browser');

Future<String?> disablePush() async => null;
