import '../../../valuation/domain/entities/bike_value.dart';
import '../../../valuation/domain/entities/bike_value_request.dart';
import '../entities/exit_price.dart';
import '../entities/gone_deal.dart';
import '../entities/market_behaviour.dart';
import '../entities/model_market.dart';
import '../entities/price_drop_outlook.dart';

abstract interface class MarketBehaviourRepository {
  /// Null when the model has no listings.
  Future<MarketBehaviour?> getForModel(String motorcycleId);

  /// How long the listing is likely to stay on the market; null when it
  /// has no model.
  Future<TimeToSale?> getTimeToSale(String listingId);

  /// What the model's other ads did in the 30 days after they were as old
  /// as this listing (N.83); null when it has no model, is gone or has no
  /// real price.
  Future<PriceDropOutlook?> getPriceDropOutlook(String listingId);

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

  /// What [motorcycleId]'s ads gone in the last 90 days left the market
  /// at, brought to [year] and [mileage] (unknown: not adjusted for it);
  /// [except] leaves out that listing and the one it repeats.
  Future<ExitPrice> getExitPrice(
    String motorcycleId, {
    int? year,
    int? mileage,
    String? except,
  });

  /// [motorcycleId]'s ads gone in the last 90 days that likely sold
  /// (duplicates left out), the latest first (N.68).
  Future<List<GoneDeal>> getGoneDeals(String motorcycleId);

  /// The catalog model to value a bike of [brand] [model], found by name
  /// or added (not followed, not collected until a value is asked for).
  /// Signed-in accounts only.
  Future<String> bikeValueModel({
    required String brand,
    required String model,
    String? olxSearch,
    String? standvirtualSearch,
    int? engineCcMin,
    int? engineCcMax,
  });

  /// Asks for the value of a bike of [motorcycleId]: [ready] when the
  /// model's listings are collected for that year, else the request waits
  /// for the next collection (which starts collecting the model). Throws
  /// [BikeValueRequestLimit] past the day's waiting requests.
  Future<({String requestId, bool ready})> requestBikeValue(
    String motorcycleId, {
    required int year,
    int? mileage,
  });

  /// Asks for the evaluation of the ad at [url] (N.102), a bike of
  /// [motorcycleId] and [year]: [listingId] when the ad is stored and
  /// scored (open it now), else the request waits for the collection of
  /// the model, which pushes the ad's scores. Throws
  /// [BikeValueRequestLimit] past the day's waiting requests.
  Future<({String requestId, String? listingId})> requestAdCheck(
    String url, {
    required String motorcycleId,
    required int year,
    int? mileage,
  });

  /// The stored listing of the ad at [url], or null.
  Future<String?> listingForAd(String url);

  /// The account's requests, newest first.
  Future<List<BikeValueRequest>> getBikeValueRequests();
}
