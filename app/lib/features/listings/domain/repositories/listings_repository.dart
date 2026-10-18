import '../entities/listing.dart';
import '../entities/listing_filters.dart';
import '../entities/listing_sort.dart';
import '../entities/motorcycle_option.dart';

abstract interface class ListingsRepository {
  Future<List<Listing>> getListings({
    ListingFilters filters = ListingFilters.empty,
    ListingSort sort = ListingSort.newest,
  });

  /// Returns null when no listing has this id.
  Future<Listing?> getListingById(String id);

  /// Active catalog models, for the model filter.
  Future<List<MotorcycleOption>> getMotorcycleOptions();

  /// Other listings of the same bike: the original's reposts, or, for a
  /// repost, the original plus its siblings.
  Future<List<Listing>> getAlsoListed(Listing listing);
}
