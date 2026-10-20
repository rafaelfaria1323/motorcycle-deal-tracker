import '../entities/listing.dart';
import '../entities/listing_filters.dart';
import '../entities/listing_sort.dart';
import '../entities/motorcycle_option.dart';
import '../entities/price_point.dart';

abstract interface class ListingsRepository {
  /// One page of listings, [limit] long from [offset]; a shorter page is
  /// the last one.
  Future<List<Listing>> getListings({
    ListingFilters filters = ListingFilters.empty,
    ListingSort sort = ListingSort.newest,
    int offset = 0,
    int limit = 40,
  });

  /// Returns null when no listing has this id.
  Future<Listing?> getListingById(String id);

  /// Active catalog models, for the model filter.
  Future<List<MotorcycleOption>> getMotorcycleOptions();

  /// Other listings of the same bike: the original's reposts, or, for a
  /// repost, the original plus its siblings.
  Future<List<Listing>> getAlsoListed(Listing listing);

  Future<List<PricePoint>> getPriceHistory(String listingId);

  /// Up to three live listings of the same model that cost less, of a year
  /// at most one apart and with no more km (cheapest first): arguments to
  /// negotiate with. Empty without a model or a price.
  Future<List<Listing>> getCheaperSimilar(Listing listing);
}
