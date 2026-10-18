import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/saved_search.dart';

class SavedSearchModel {
  const SavedSearchModel._();

  static SavedSearch fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'] as String,
      name: json['name'] as String?,
      filters: ListingFilters(
        motorcycleId: json['motorcycle_id'] as String?,
        minYear: json['min_year'] as int?,
        maxPrice: (json['max_price'] as num?)?.toDouble(),
        maxMileage: json['max_mileage'] as int?,
        location: json['location'] as String?,
        sellerType: _sellerType(json['seller_type'] as String?),
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      notifyNewListing: json['notify_new_listing'] as bool? ?? true,
      notifyPriceReduction: json['notify_price_reduction'] as bool? ?? true,
      notifyExcellentDeal: json['notify_excellent_deal'] as bool? ?? false,
      notifyListingRemoved: json['notify_listing_removed'] as bool? ?? false,
    );
  }

  /// The row to insert. `user_id` is filled in by the database
  /// (`default auth.uid()`), so the app never sends it.
  static Map<String, Object?> toInsert(String name, ListingFilters filters) {
    return {
      'name': name,
      'motorcycle_id': filters.motorcycleId,
      'min_year': filters.minYear,
      'max_price': filters.maxPrice,
      'max_mileage': filters.maxMileage,
      'location': filters.location,
      'seller_type': filters.sellerType?.name,
    };
  }

  // In a saved search, null means "any", so "unknown" is the same as null.
  static SellerType? _sellerType(String? value) => switch (value) {
    'private' => SellerType.private,
    'dealer' => SellerType.dealer,
    _ => null,
  };
}
