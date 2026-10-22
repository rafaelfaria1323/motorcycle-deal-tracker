import '../../domain/entities/listing.dart';

class ListingModel extends Listing {
  const ListingModel({
    required super.id,
    required super.source,
    required super.url,
    required super.brand,
    required super.model,
    required super.status,
    required super.sellerType,
    required super.images,
    required super.firstSeenAt,
    required super.lastSeenAt,
    super.motorcycleId,
    super.duplicateOf,
    super.riskScore,
    super.year,
    super.mileage,
    super.mileageFromText,
    super.dealScore,
    super.initialPrice,
    super.priceBeforeDrop,
    super.price,
    super.scoreBreakdown,
    super.sellerName,
    super.location,
    super.description,
    super.registrations,
    super.serviceBook,
    super.origin,
    super.warrantyUntil,
    super.dealerWarrantyMonths,
    super.publishedAt,
    super.siteRefreshedAt,
    super.relistedFrom,
    super.relistedSince,
    super.relistedPrice,
    super.newPrice,
    super.newPriceCheckedAt,
    super.engineCc,
    super.distanceKm,
  });

  /// The columns lists need (cards, alerts, other sources of a bike); the
  /// detail page loads the whole row. `distance_km` is a computed field
  /// (from the caller's home), never part of `*`. Leaves out the description and score
  /// breakdown, the bulk of a row.
  static const summaryColumns =
      'id, source, url, brand, model, motorcycle_id, duplicate_of, year, '
      'mileage, price, initial_price, price_before_drop, deal_score, '
      'risk_score, seller_type, location, images, status, first_seen_at, '
      'last_seen_at, distance_km';

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    // Present when the query embeds the matched model (detail page).
    final bike = json['motorcycles'] as Map<String, dynamic>?;
    return ListingModel(
      id: json['id'] as String,
      source: json['source'] as String,
      url: json['url'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      motorcycleId: json['motorcycle_id'] as String?,
      duplicateOf: json['duplicate_of'] as String?,
      riskScore: json['risk_score'] as int?,
      year: json['year'] as int?,
      mileage: json['mileage'] as int?,
      mileageFromText: json['mileage_from_text'] as bool? ?? false,
      dealScore: json['deal_score'] as int?,
      initialPrice: (json['initial_price'] as num?)?.toDouble(),
      priceBeforeDrop: (json['price_before_drop'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      scoreBreakdown: json['score_breakdown'] as Map<String, dynamic>?,
      sellerType: sellerTypeOf(json['seller_type'] as String?),
      sellerName: json['seller_name'] as String?,
      location: json['location'] as String?,
      description: json['description'] as String?,
      images: List<String>.from(json['images'] as List? ?? const []),
      status: _status(json['status'] as String?),
      firstSeenAt: dateOf(json['first_seen_at']),
      lastSeenAt: dateOf(json['last_seen_at']),
      registrations: json['registrations'] as int?,
      serviceBook: json['service_book'] as bool?,
      origin: json['origin'] as String?,
      warrantyUntil: dateOf(json['warranty_until']),
      dealerWarrantyMonths: json['dealer_warranty_months'] as int?,
      publishedAt: dateOf(json['published_at']),
      siteRefreshedAt: dateOf(json['site_refreshed_at']),
      relistedFrom: json['relisted_from'] as String?,
      relistedSince: dateOf(json['relisted_since']),
      relistedPrice: (json['relisted_price'] as num?)?.toDouble(),
      newPrice: (bike?['new_price_reference'] as num?)?.toDouble(),
      newPriceCheckedAt: dateOf(bike?['new_price_checked_at']),
      engineCc: engineCcOf(bike),
      distanceKm: (json['distance_km'] as num?)?.toInt(),
    );
  }

  /// The middle of the model's engine range ("680-710" -> 695), or the one
  /// limit it has; null without either.
  static int? engineCcOf(Map<String, dynamic>? bike) {
    final min = (bike?['engine_cc_min'] as num?)?.toInt();
    final max = (bike?['engine_cc_max'] as num?)?.toInt();
    if (min == null || max == null) return min ?? max;
    return ((min + max) / 2).round();
  }

  /// Shared with `SavedSearchModel`; anything unrecognised is `unknown`.
  static SellerType sellerTypeOf(String? value) => switch (value) {
    'private' => SellerType.private,
    'dealer' => SellerType.dealer,
    _ => SellerType.unknown,
  };

  static ListingStatus _status(String? value) => switch (value) {
    'active' => ListingStatus.active,
    'price_changed' => ListingStatus.priceChanged,
    'removed' => ListingStatus.removed,
    'sold' => ListingStatus.sold,
    _ => ListingStatus.unknown,
  };

  /// Shared with the alert model; null when absent or unparseable.
  static DateTime? dateOf(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
