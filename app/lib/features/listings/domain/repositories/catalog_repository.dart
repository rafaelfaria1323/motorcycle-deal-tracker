import '../entities/catalog_model.dart';

/// The catalog changes below need a signed-in account; they throw otherwise.
abstract interface class CatalogRepository {
  /// Every catalog model, tracked or not.
  Future<List<CatalogModel>> getModels();

  Future<void> setTracked(String motorcycleId, {required bool tracked});

  Future<void> setMinYear(String motorcycleId, int minYear);

  /// Sets the new-bike list price, checked today; null clears it.
  Future<void> setNewPrice(String motorcycleId, double? price);

  /// Adds a model, tracked from the next collection.
  Future<void> addModel({
    required String brand,
    required String model,
    required int minYear,
    String? olxSearch,
    String? standvirtualSearch,
    List<String> aliases = const [],
  });
}
