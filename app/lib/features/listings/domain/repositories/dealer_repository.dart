import '../entities/dealer_reliability.dart';
import '../entities/listing.dart';

abstract interface class DealerRepository {
  /// The figures of the dealer with this name (case and surrounding spaces
  /// ignored); null when there are none.
  Future<DealerReliability?> getByName(String sellerName);

  /// The dealer's ads on both sites (repeats left out): live ones newest
  /// first, then the gone ones, last seen first (`dealer_listings`, N.72).
  Future<List<Listing>> getListings(String sellerName);
}
