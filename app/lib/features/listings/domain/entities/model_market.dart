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
  });

  final String motorcycleId;
  final String brand;
  final String model;

  /// Null when the model has no live listing with a price.
  final PriceSpread? prices;
  final MarketBehaviour? behaviour;

  String get name => '$brand $model';

  @override
  List<Object?> get props => [motorcycleId, brand, model, prices, behaviour];
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
