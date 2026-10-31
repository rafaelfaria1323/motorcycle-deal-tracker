import 'notification_text.dart';

/// An alert waiting to be pushed, with what the message shows.
class const PendingAlert({
  required final String alertId,
  required final String type,
  required final String brand,
  required final String model,
  required final String url,

  /// Whose alert it is, and the listing it opens in the app.
  final String? userId,
  final String? listingId,
  final double? oldPrice,
  final double? newPrice,
  final int? year,
  final int? mileage,
  final double? price,
  final int? dealScore,
  final String? location,

  /// When the alert was made (null from older databases).
  final DateTime? createdAt,

  /// The bike is in one of the person's colours for its model (a plus, not
  /// part of the score).
  final bool myColour = false,
}) {
  factory PendingAlert.fromRow(Map<String, dynamic> row) => PendingAlert(
    alertId: row['alert_id'] as String,
    type: row['type'] as String,
    brand: row['brand'] as String,
    model: row['model'] as String,
    url: row['url'] as String,
    userId: row['user_id'] as String?,
    listingId: row['listing_id'] as String?,
    oldPrice: (row['old_price'] as num?)?.toDouble(),
    newPrice: (row['new_price'] as num?)?.toDouble(),
    year: (row['year'] as num?)?.toInt(),
    mileage: (row['mileage'] as num?)?.toInt(),
    price: (row['price'] as num?)?.toDouble(),
    dealScore: (row['deal_score'] as num?)?.toInt(),
    location: row['location'] as String?,
    createdAt: switch (row['created_at']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    myColour: row['my_colour'] as bool? ?? false,
  );
}

/// `7650` -> `7 650 €`
String euros(num value, {NotificationLanguage language = .portuguese}) =>
    language.currency(value);

/// The three lines of an alert message: what happened to which bike, the
/// price, and the facts.
({String title, String? price, String facts}) _alertLines(
  PendingAlert a,
  NotificationLanguage language,
) {
  final heading = language.alertHeading(a.type, myColour: a.myColour);
  String money(num value) => euros(value, language: language);
  final bike = [a.brand, a.model, if (a.year != null) '${a.year}'].join(' ');

  final old = a.oldPrice;
  final current = a.newPrice ?? a.price;
  final priceLine =
      a.type == 'price_reduction' && old != null && current != null
      ? '${money(old)} → ${money(current)}'
      // Back on the market: the new price, and what the earlier ad asked.
      : a.type == 'back_on_market' && old != null && current != null
      ? '${money(current)} (${language.previously(money(old))})'
      // The target price is stored as old_price.
      : a.type == 'target_price_reached' && old != null && current != null
      ? '${money(current)} (${language.targetPrice(money(old))})'
      : current == null
      ? null
      : money(current);

  final facts = [
    if (a.myColour && a.type != 'new_listing') language.inYourColour,
    if (a.mileage != null) '${language.number(a.mileage!)} km',
    if (a.location != null) a.location!,
    if (a.dealScore != null && a.type != 'listing_removed')
      language.score(a.dealScore),
  ].join(' · ');

  return (title: '$heading: $bike', price: priceLine, facts: facts);
}

/// The Web Push message for one alert, read by the app's service worker
/// (`web/push_sw.js`): a tap opens the listing in the app.
Map<String, Object?> pushMessage(
  PendingAlert a, {
  NotificationLanguage language = .portuguese,
}) {
  final lines = _alertLines(a, language);
  return {
    'title': lines.title,
    'body': [?lines.price, if (lines.facts.isNotEmpty) lines.facts].join('\n'),
    'url': a.listingId == null ? a.url : '/#/deals/${a.listingId}',
    // One notification per alert, even if a run sends it twice.
    'tag': a.alertId,
    'language': language.code,
  };
}
