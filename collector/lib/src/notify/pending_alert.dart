/// An alert waiting to be pushed, with what the message shows.
class PendingAlert {
  const PendingAlert({
    required this.alertId,
    required this.type,
    required this.brand,
    required this.model,
    required this.url,
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

/// The Telegram message for one alert (plain text).
String formatAlert(PendingAlert a) {
  final heading = switch (a.type) {
    'new_listing' => '🆕 Novo anúncio',
    'price_reduction' => '📉 Baixa de preço',
    'excellent_opportunity' => '🔥 Excelente oportunidade',
    'listing_removed' => '🚫 Anúncio removido',
    _ => '🔔 Alerta',
  };
  final bike = [a.brand, a.model, if (a.year != null) '${a.year}'].join(' ');

  final old = a.oldPrice;
  final current = a.newPrice ?? a.price;
  final priceLine =
      a.type == 'price_reduction' && old != null && current != null
      ? '${euros(old)} → ${euros(current)}'
      : current == null
      ? null
      : euros(current);

  final facts = [
    if (a.mileage != null) '${euros(a.mileage!).replaceAll(' €', '')} km',
    if (a.location != null) a.location!,
    if (a.dealScore != null && a.type != 'listing_removed')
      'Pontuação ${a.dealScore}',
  ].join(' · ');

  return [
    '$heading: $bike',
    ?priceLine,
    if (facts.isNotEmpty) facts,
    a.url,
  ].join('\n');
}
