import 'dart:io';

import 'package:collector/collector.dart';

/// Sends a test notification (Web Push) to the devices of the account that
/// asked for it in the app (Mais › "Notificações neste aparelho") or, when
/// started anywhere else, to every admin's devices.
Future<void> main() async {
  await withServiceClient((client) async {
    final store = ListingStore(client);
    final push = WebPushSender(await store.pushKeys());
    final result = await sendTestPush(store, push);
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
