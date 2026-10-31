import '../store/listing_store.dart';
import 'notification_text.dart';
import 'pending_alert.dart';
import 'web_push.dart';

/// Alerts read per run; more wait for the next one.
const pendingPerRun = 200;

/// How long a failed push is tried again (on later runs), and the age past
/// which an alert is no longer pushed at all: it would be old news.
const pushRetryWindow = Duration(hours: 24);

/// Sends pending alerts, each to its account's devices ([push], Web Push),
/// and marks them sent. Without [push] (the keys could not be read)
/// nothing is marked, so the next run sends them. An alert whose every
/// push failed stays pending until [pushRetryWindow] has passed.
/// Returns how many alerts were marked and how many pushes reached a
/// device. A device that no longer exists is forgotten; one whose push
/// failed is not tried again this run (its push service is down or asks
/// us to slow down, and each try can wait 45 s), so its alerts wait.
/// Alerts of accounts in their quiet hours at [now] are not read: they go
/// with the first run after.
Future<({int alerts, int pushes})> notifyPending(
  ListingStore store, {
  WebPushSender? push,
  DateTime? now,
}) async {
  if (push == null) return (alerts: 0, pushes: 0);
  final at = now ?? DateTime.now();
  final pending = await store.pendingNotifications(
    limit: pendingPerRun,
    at: at,
  );
  if (pending.isEmpty) return (alerts: 0, pushes: 0);
  final devices = await store.pushTargets();
  final languages = await store.accountLanguages(
    pending.map((alert) => alert.userId).whereType<String>().toSet().toList(),
  );

  final sent = <String>[];
  final reached = <String>{};
  final gone = <String>{};
  final down = <String>{};
  var pushes = 0;
  for (final alert in pending) {
    final created = alert.createdAt;
    final old = created != null && at.difference(created) > pushRetryWindow;
    var failed = false;
    var delivered = false;
    final message = pushMessage(
      alert,
      language: alert.userId == null
          ? NotificationLanguage.portuguese
          : languages[alert.userId]!,
    );
    for (final device in devices[alert.userId] ?? const <PushTarget>[]) {
      if (old) break;
      if (gone.contains(device.endpoint)) continue;
      if (down.contains(device.endpoint)) {
        failed = true;
        continue;
      }
      switch (await push.send(device, message)) {
        case .sent:
          pushes++;
          delivered = true;
          reached.add(device.endpoint);
        case .gone:
          gone.add(device.endpoint);
        case .failed:
          failed = true;
          down.add(device.endpoint);
      }
    }
    // Retried only when no device got it: a second push to the devices
    // that did would be a repeat.
    if (failed && !delivered && !old) continue;
    sent.add(alert.alertId);
  }

  await store.forgetPushTargets(gone.toList());
  await store.markPushTargetsUsed(reached.toList());
  await store.markNotified(sent);
  return (alerts: sent.length, pushes: pushes);
}
