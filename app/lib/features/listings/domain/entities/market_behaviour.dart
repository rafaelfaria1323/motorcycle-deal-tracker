import 'package:equatable/equatable.dart';

class MarketBehaviour extends Equatable {
  const MarketBehaviour({
    required this.liveCount,
    required this.goneCount,
    required this.pricedCount,
    required this.droppedCount,
    this.medianDaysToGone,
    this.medianDaysListedLive,
    this.medianDropPct,
    this.depreciation,
  });

  final int liveCount;

  /// Listings that left the market (sold or withdrawn: we can't tell).
  final int goneCount;
  final int pricedCount;
  final int droppedCount;
  final int? medianDaysToGone;
  final int? medianDaysListedLive;
  final double? medianDropPct;
  final Depreciation? depreciation;

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
class Depreciation extends Equatable {
  const Depreciation({
    required this.sampleCount,
    required this.isFitted,
    required this.perYear,
    required this.per1000Km,
  });

  /// Live listings with price, year and mileage the rates are fitted on.
  final int sampleCount;

  /// False when the model has too few listings and the general rates apply.
  final bool isFitted;

  /// Rates of the model's exponential price curve (0.04 = about 4 %).
  final double perYear;
  final double per1000Km;

  @override
  List<Object?> get props => [sampleCount, isFitted, perYear, per1000Km];
}

/// Where a listing's price sat against its estimated value, for the time
/// to sale (`market_band` in the database).
enum PriceBand { below, near, above }

/// How long a listing is likely to stay on the market (10.4), from the
/// model's other ads: those that left and those still live (which have
/// lasted at least their age).
class TimeToSale extends Equatable {
  const TimeToSale({
    required this.goneCount,
    required this.liveCount,
    required this.daysListed,
    this.band,
    this.typicalDays,
    this.remainingDays,
  });

  /// The price band the figures come from; null: every ad of the model.
  final PriceBand? band;
  final int goneCount;
  final int liveCount;
  final int daysListed;

  /// Days until half the ads left, from their first day.
  final int? typicalDays;

  /// Days until half the ads that lasted as long as this one left; null
  /// when too few did, or the listing is no longer live.
  final int? remainingDays;

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
