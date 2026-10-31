import 'package:equatable/equatable.dart';

/// What we have seen of one dealer's ads, on both sites (view
/// `dealer_reliability`). Private sellers never have one.
class const DealerReliability({
  required final String name,

  /// Ads that are not a repeat of another ad.
  required final int bikes,
  required final int live,

  /// Put up again after the earlier ad went.
  required final int relisted,

  /// A price step of half or more, up or down.
  required final int sharpChanges,
  required final int missingMileage,

  /// A used bike posted twice on the same site.
  required final int repeated,

  /// Bikes whose price went down.
  required final int dropped,
  final DateTime? firstSeenAt,
}) extends Equatable {
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
