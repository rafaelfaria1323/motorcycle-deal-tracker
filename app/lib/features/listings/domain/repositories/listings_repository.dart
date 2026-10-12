import '../entities/listing.dart';

abstract interface class ListingsRepository {
  Future<List<Listing>> getListings({String? motorcycleId});

  /// Returns null when no listing has this id.
  Future<Listing?> getListingById(String id);
}
