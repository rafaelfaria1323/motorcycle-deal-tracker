import '../entities/catalog_model.dart';

abstract interface class CatalogRepository {
  /// Every catalog model, tracked or not.
  Future<List<CatalogModel>> getModels();

  /// Only a signed-in account may change it; throws otherwise.
  Future<void> setTracked(String motorcycleId, {required bool tracked});
}
