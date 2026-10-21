import 'dart:io';

import 'package:collector/collector.dart';

/// Sends a test notification (Web Push) to the devices of the account that
/// asked for it in the app (Mais › "Notificações neste aparelho";
/// `PUSH_ACCOUNT`) or, when started anywhere else, to every admin's
/// devices. `PUSH_KIND` picks which notification to show an example of
/// (`pushTestKinds`; the test one by default).
Future<void> main() async {
  final env = Platform.environment;
  final kind = env['PUSH_KIND']?.trim() ?? '';
  if (kind.isNotEmpty && !pushTestKinds.contains(kind)) {
    stderr.writeln(
      'Unknown PUSH_KIND "$kind": one of ${pushTestKinds.join(', ')}.',
    );
    exitCode = 2;
    return;
  }
  await withServiceClient((client) async {
    final store = ListingStore(client);
    final push = WebPushSender(
      await store.pushKeys(),
      fcm: FcmSender.fromEnvironment(),
    );
    final result = await sendTestPush(
      store,
      push,
      account: env['PUSH_ACCOUNT']?.trim(),
      kind: kind.isEmpty ? 'test' : kind,
    );
    if (result.devices == 0) {
      stderr.writeln(
        'No device to send to: turn on "Notificações neste aparelho" in '
        'Mais first.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln(
      'Test notification sent to ${result.sent} of ${result.devices} '
      'device(s).',
    );
    if (result.sent == 0) exitCode = 1;
  });
}
