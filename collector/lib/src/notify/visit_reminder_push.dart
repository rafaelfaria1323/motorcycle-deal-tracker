import '../store/push_store.dart';
import 'notification_text.dart';
import 'push_test.dart';
import 'web_push.dart';

/// A visit to a favourite's bike (N.65) to remind its owner of: when, in
/// Lisbon time, and the bike.
class const VisitReminder({
  required final String userId,
  required final String listingId,
  required final DateTime visitAt,

  /// Calendar days from the run's day to the visit's (0 today, 1 tomorrow).
  required final int day,

  /// "10:00".
  required final String time,
  required final String brand,
  required final String model,
  final int? year,
  final double? price,
  final String? location,

  /// The ad is still on the site.
  required final bool live,
}) {
  /// A row of `pending_visit_reminders`.
  factory VisitReminder.fromRow(Map<String, dynamic> row) => VisitReminder(
    userId: row['user_id'] as String,
    listingId: row['listing_id'] as String,
    visitAt: DateTime.parse(row['visit_at'] as String),
    day: (row['visit_day'] as num).toInt(),
    time: row['visit_time'] as String,
    brand: row['brand'] as String,
    model: row['model'] as String,
    year: (row['year'] as num?)?.toInt(),
    price: (row['price'] as num?)?.toDouble(),
    location: row['location'] as String?,
    live: row['is_live'] as bool? ?? true,
  );
}

/// The reminder: when, the bike, and to take the checklist (or that the ad
/// is gone); a tap opens the ad.
Map<String, Object?> visitReminderPush(
  VisitReminder visit, {
  NotificationLanguage language = .portuguese,
}) {
  final bike = [
    [
      visit.brand,
      visit.model,
      if (visit.year case final year?) '$year',
    ].join(' '),
    if (visit.price case final price?) language.currency(price),
    if (visit.location case final place? when place.isNotEmpty) place,
  ].join(' · ');
  return {
    'title': language.visitTitle(visit.day, visit.time),
    'body': '$bike\n${visit.live ? language.visitBring : language.visitAdGone}',
    'url': '/#/deals/${visit.listingId}',
    'tag': 'visit-${visit.listingId}',
    'language': language.code,
  };
}

/// Reminds the visits due at [at] (the run's time) on their owners'
/// devices. A reminder is marked sent once a device took it, or when the
/// account has no device (nothing to wait for); when every device failed
/// it is tried again by the next run before the visit. Without Web Push
/// ([push] null) nothing is read: they wait.
Future<({int reminded, int sent})> remindVisits(
  PushStore store,
  WebPushSender? push,
  DateTime at,
) async {
  if (push == null) return (reminded: 0, sent: 0);
  final visits = await store.pendingVisitReminders(at);
  var reminded = 0;
  var sent = 0;
  for (final visit in visits) {
    final result = await pushToUsers(store, push, [
      visit.userId,
    ], (_, language) => visitReminderPush(visit, language: language));
    sent += result.sent;
    if (result.devices == 0 || result.sent > 0) {
      await store.markVisitReminded(visit);
      reminded++;
    }
  }
  return (reminded: reminded, sent: sent);
}
