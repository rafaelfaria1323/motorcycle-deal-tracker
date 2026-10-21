/// An alert waiting to be pushed, with what the message shows.
class PendingAlert {
  const PendingAlert({
    required this.alertId,
    required this.type,
    required this.brand,
    required this.model,
    required this.url,
    this.userId,
    this.listingId,
    this.oldPrice,
    this.newPrice,
    this.year,
    this.mileage,
    this.price,
    this.dealScore,
    this.location,
  });

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
  );

  final String alertId;
  final String type;
  final String brand;
  final String model;
  final String url;

  /// Whose alert it is, and the listing it opens in the app.
  final String? userId;
  final String? listingId;
  final double? oldPrice;
  final double? newPrice;
  final int? year;
  final int? mileage;
  final double? price;
  final int? dealScore;
  final String? location;
}

/// `7650` -> `7 650 €`
String euros(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final out = StringBuffer(rounded < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return '$out €';
}

/// The three lines of an alert message: what happened to which bike, the
/// price, and the facts.
({String title, String? price, String facts}) _alertLines(PendingAlert a) {
  final heading = switch (a.type) {
    'new_listing' => '🆕 Novo anúncio',
    'price_reduction' => '📉 Baixa de preço',
    'excellent_opportunity' => '🔥 Excelente oportunidade',
    'listing_removed' => '🚫 Anúncio removido',
    'back_on_market' => '🔁 Voltou ao mercado',
    'target_price_reached' => '🎯 Chegou ao seu preço',
    _ => '🔔 Alerta',
  };
  final bike = [a.brand, a.model, if (a.year != null) '${a.year}'].join(' ');

  final old = a.oldPrice;
  final current = a.newPrice ?? a.price;
  final priceLine =
      a.type == 'price_reduction' && old != null && current != null
      ? '${euros(old)} → ${euros(current)}'
      // Back on the market: the new price, and what the earlier ad asked.
      : a.type == 'back_on_market' && old != null && current != null
      ? '${euros(current)} (antes ${euros(old)})'
      // The target price is stored as old_price.
      : a.type == 'target_price_reached' && old != null && current != null
      ? '${euros(current)} (o seu preço: ${euros(old)})'
      : current == null
      ? null
      : euros(current);

  final facts = [
    if (a.mileage != null) '${euros(a.mileage!).replaceAll(' €', '')} km',
    if (a.location != null) a.location!,
    if (a.dealScore != null && a.type != 'listing_removed')
      'Pontuação ${a.dealScore}',
  ].join(' · ');

  return (title: '$heading: $bike', price: priceLine, facts: facts);
}

/// The Telegram message for one alert (plain text).
String formatAlert(PendingAlert a) {
  final lines = _alertLines(a);
  return [
    lines.title,
    ?lines.price,
    if (lines.facts.isNotEmpty) lines.facts,
    a.url,
  ].join('\n');
}

/// The Web Push message for one alert, read by the app's service worker
/// (`web/push_sw.js`): a tap opens the listing in the app.
Map<String, Object?> pushMessage(PendingAlert a) {
  final lines = _alertLines(a);
  return {
    'title': lines.title,
    'body': [?lines.price, if (lines.facts.isNotEmpty) lines.facts].join('\n'),
    'url': a.listingId == null ? a.url : '/#/deals/${a.listingId}',
    // One notification per alert, even if a run sends it twice.
    'tag': a.alertId,
  };
}
