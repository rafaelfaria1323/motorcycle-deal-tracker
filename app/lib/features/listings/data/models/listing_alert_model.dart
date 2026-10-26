import '../../domain/entities/listing_alert.dart';
import 'listing_model.dart';

class ListingAlertModel {
  const ListingAlertModel._();

  /// Expects the row with its listing (`ListingModel.summaryColumns`) and
  /// saved search embedded: `select('*, listings(...), saved_searches(name)')`.
  static ListingAlert fromJson(Map<String, dynamic> json) {
    final search = json['saved_searches'] as Map<String, dynamic>?;
    return ListingAlert(
      id: json['id'] as String,
      type: _type(json['type'] as String?),
      listing: ListingModel.fromJson(json['listings'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      searchId: json['saved_search_id'] as String?,
      searchName: search?['name'] as String?,
      oldPrice: (json['old_price'] as num?)?.toDouble(),
      newPrice: (json['new_price'] as num?)?.toDouble(),
      readAt: ListingModel.dateOf(json['read_at'])?.toLocal(),
    );
  }

  static AlertType _type(String? value) => switch (value) {
    'new_listing' => AlertType.newListing,
    'price_reduction' => AlertType.priceReduction,
    'excellent_opportunity' => AlertType.excellentOpportunity,
    'listing_removed' => AlertType.listingRemoved,
    'back_on_market' => AlertType.backOnMarket,
    'target_price_reached' => AlertType.targetPriceReached,
    _ => AlertType.unknown,
  };
}
