import '../store/push_store.dart';
import 'notification_text.dart';
import 'push_test.dart';
import 'web_push.dart';

/// An EU recall (Safety Gate, N.86) that can cover an account's own bike
/// or a favourite's (N.87): the bike and what the recall says.
class const RecallNotice({
  required final String userId,
  required final String caseNumber,

  /// The bike in "A minha mota", when it is one of the account's own.
  final String? bikeId,

  /// The favourite's ad (or the ad an owned bike was bought from).
  final String? listingId,
  required final String brand,
  required final String model,
  final int? year,

  /// The recall's own name of the product ("MT-07", "YZF-R7").
  final String? recallName,

  /// The maker's recall code, when the alert gives one.
  final String? recallCode,
  final String? dangerEn,
  final String? dangerPt,
}) {
  /// A row of `pending_recall_notices`.
  factory RecallNotice.fromRow(Map<String, dynamic> row) => RecallNotice(
    userId: row['user_id'] as String,
    caseNumber: row['case_number'] as String,
    bikeId: row['bike_id'] as String?,
    listingId: row['listing_id'] as String?,
    brand: row['brand'] as String,
    model: row['model'] as String,
    year: (row['year'] as num?)?.toInt(),
    recallName: row['recall_name'] as String?,
    recallCode: row['recall_code'] as String?,
    dangerEn: row['danger_en'] as String?,
    dangerPt: row['danger_pt'] as String?,
  );

  /// One of the account's own bikes, not a favourite.
  bool get owned => bikeId != null;
}

/// The longest danger text a notification carries; the rest is on the page.
const recallDangerMaxLength = 160;

/// The notice: the bike, the danger in the account's language (the other
/// one when only that was read), the maker's code, and to ask the brand's
/// dealer; a tap opens "A minha mota" or the favourite's ad.
Map<String, Object?> recallPush(
  RecallNotice notice, {
  NotificationLanguage language = .portuguese,
}) {
  final bike = [
    notice.brand,
    notice.model,
    if (notice.year case final year?) '$year',
  ].join(' ');
  final danger = switch (language) {
    .portuguese => notice.dangerPt ?? notice.dangerEn,
    .english => notice.dangerEn ?? notice.dangerPt,
  };
  return {
    'title': language.recallTitle(bike),
    'body': [
      if (danger case final text? when text.trim().isNotEmpty)
        _shortened(text.trim()),
      if (notice.recallCode case final code? when code.trim().isNotEmpty)
        language.recallCode(code.trim()),
      notice.owned ? language.recallAskDealer : language.recallAskSeller,
    ].join('\n'),
    'url': switch ((notice.owned, notice.listingId)) {
      (false, final listing?) => '/#/deals/$listing',
      _ => '/#/my-bike',
    },
    'tag': 'recall-${notice.caseNumber}',
    'language': language.code,
  };
}

String _shortened(String text) => text.length <= recallDangerMaxLength
    ? text
    : '${text.substring(0, recallDangerMaxLength - 1).trimRight()}…';

/// Tells each account of the recalls due at [at] (the run's time) on its
/// devices. A notice is marked once a device took it, or when the account
/// has no device (it is on the bike's page anyway); when every device
/// failed the next run tries again. Without Web Push ([push] null) nothing
/// is read: they wait.
Future<({int noticed, int sent})> noticeRecalls(
  PushStore store,
  WebPushSender? push,
  DateTime at,
) async {
  if (push == null) return (noticed: 0, sent: 0);
  final notices = await store.pendingRecallNotices(at);
  var noticed = 0;
  var sent = 0;
  for (final notice in notices) {
    final result = await pushToUsers(store, push, [
      notice.userId,
    ], (_, language) => recallPush(notice, language: language));
    sent += result.sent;
    if (result.devices == 0 || result.sent > 0) {
      await store.markRecallNoticed(notice);
      noticed++;
    }
  }
  return (noticed: noticed, sent: sent);
}
