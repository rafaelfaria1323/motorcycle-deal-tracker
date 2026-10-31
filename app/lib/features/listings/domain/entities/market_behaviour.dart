import 'package:equatable/equatable.dart';

class const MarketBehaviour({
  required final int liveCount,

  /// Listings that left the market (sold or withdrawn: we can't tell).
  required final int goneCount,
  required final int pricedCount,
  required final int droppedCount,
  final int? medianDaysToGone,
  final int? medianDaysListedLive,
  final double? medianDropPct,
  final Depreciation? depreciation,
}) extends Equatable {
  @override
  List<Object?> get props => [
    liveCount,
    goneCount,
    pricedCount,
    droppedCount,
    medianDaysToGone,
    medianDaysListedLive,
    medianDropPct,
    depreciation,
  ];
}

/// How fast the model loses value: the share of the price a bike loses per
/// year of age and per 1000 km, as the fair price uses them.
class const Depreciation({
  /// Live listings with price, year and mileage the rates are fitted on.
  required final int sampleCount,

  /// False when the model has too few listings and the general rates apply.
  required final bool isFitted,

  /// Rates of the model's exponential price curve (0.04 = about 4 %).
  required final double perYear,
  required final double per1000Km,
}) extends Equatable {
  @override
  List<Object?> get props => [sampleCount, isFitted, perYear, per1000Km];
}

/// Where a listing's price sat against its estimated value, for the time
/// to sale (`market_band` in the database).
enum PriceBand { below, near, above }

/// How long a listing is likely to stay on the market (10.4), from the
/// model's other ads: those that left and those still live (which have
/// lasted at least their age).
class const TimeToSale({
  required final int goneCount,
  required final int liveCount,
  required final int daysListed,

  /// The price band the figures come from; null: every ad of the model.
  final PriceBand? band,

  /// Days until half the ads left, from their first day.
  final int? typicalDays,

  /// Days until half the ads that lasted as long as this one left; null
  /// when too few did, or the listing is no longer live.
  final int? remainingDays,
}) extends Equatable {
  @override
  List<Object?> get props => [
    band,
    goneCount,
    liveCount,
    daysListed,
    typicalDays,
    remainingDays,
  ];
}
