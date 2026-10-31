import '../store/listing_store.dart';
import 'notification_text.dart';
import 'push_test.dart';
import 'web_push.dart';

/// An examination of every photo (P.4) someone asked for, now done: who
/// asked, the bike and how many kinds of hint its photos show.
class const PhotoExamAnswer({
  required final String userId,
  required final String listingId,
  required final String brand,
  required final String model,
  final int? year,
  required final int hints,
}) {
  /// A row of `photo_exam_answers`.
  factory PhotoExamAnswer.fromRow(Map<String, dynamic> row) => PhotoExamAnswer(
    userId: row['user_id'] as String,
    listingId: row['listing_id'] as String,
    brand: row['brand'] as String,
    model: row['model'] as String,
    year: (row['year'] as num?)?.toInt(),
    hints: (row['hints'] as num?)?.toInt() ?? 0,
  );
}

/// The notification of a finished examination; a tap opens the listing.
Map<String, Object?> photoExamPush(
  PhotoExamAnswer answer, {
  NotificationLanguage language = .portuguese,
}) {
  final bike = [
    answer.brand,
    answer.model,
    if (answer.year case final year?) '$year',
  ].join(' ');
  return {
    'title': language.photoExamTitle,
    'body': '$bike\n${language.photoExamHints(answer.hints)}',
    'url': '/#/deals/${answer.listingId}',
    'tag': 'photo-exam-${answer.listingId}',
    'language': language.code,
  };
}

/// Tells each account that asked for every photo of [listings] (those now
/// examined in full) on its devices; returns how many pushes went out.
Future<int> tellPhotoExams(
  ListingStore store,
  WebPushSender push,
  List<String> listings,
) async {
  if (listings.isEmpty) return 0;
  var sent = 0;
  // One push per request: an account may have asked for several ads.
  for (final answer in await store.photoExamAnswers(listings)) {
    final result = await pushToUsers(store, push, [
      answer.userId,
    ], (_, language) => photoExamPush(answer, language: language));
    sent += result.sent;
  }
  return sent;
}
