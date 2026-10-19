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
  });

  final int liveCount;

  /// Listings that left the market (sold or withdrawn: we can't tell).
  final int goneCount;
  final int pricedCount;
  final int droppedCount;
  final int? medianDaysToGone;
  final int? medianDaysListedLive;
  final double? medianDropPct;

  @override
  List<Object?> get props => [
    liveCount,
    goneCount,
    pricedCount,
    droppedCount,
    medianDaysToGone,
    medianDaysListedLive,
    medianDropPct,
  ];
}
