import 'dart:io';

import '../store/listing_store.dart';
import 'pending_alert.dart';
import 'telegram_notifier.dart';
import 'web_push.dart';

/// Sends pending alerts: each to its account's devices ([push], Web Push)
/// and, an admin's, to the owner's Telegram chat ([telegram]), either when
/// configured.
/// Returns how many alerts went out and how many pushes reached a device.
/// A Telegram failure stops the loop and leaves the rest for the next run;
/// a device that no longer exists is forgotten. Never throws.
Future<({int alerts, int pushes})> notifyPending(
  ListingStore store, {
  TelegramNotifier? telegram,
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
    if (telegram != null && alert.toTelegram) {
      try {
        await telegram.send(formatAlert(alert));
      } on NotifyFailed catch (e) {
        stderr.writeln('Notification not sent: $e');
        break;
      }
    }
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
