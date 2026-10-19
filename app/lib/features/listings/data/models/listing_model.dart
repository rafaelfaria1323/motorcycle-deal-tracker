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
  });

  factory ListingModel.fromJson(Map<String, dynamic> json) {
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
      firstSeenAt: json['first_seen_at'] == null
          ? null
          : DateTime.parse(json['first_seen_at'] as String),
      lastSeenAt: json['last_seen_at'] == null
          ? null
          : DateTime.parse(json['last_seen_at'] as String),
      registrations: json['registrations'] as int?,
      serviceBook: json['service_book'] as bool?,
      origin: json['origin'] as String?,
      warrantyUntil: _date(json['warranty_until']),
      dealerWarrantyMonths: json['dealer_warranty_months'] as int?,
      publishedAt: _date(json['published_at']),
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
