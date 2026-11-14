import '../store/push_store.dart';
import 'notification_text.dart';
import 'push_test.dart';
import 'web_push.dart';

/// A valuation the collector answered ("Quanto vale a minha mota" for a
/// model or year the collection didn't reach yet): the request and the
/// value worked out once the run read the model. An ad check ("Avaliar um
/// anúncio", N.102, [isAd]) also carries the ad's listing and scores once
/// the run found it ([listingId] null: not found a day on).
class const BikeValueAnswer({
  required final String id,
  required final String userId,
  required final String brand,
  required final String model,
  required final int year,
  final int? mileage,
  required final int comparableCount,
  final double? fairPrice,
  final bool isAd = false,
  final String? listingId,
  final int? dealScore,
  final int? riskScore,
}) {
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
    isAd: row['is_ad'] as bool? ?? false,
    listingId: row['listing_id'] as String?,
    dealScore: (row['deal_score'] as num?)?.toInt(),
    riskScore: (row['risk_score'] as num?)?.toInt(),
  );
}

/// The notification of an answered valuation: the bike and its value (or
/// that there are too few listings yet); a tap opens the request in the app.
Map<String, Object?> bikeValuePush(
  BikeValueAnswer answer, {
  NotificationLanguage language = .portuguese,
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
  if (answer.isAd) return _adCheckPush(answer, bike, value, language);
  return {
    'title': language.bikeValueTitle,
    'body': '$bike\n$value',
    'url': '/#/worth?request=${answer.id}',
    'tag': 'bike-value-${answer.id}',
    'language': language.code,
  };
}

/// An ad check's notification: the ad's scores and a tap opens it; not
/// found, the value of a bike of that year and a tap opens the request.
Map<String, Object?> _adCheckPush(
  BikeValueAnswer answer,
  String bike,
  String value,
  NotificationLanguage language,
) {
  final listingId = answer.listingId;
  if (listingId == null) {
    return {
      'title': language.adCheckNotFoundTitle,
      'body': '$bike\n${language.adCheckNotFound}\n$value',
      'url': '/#/worth?request=${answer.id}',
      'tag': 'bike-value-${answer.id}',
      'language': language.code,
    };
  }
  final scores = [
    if (answer.dealScore case final deal?) language.adCheckDealScore(deal),
    if (answer.riskScore case final risk?) language.adCheckRiskScore(risk),
  ];
  return {
    'title': language.adCheckTitle,
    'body': [
      bike,
      if (scores.isEmpty) language.adCheckNoScore else scores.join(' · '),
    ].join('\n'),
    'url': '/#/deals/$listingId',
    'tag': 'bike-value-${answer.id}',
    'language': language.code,
  };
}

/// Answers the valuations waiting for a model this run (started at
/// [startedAt]) read, and tells each owner on their devices ([push]; none
/// when Web Push isn't available: the answer still shows in the app).
Future<({int answered, int sent})> answerBikeValues(
  PushStore store,
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
