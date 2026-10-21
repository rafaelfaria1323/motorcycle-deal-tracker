import '../store/listing_store.dart';
import 'pending_alert.dart';
import 'web_push.dart';

/// Sends pending alerts, each to its account's devices ([push], Web Push,
/// when available), and marks them all sent.
/// Returns how many alerts went out and how many pushes reached a device.
/// A device that no longer exists is forgotten.
Future<({int alerts, int pushes})> notifyPending(
  ListingStore store, {
  WebPushSender? push,
}) async {
  final pending = await store.pendingNotifications();
  if (pending.isEmpty) return (alerts: 0, pushes: 0);
  final devices = push == null
      ? const <String, List<PushTarget>>{}
      : await store.pushTargets();

  final sent = <String>[];
  final reached = <String>{};
  final gone = <String>{};
  var pushes = 0;
  for (final alert in pending) {
    for (final device in devices[alert.userId] ?? const <PushTarget>[]) {
      if (gone.contains(device.endpoint)) continue;
      switch (await push!.send(device, pushMessage(alert))) {
        case PushResult.sent:
          pushes++;
          reached.add(device.endpoint);
        case PushResult.gone:
          gone.add(device.endpoint);
        case PushResult.failed:
          break;
      }
    }
    sent.add(alert.alertId);
  }

  await store.forgetPushTargets(gone.toList());
  await store.markPushTargetsUsed(reached.toList());
  await store.markNotified(sent);
  return (alerts: sent.length, pushes: pushes);
}
