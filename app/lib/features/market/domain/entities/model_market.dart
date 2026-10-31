import 'package:equatable/equatable.dart';

import 'market_behaviour.dart';

/// A tracked model's market, for the comparison of models.
class const ModelMarket({
  required final String motorcycleId,
  required final String brand,
  required final String model,

  /// Null when the model has no live listing with a price.
  final PriceSpread? prices,
  final MarketBehaviour? behaviour,

  /// The last weeks' asking prices, oldest first; weeks without ads left
  /// out.
  final List<PriceTrendWeek> trend = const [],
}) extends Equatable {
  String get name => '$brand $model';

  @override
  List<Object?> get props => [
    motorcycleId,
    brand,
    model,
    prices,
    behaviour,
    trend,
  ];
}

/// One week of a model's asking prices (`model_price_trend`): the ads seen
/// that week at their price by its end.
class const PriceTrendWeek({
  /// The Monday the week starts on.
  required final DateTime weekStart,
  required final int count,
  required final double median,

  /// The median with every bike brought to the model's typical year and
  /// mileage of today, so a week with newer bikes doesn't look dearer.
  required final double adjustedMedian,
}) extends Equatable {
  @override
  List<Object?> get props => [weekStart, count, median, adjustedMedian];
}

/// The model's live asking prices (duplicates left out).
class const PriceSpread({
  required final int count,
  required final double min,
  required final double p25,
  required final double median,
  required final double p75,
  required final double max,
  final int? medianYear,
  final int? medianMileage,
}) extends Equatable {
  @override
  List<Object?> get props => [
    count,
    min,
    p25,
    median,
    p75,
    max,
    medianYear,
    medianMileage,
  ];
}
