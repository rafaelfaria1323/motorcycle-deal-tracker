import 'package:equatable/equatable.dart';

/// The account's latest weekly summary (`weekly_summaries`), made by the
/// collector each Monday or when asked for in the app: the last 7 days of
/// the account's own models.
class WeeklySummary extends Equatable {
  const WeeklySummary({
    required this.since,
    required this.until,
    required this.madeAt,
    required this.liveCount,
    required this.newCount,
    required this.goneCount,
    required this.dropCount,
    this.newByModel = const [],
    this.biggestDrops = const [],
    this.bestDeals = const [],
  });

  /// The 7 days summed up: [since, until).
  final DateTime since;
  final DateTime until;
  final DateTime madeAt;
  final int liveCount;
  final int newCount;
  final int goneCount;
  final int dropCount;

  /// New listings per model, most first.
  final List<({String bike, int count})> newByModel;

  /// Live listings whose price fell, biggest drop first.
  final List<SummaryDeal> biggestDrops;

  /// Live listings by Deal Score, best first (risk below 50 only).
  final List<SummaryDeal> bestDeals;

  @override
  List<Object?> get props => [
    since,
    until,
    madeAt,
    liveCount,
    newCount,
    goneCount,
    dropCount,
    newByModel,
    biggestDrops,
    bestDeals,
  ];
}

/// A listing named in the summary; [oldPrice] only for a price drop.
class SummaryDeal extends Equatable {
  const SummaryDeal({
    required this.listingId,
    required this.bike,
    this.year,
    this.price,
    this.oldPrice,
    this.mileage,
    this.dealScore,
  });

  final String listingId;

  /// Catalog brand and model, e.g. "Yamaha MT-07".
  final String bike;
  final int? year;
  final double? price;
  final double? oldPrice;
  final int? mileage;
  final int? dealScore;

  @override
  List<Object?> get props => [
    listingId,
    bike,
    year,
    price,
    oldPrice,
    mileage,
    dealScore,
  ];
}
