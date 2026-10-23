import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/saved_search.dart';
import 'listing_model.dart';

class SavedSearchModel {
  const SavedSearchModel._();

  static SavedSearch fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'] as String,
      name: json['name'] as String?,
      filters: ListingFilters(
        motorcycleIds: List<String>.from(
          json['motorcycle_ids'] as List? ?? const [],
        ),
        minYear: json['min_year'] as int?,
        maxPrice: (json['max_price'] as num?)?.toDouble(),
        maxMileage: json['max_mileage'] as int?,
        location: json['location'] as String?,
        sellerType: _sellerType(json['seller_type'] as String?),
        minDealScore: json['min_deal_score'] as int?,
        maxRiskScore: json['max_risk_score'] as int?,
        maxDistanceKm: json['max_distance_km'] as int?,
        extras: List<String>.from(json['extras'] as List? ?? const []),
        onlyMyColours: json['only_my_colours'] as bool? ?? false,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      notifyNewListing: json['notify_new_listing'] as bool? ?? true,
      notifyPriceReduction: json['notify_price_reduction'] as bool? ?? true,
      notifyExcellentDeal: json['notify_excellent_deal'] as bool? ?? false,
      notifyListingRemoved: json['notify_listing_removed'] as bool? ?? false,
    );
  }

  static Map<String, Object?> _criteria(ListingFilters filters) => {
    'motorcycle_ids': filters.motorcycleIds,
    'min_year': filters.minYear,
    'max_price': filters.maxPrice,
    'max_mileage': filters.maxMileage,
    'location': filters.location,
    'seller_type': filters.sellerType?.name,
    'min_deal_score': filters.minDealScore,
    'max_risk_score': filters.maxRiskScore,
    'max_distance_km': filters.maxDistanceKm,
    'extras': filters.extras,
    'only_my_colours': filters.onlyMyColours,
  };

  /// The row to insert. `user_id` is filled in by the database
  /// (`default auth.uid()`), so the app never sends it.
  static Map<String, Object?> toInsert(String name, ListingFilters filters) {
    return {'name': name, ..._criteria(filters)};
  }

  /// The columns an edit may change. Cleared criteria are sent as explicit
  /// nulls, which is how "any" is stored. `user_id` is never touched.
  static Map<String, Object?> toUpdate(SavedSearch search) {
    return {
      'name': search.name,
      ..._criteria(search.filters),
      'notify_new_listing': search.notifyNewListing,
      'notify_price_reduction': search.notifyPriceReduction,
      'notify_excellent_deal': search.notifyExcellentDeal,
      'notify_listing_removed': search.notifyListingRemoved,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  // In a saved search, null means "any", so "unknown" is the same as null.
  static SellerType? _sellerType(String? value) {
    final type = ListingModel.sellerTypeOf(value);
    return type == SellerType.unknown ? null : type;
  }
}
