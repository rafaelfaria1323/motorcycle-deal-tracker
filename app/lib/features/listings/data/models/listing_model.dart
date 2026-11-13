import '../../domain/entities/bike_maintenance.dart';
import '../../domain/entities/bike_specs.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/photo_hint.dart';

class const ListingModel({
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
  super.mileageMaxSeen,
  super.yearFirstSeen,
  super.dealScore,
  super.initialPrice,
  super.priceBeforeDrop,
  super.price,
  super.scoreBreakdown,
  super.sellerName,
  super.location,
  super.description,
  super.registrations,
  super.hasFirstOwnerSignal,
  super.riskReasons,
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
  super.newPriceAdCount,
  super.engineCc,
  super.maintenance,
  super.specs,
  super.distanceKm,
  super.colour,
  super.myColour,
  super.marketPosition,
  super.photoHints,
  super.photoExamRequestedAt,
  super.photosExaminedAllAt,
}) extends Listing {
  /// The columns lists need (cards, alerts, other sources of a bike); the
  /// detail page loads the whole row. `distance_km`, `my_colour` and
  /// `market_position` are computed fields (from the caller's home and
  /// colours; the score breakdown), never part of `*`. Includes the optional card facts and risk-reason codes, not the
  /// description or full score breakdown, the bulk of a row.
  static const summaryColumns =
      'id, source, url, brand, model, motorcycle_id, duplicate_of, year, '
      'mileage, price, initial_price, price_before_drop, deal_score, '
      'risk_score, seller_type, location, images, status, first_seen_at, '
      'last_seen_at, distance_km, colour, my_colour, registrations, '
      'service_book, origin, warranty_until, dealer_warranty_months, '
      'seller_name, published_at, site_refreshed_at, market_position, '
      'card_risk_reasons:score_breakdown->risk_reasons';

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    // Present when the query embeds the matched model (detail page).
    final bike = json['motorcycles'] as Map<String, dynamic>?;
    // The dealers' new bikes for sale, else the typed list price (N.58).
    final fromAds = bike?['new_price_from_ads'] as num?;
    final breakdown = json['score_breakdown'] as Map<String, dynamic>?;
    final riskReasons = List<String>.from(
      json['card_risk_reasons'] as List? ??
          breakdown?['risk_reasons'] as List? ??
          const [],
    );
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
      mileageMaxSeen: json['mileage_max_seen'] as int?,
      yearFirstSeen: json['year_first_seen'] as int?,
      dealScore: json['deal_score'] as int?,
      initialPrice: (json['initial_price'] as num?)?.toDouble(),
      priceBeforeDrop: (json['price_before_drop'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      scoreBreakdown: breakdown,
      sellerType: sellerTypeOf(json['seller_type'] as String?),
      sellerName: json['seller_name'] as String?,
      location: json['location'] as String?,
      description: json['description'] as String?,
      images: List<String>.from(json['images'] as List? ?? const []),
      status: _status(json['status'] as String?),
      firstSeenAt: dateOf(json['first_seen_at']),
      lastSeenAt: dateOf(json['last_seen_at']),
      registrations: json['registrations'] as int?,
      hasFirstOwnerSignal: riskReasons.contains('first_owner'),
      riskReasons: riskReasons,
      serviceBook: json['service_book'] as bool?,
      origin: json['origin'] as String?,
      warrantyUntil: dateOf(json['warranty_until']),
      dealerWarrantyMonths: json['dealer_warranty_months'] as int?,
      publishedAt: dateOf(json['published_at']),
      siteRefreshedAt: dateOf(json['site_refreshed_at']),
      relistedFrom: json['relisted_from'] as String?,
      relistedSince: dateOf(json['relisted_since']),
      relistedPrice: (json['relisted_price'] as num?)?.toDouble(),
      newPrice: (fromAds ?? bike?['new_price_reference'] as num?)?.toDouble(),
      newPriceCheckedAt: fromAds == null
          ? dateOf(bike?['new_price_checked_at'])
          : null,
      newPriceAdCount: fromAds == null
          ? null
          : bike?['new_price_ad_count'] as int?,
      engineCc: engineCcOf(bike),
      maintenance: maintenanceOf(bike),
      specs: specsOf(bike),
      distanceKm: (json['distance_km'] as num?)?.toInt(),
      colour: json['colour'] as String?,
      myColour: json['my_colour'] as bool? ?? false,
      marketPosition: (json['market_position'] as num?)?.toDouble(),
      photoHints: photoHintsOf(json['photo_hints']),
      photoExamRequestedAt: dateOf(json['photo_exam_requested_at']),
      photosExaminedAllAt: dateOf(json['photos_examined_all_at']),
    );
  }

  /// `photo_hints` ([{code, photo, p}]); entries without a code or photo
  /// are left out.
  static List<PhotoHint> photoHintsOf(Object? value) => [
    if (value is List)
      for (final Object? hint in value)
        if (hint case {
          'code': final String code,
          'photo': final num photo,
          'p': final num share,
        })
          PhotoHint(code: code, photo: photo.toInt(), share: share.toDouble()),
  ];

  /// The middle of the model's engine range ("680-710" -> 695), or the one
  /// limit it has; null without either.
  static int? engineCcOf(Map<String, dynamic>? bike) {
    final min = (bike?['engine_cc_min'] as num?)?.toInt();
    final max = (bike?['engine_cc_max'] as num?)?.toInt();
    if (min == null || max == null) return min ?? max;
    return ((min + max) / 2).round();
  }

  /// The columns of `motorcycles` that [maintenanceOf] reads.
  static const maintenanceColumns =
      'front_tyre, rear_tyre, cylinders, service_interval_km, valve_check_km, '
      'fuel_l_per_100km';

  /// The model's maintenance figures; null when it has none.
  static BikeMaintenance? maintenanceOf(Map<String, dynamic>? bike) {
    if (bike == null) return null;
    final value = BikeMaintenance(
      frontTyre: bike['front_tyre'] as String?,
      rearTyre: bike['rear_tyre'] as String?,
      cylinders: (bike['cylinders'] as num?)?.toInt(),
      serviceIntervalKm: (bike['service_interval_km'] as num?)?.toInt(),
      valveCheckKm: (bike['valve_check_km'] as num?)?.toInt(),
      fuelPer100Km: (bike['fuel_l_per_100km'] as num?)?.toDouble(),
    );
    return value == const BikeMaintenance() ? null : value;
  }

  /// The columns of `motorcycles` that [specsOf] reads.
  static const specColumns =
      'power_kw, torque_nm, weight_kg, seat_height_mm, tank_l';

  /// The model's specifications; null when it has none.
  static BikeSpecs? specsOf(Map<String, dynamic>? bike) {
    if (bike == null) return null;
    final value = BikeSpecs(
      powerKw: (bike['power_kw'] as num?)?.toDouble(),
      torqueNm: (bike['torque_nm'] as num?)?.toDouble(),
      weightKg: (bike['weight_kg'] as num?)?.toInt(),
      seatHeightMm: (bike['seat_height_mm'] as num?)?.toInt(),
      tankLitres: (bike['tank_l'] as num?)?.toDouble(),
    );
    return value == const BikeSpecs() ? null : value;
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
