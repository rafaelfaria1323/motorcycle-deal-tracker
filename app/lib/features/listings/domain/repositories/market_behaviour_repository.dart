import '../entities/market_behaviour.dart';

abstract interface class MarketBehaviourRepository {
  /// Null when the model has no listings.
  Future<MarketBehaviour?> getForModel(String motorcycleId);
}
