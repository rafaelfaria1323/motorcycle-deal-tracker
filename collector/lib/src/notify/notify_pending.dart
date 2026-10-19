import 'dart:io';

import '../store/listing_store.dart';
import 'pending_alert.dart';
import 'telegram_notifier.dart';

/// Pushes pending alerts; returns how many were sent. A failure stops the
/// loop and leaves the rest for the next run; it never throws.
Future<int> notifyPending(ListingStore store, TelegramNotifier notifier) async {
  final pending = await store.pendingNotifications();
  final sent = <String>[];
  for (final alert in pending) {
    try {
      await notifier.send(formatAlert(alert));
      sent.add(alert.alertId);
    } on NotifyFailed catch (e) {
      stderr.writeln('Notification not sent: $e');
      break;
    }
  }
  await store.markNotified(sent);
  return sent.length;
}
