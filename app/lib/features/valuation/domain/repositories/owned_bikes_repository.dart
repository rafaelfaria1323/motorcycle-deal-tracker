import '../entities/owned_bike.dart';

abstract interface class OwnedBikesRepository {
  /// The current account's bikes, the latest bought first.
  Future<List<OwnedBike>> list();

  /// Adds a bike; one bought from an ad already kept is updated instead.
  Future<void> add(OwnedBikeDraft bike);

  /// Replaces what the owner told about bike [id].
  Future<void> update(String id, OwnedBikeDraft bike);

  Future<void> delete(String id);
}
