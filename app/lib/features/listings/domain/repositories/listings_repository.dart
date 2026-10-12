import '../entities/listing.dart';
import '../entities/listing_sort.dart';

abstract interface class ListingsRepository {
  Future<List<Listing>> getListings({String? motorcycleId, ListingSort sort = ListingSort.newest});

  /// Returns null when no listing has this id.
  Future<Listing?> getListingById(String id);
}
