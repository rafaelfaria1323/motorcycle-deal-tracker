import '../store/listing_store.dart';
import 'web_push.dart';

/// The workflow that sends a test notification (`push-test.yml`), as
/// `start_workflow` records it.
const pushTestWorkflow = 'push-test.yml';

/// The test notification: says the device receives them; a tap opens Mais.
const Map<String, Object?> testPushMessage = {
  'title': 'Notificação de teste',
  'body':
      'As notificações chegam a este aparelho. Os alertas aparecem assim '
      'depois de cada recolha.',
  'url': '/#/more',
  'tag': 'push-test',
};

/// Sends [testPushMessage] to the devices of the account that asked for it
/// in the app (the last start of [pushTestWorkflow] in the last 30
/// minutes) or, started elsewhere (GitHub's "Run workflow"), to every
/// admin's devices. Forgets devices that no longer exist.
Future<({int devices, int sent})> sendTestPush(
  ListingStore store,
  WebPushSender push, {
  DateTime? now,
}) async {
  final since = (now ?? DateTime.now().toUtc()).subtract(
    const Duration(minutes: 30),
  );
  final requester = await store.lastWorkflowStarter(pushTestWorkflow, since);
  final users = requester == null ? await store.adminIds() : [requester];
  final byUser = await store.pushTargets();
  final devices = [for (final u in users) ...?byUser[u]];

  final reached = <String>[];
  final gone = <String>[];
  for (final device in devices) {
    switch (await push.send(device, testPushMessage)) {
      case PushResult.sent:
        reached.add(device.endpoint);
      case PushResult.gone:
        gone.add(device.endpoint);
      case PushResult.failed:
        break;
    }
  }
  await store.forgetPushTargets(gone);
  await store.markPushTargetsUsed(reached);
  return (devices: devices.length, sent: reached.length);
}
