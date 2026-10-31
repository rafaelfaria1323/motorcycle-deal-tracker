import '../store/listing_store.dart';
import 'notification_text.dart';
import 'pending_alert.dart';
import 'web_push.dart';

/// Alerts read per run; more wait for the next one.
const pendingPerRun = 200;

/// How long a failed push is tried again (on later runs), and the age past
/// which an alert is no longer pushed at all: it would be old news.
const pushRetryWindow = Duration(hours: 24);

/// Notifications one account gets from a run at most: up to this many
/// bikes each get their own; past it, the best ones but one do and the
/// rest go as one summary ([alertsSummaryMessage]) that opens Alertas.
const pushesPerAccount = 4;

/// One notification of a run: whose it is, the alerts it covers (all
/// marked sent once a device took it) and what it says.
typedef PlannedPush = ({
  String? userId,
  List<String> alertIds,
  Map<String, Object?> message,
});

/// The run's notifications for [alerts] (in the order they were read,
/// oldest first): one per account and bike, with the strongest of that
/// bike's alerts, so a new ad that is also an excellent opportunity (or
/// matches two saved searches) arrives once; an excellent opportunity
/// brought by a price drop shows the drop. An account with more than
/// [pushesPerAccount] bikes gets its best `pushesPerAccount - 1` and one
/// summary of the others. Each account's are in the order to send them:
/// the summary first, the best bike last. [languageOf] gives each
/// account's language.
List<PlannedPush> planAlertPushes(
  List<PendingAlert> alerts,
  NotificationLanguage Function(String? userId) languageOf,
) {
  final byAccount = <String?, Map<String, List<PendingAlert>>>{};
  for (final alert in alerts) {
    byAccount
        .putIfAbsent(alert.userId, () => {})
        .putIfAbsent(alert.listingId ?? 'alert:${alert.alertId}', () => [])
        .add(alert);
  }

  final planned = <PlannedPush>[];
  for (final MapEntry(key: user, value: bikes) in byAccount.entries) {
    final language = languageOf(user);
    final ranked = [
      for (final (order, group) in bikes.values.indexed)
        (order: order, group: group, lead: _strongest(group)),
    ]..sort((a, b) => _compareBikes(a.lead, b.lead, a.order, b.order));
    final individual = ranked.length <= pushesPerAccount
        ? ranked
        : ranked.take(pushesPerAccount - 1).toList();
    final rest = ranked.skip(individual.length).toList();
    final pushes = <PlannedPush>[
      for (final bike in individual)
        (
          userId: user,
          alertIds: [for (final alert in bike.group) alert.alertId],
          message: pushMessage(
            bike.lead,
            language: language,
            droppedFrom: _dropBehind(bike.lead, bike.group),
          ),
        ),
      if (rest.isNotEmpty)
        (
          userId: user,
          alertIds: [
            for (final bike in rest)
              for (final alert in bike.group) alert.alertId,
          ],
          message: alertsSummaryMessage([
            for (final bike in rest) bike.lead.type,
          ], language: language),
        ),
    ];
    // The best last: a phone lists the newest notification on top.
    planned.addAll(pushes.reversed);
  }
  return planned;
}

/// The alert of a bike's [group] its notification shows: the strongest
/// type, the first read among equals.
PendingAlert _strongest(List<PendingAlert> group) => group.reduce(
  (best, alert) =>
      alertTypeRank(alert.type) < alertTypeRank(best.type) ? alert : best,
);

int _compareBikes(PendingAlert a, PendingAlert b, int orderA, int orderB) {
  final byType = alertTypeRank(a.type).compareTo(alertTypeRank(b.type));
  if (byType != 0) return byType;
  final byScore = (b.dealScore ?? -1).compareTo(a.dealScore ?? -1);
  return byScore != 0 ? byScore : orderA.compareTo(orderB);
}

/// The price an excellent opportunity [lead] dropped from in the same run
/// (a price drop alert of the same bike), so its notification shows why.
double? _dropBehind(PendingAlert lead, List<PendingAlert> group) {
  if (lead.type != 'excellent_opportunity') return null;
  for (final alert in group) {
    if (alert.type == 'price_reduction' && alert.oldPrice != null) {
      return alert.oldPrice;
    }
  }
  return null;
}

/// Sends pending alerts to their accounts' devices ([push], Web Push), as
/// [planAlertPushes] groups them, and marks them sent. Without [push] (the
/// keys could not be read) nothing is marked, so the next run sends them.
/// A notification whose every push failed leaves its alerts pending until
/// [pushRetryWindow] has passed; older alerts are marked without a push.
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

  bool isOld(PendingAlert alert) {
    final created = alert.createdAt;
    return created != null && at.difference(created) > pushRetryWindow;
  }

  final sent = [
    for (final alert in pending)
      if (isOld(alert)) alert.alertId,
  ];
  final reached = <String>{};
  final gone = <String>{};
  final down = <String>{};
  var pushes = 0;
  final planned = planAlertPushes([
    for (final alert in pending)
      if (!isOld(alert)) alert,
  ], (user) => user == null ? .portuguese : languages[user]!);
  for (final notification in planned) {
    var failed = false;
    var delivered = false;
    for (final device in devices[notification.userId] ?? const <PushTarget>[]) {
      if (gone.contains(device.endpoint)) continue;
      if (down.contains(device.endpoint)) {
        failed = true;
        continue;
      }
      switch (await push.send(device, notification.message)) {
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
    if (failed && !delivered) continue;
    sent.addAll(notification.alertIds);
  }

  await store.forgetPushTargets(gone.toList());
  await store.markPushTargetsUsed(reached.toList());
  await store.markNotified(sent);
  return (alerts: sent.length, pushes: pushes);
}
