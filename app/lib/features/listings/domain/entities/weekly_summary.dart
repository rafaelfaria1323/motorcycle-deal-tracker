import 'package:equatable/equatable.dart';

/// The account's latest weekly summary (`weekly_summaries`), made by the
/// collector each Monday or when asked for in the app: the last 7 days of
/// the account's own models.
class const WeeklySummary({
  /// The 7 days summed up: [since, until).
  required final DateTime since,
  required final DateTime until,
  required final DateTime madeAt,
  required final int liveCount,
  required final int newCount,
  required final int goneCount,
  required final int dropCount,

  /// New listings per model, most first.
  final List<({String bike, int count})> newByModel = const [],

  /// Live listings whose price fell, biggest drop first.
  final List<SummaryDeal> biggestDrops = const [],

  /// Live listings by Deal Score, best first (risk below 50 only).
  final List<SummaryDeal> bestDeals = const [],
}) extends Equatable {
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
class const SummaryDeal({
  required final String listingId,

  /// Catalog brand and model, e.g. "Yamaha MT-07".
  required final String bike,
  final int? year,
  final double? price,
  final double? oldPrice,
  final int? mileage,
  final int? dealScore,
}) extends Equatable {
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
