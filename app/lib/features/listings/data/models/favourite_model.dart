import '../../domain/entities/favourite.dart';
import 'listing_model.dart';

class FavouriteModel {
  const FavouriteModel._();

  /// Expects the row with its listing embedded:
  /// `select('listing_id, note, created_at, listings(...)')`.
  static Favourite fromJson(Map<String, dynamic> json) {
    final listing = json['listings'] as Map<String, dynamic>?;
    return Favourite(
      listingId: json['listing_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      note: json['note'] as String?,
      listing: listing == null ? null : ListingModel.fromJson(listing),
    );
  }
}
