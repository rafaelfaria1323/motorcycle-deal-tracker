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
    super.newPrice,
    super.newPriceCheckedAt,
  });

  /// The columns lists need (cards, alerts, other sources of a bike); the
  /// detail page loads the whole row. Leaves out the description and score
  /// breakdown, the bulk of a row.
  static const summaryColumns =
      'id, source, url, brand, model, motorcycle_id, duplicate_of, year, '
      'mileage, price, initial_price, price_before_drop, deal_score, '
      'risk_score, seller_type, location, images, status, first_seen_at, '
      'last_seen_at';

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    // Present when the query embeds the matched model's new-bike price.
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
      dealScore: json['deal_score'] as int?,
      initialPrice: (json['initial_price'] as num?)?.toDouble(),
      priceBeforeDrop: (json['price_before_drop'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      scoreBreakdown: json['score_breakdown'] as Map<String, dynamic>?,
      sellerType: _sellerType(json['seller_type'] as String?),
      sellerName: json['seller_name'] as String?,
      location: json['location'] as String?,
      description: json['description'] as String?,
      images: List<String>.from(json['images'] as List? ?? const []),
      status: _status(json['status'] as String?),
      firstSeenAt: _date(json['first_seen_at']),
      lastSeenAt: _date(json['last_seen_at']),
      registrations: json['registrations'] as int?,
      serviceBook: json['service_book'] as bool?,
      origin: json['origin'] as String?,
      warrantyUntil: _date(json['warranty_until']),
      dealerWarrantyMonths: json['dealer_warranty_months'] as int?,
      publishedAt: _date(json['published_at']),
      siteRefreshedAt: _date(json['site_refreshed_at']),
      newPrice: (bike?['new_price_reference'] as num?)?.toDouble(),
      newPriceCheckedAt: _date(bike?['new_price_checked_at']),
    );
  }

  static SellerType _sellerType(String? value) => switch (value) {
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

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
