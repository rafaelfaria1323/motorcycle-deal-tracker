import '../store/listing_store.dart';
import 'notification_text.dart';
import 'push_test.dart';
import 'web_push.dart';

/// A valuation the collector answered ("Quanto vale a minha mota" for a
/// model or year the collection didn't reach yet): the request and the
/// value worked out once the run read the model.
class BikeValueAnswer {
  const BikeValueAnswer({
    required this.id,
    required this.userId,
    required this.brand,
    required this.model,
    required this.year,
    this.mileage,
    required this.comparableCount,
    this.fairPrice,
  });

  /// A row of `answer_bike_value_requests`.
  factory BikeValueAnswer.fromRow(Map<String, dynamic> row) => BikeValueAnswer(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    brand: row['brand'] as String,
    model: row['model'] as String,
    year: (row['year'] as num).toInt(),
    mileage: (row['mileage'] as num?)?.toInt(),
    comparableCount: (row['comparable_count'] as num?)?.toInt() ?? 0,
    fairPrice: (row['fair_price'] as num?)?.toDouble(),
  );

  final String id;
  final String userId;
  final String brand;
  final String model;
  final int year;
  final int? mileage;
  final int comparableCount;
  final double? fairPrice;
}

/// The notification of an answered valuation: the bike and its value (or
/// that there are too few listings yet); a tap opens the request in the app.
Map<String, Object?> bikeValuePush(
  BikeValueAnswer answer, {
  NotificationLanguage language = NotificationLanguage.portuguese,
}) {
  final bike = [
    answer.brand,
    answer.model,
    '${answer.year}',
    if (answer.mileage case final km?) '${language.number(km)} km',
  ].join(' ');
  final price = answer.fairPrice;
  final value = price == null || answer.comparableCount == 0
      ? language.bikeValueNone
      : language.bikeValueEstimate(
          language.currency(price),
          answer.comparableCount,
        );
  return {
    'title': language.bikeValueTitle,
    'body': '$bike\n$value',
    'url': '/#/worth?request=${answer.id}',
    'tag': 'bike-value-${answer.id}',
    'language': language.code,
  };
}

/// Answers the valuations waiting for a model this run (started at
/// [startedAt]) read, and tells each owner on their devices ([push]; none
/// when Web Push isn't available: the answer still shows in the app).
Future<({int answered, int sent})> answerBikeValues(
  ListingStore store,
  WebPushSender? push,
  DateTime startedAt,
) async {
  final answers = await store.answerBikeValues(startedAt);
  if (answers.isEmpty || push == null) {
    return (answered: answers.length, sent: 0);
  }
  var sent = 0;
  // One push per request: an account may have asked for several bikes.
  for (final answer in answers) {
    final result = await pushToUsers(store, push, [
      answer.userId,
    ], (_, language) => bikeValuePush(answer, language: language));
    sent += result.sent;
  }
  return (answered: answers.length, sent: sent);
}
