import 'package:equatable/equatable.dart';

/// An ad of a model that left the market in the last 90 days and likely
/// sold (`gone_deals`, N.68; `exit_kind`, N.61), with the Deal Score it
/// last had and how long the bike was on sale. Shown only; never a score.
class const GoneDeal({
  required final String listingId,
  final int? year,
  final int? mileage,
  required final double price,

  /// Null when it was never scored.
  final int? dealScore,

  /// From the bike's first publication (earlier ads included) to when it
  /// was last seen.
  required final int daysListed,
  required final DateTime goneAt,
}) extends Equatable {
  @override
  List<Object?> get props => [
    listingId,
    year,
    mileage,
    price,
    dealScore,
    daysListed,
    goneAt,
  ];
}
