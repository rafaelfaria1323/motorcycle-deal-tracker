import 'package:equatable/equatable.dart';

import 'market_behaviour.dart';

/// A tracked model's market, for the comparison of models.
class ModelMarket extends Equatable {
  const ModelMarket({
    required this.motorcycleId,
    required this.brand,
    required this.model,
    this.prices,
    this.behaviour,
    this.trend = const [],
  });

  final String motorcycleId;
  final String brand;
  final String model;

  /// Null when the model has no live listing with a price.
  final PriceSpread? prices;
  final MarketBehaviour? behaviour;

  /// The last weeks' asking prices, oldest first; weeks without ads left
  /// out.
  final List<PriceTrendWeek> trend;

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
class PriceTrendWeek extends Equatable {
  const PriceTrendWeek({
    required this.weekStart,
    required this.count,
    required this.median,
    required this.adjustedMedian,
  });

  /// The Monday the week starts on.
  final DateTime weekStart;
  final int count;
  final double median;

  /// The median with every bike brought to the model's typical year and
  /// mileage of today, so a week with newer bikes doesn't look dearer.
  final double adjustedMedian;

  @override
  List<Object?> get props => [weekStart, count, median, adjustedMedian];
}

/// The model's live asking prices (duplicates left out).
class PriceSpread extends Equatable {
  const PriceSpread({
    required this.count,
    required this.min,
    required this.p25,
    required this.median,
    required this.p75,
    required this.max,
    this.medianYear,
    this.medianMileage,
  });

  final int count;
  final double min;
  final double p25;
  final double median;
  final double p75;
  final double max;
  final int? medianYear;
  final int? medianMileage;

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
