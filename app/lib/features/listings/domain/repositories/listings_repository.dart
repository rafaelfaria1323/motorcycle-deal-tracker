import '../entities/listing.dart';

abstract interface class ListingsRepository {
  Future<List<Listing>> getListings();
}