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
}
