import 'package:equatable/equatable.dart';

/// What we have seen of one dealer's ads, on both sites (view
/// `dealer_reliability`). Private sellers never have one.
class DealerReliability extends Equatable {
  const DealerReliability({
    required this.name,
    required this.bikes,
    required this.live,
    required this.relisted,
    required this.sharpChanges,
    required this.missingMileage,
    required this.repeated,
    required this.dropped,
    this.firstSeenAt,
  });

  final String name;

  /// Ads that are not a repeat of another ad.
  final int bikes;
  final int live;

  /// Put up again after the earlier ad went.
  final int relisted;

  /// A price step of half or more, up or down.
  final int sharpChanges;
  final int missingMileage;

  /// A used bike posted twice on the same site.
  final int repeated;

  /// Bikes whose price went down.
  final int dropped;
  final DateTime? firstSeenAt;

  @override
  List<Object?> get props => [
    name,
    bikes,
    live,
    relisted,
    sharpChanges,
    missingMileage,
    repeated,
    dropped,
    firstSeenAt,
  ];
}
