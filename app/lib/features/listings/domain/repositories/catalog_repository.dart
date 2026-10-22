import '../entities/catalog_model.dart';
import '../entities/site_model.dart';

/// The catalog changes below need a signed-in account; they throw otherwise.
abstract interface class CatalogRepository {
  /// Every catalog model, tracked or not.
  Future<List<CatalogModel>> getModels();

  Future<void> setTracked(String motorcycleId, {required bool tracked});

  Future<void> setMinYear(String motorcycleId, int minYear);

  /// The account's favourite colours for the model (codes).
  Future<void> setColours(String motorcycleId, List<String> colours);

  /// Sets the new-bike list price, checked today; null clears it.
  Future<void> setNewPrice(String motorcycleId, double? price);

  /// The brands the sites offer, for the model picker (filled by the
  /// collector; empty before its first run).
  Future<List<SiteMake>> getSiteMakes();

  /// The models both sites offer for a brand.
  Future<List<SiteModel>> getSiteModels(String makeId);

  /// Adds a model, tracked from the next collection. The engine size range
  /// tells it apart from other sizes of the same family (Forza 125 / 350).
  Future<void> addModel({
    required String brand,
    required String model,
    required int minYear,
    String? olxSearch,
    String? standvirtualSearch,
    List<String> aliases = const [],
    int? engineCcMin,
    int? engineCcMax,
  });
}
