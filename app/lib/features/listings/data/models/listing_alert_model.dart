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

  static const _codes = {
    AlertType.newListing: 'new_listing',
    AlertType.priceReduction: 'price_reduction',
    AlertType.excellentOpportunity: 'excellent_opportunity',
    AlertType.listingRemoved: 'listing_removed',
    AlertType.backOnMarket: 'back_on_market',
    AlertType.targetPriceReached: 'target_price_reached',
  };

  /// The database's `alert_type` value; null for [AlertType.unknown].
  static String? code(AlertType type) => _codes[type];

  static final _types = {
    for (final entry in _codes.entries) entry.value: entry.key,
  };

  static AlertType _type(String? value) => _types[value] ?? AlertType.unknown;
}
