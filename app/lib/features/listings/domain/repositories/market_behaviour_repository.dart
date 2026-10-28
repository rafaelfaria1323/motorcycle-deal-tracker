import '../entities/bike_value.dart';
import '../entities/market_behaviour.dart';
import '../entities/model_market.dart';

abstract interface class MarketBehaviourRepository {
  /// Null when the model has no listings.
  Future<MarketBehaviour?> getForModel(String motorcycleId);

  /// Asking prices of the model's live listings (duplicates left out), by
  /// listing id.
  Future<Map<String, double>> getLivePrices(String motorcycleId);

  /// The market of every tracked model, for the comparison of models.
  Future<List<ModelMarket>> getTrackedModels();

  /// What a bike of [motorcycleId] from [year] with [mileage] km (unknown:
  /// any) is worth, from the model's live asking prices.
  Future<BikeValue> getBikeValue(
    String motorcycleId, {
    required int year,
    int? mileage,
  });
}
