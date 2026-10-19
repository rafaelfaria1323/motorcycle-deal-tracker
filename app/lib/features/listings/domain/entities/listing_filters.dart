import 'package:equatable/equatable.dart';

import 'listing.dart';

class ListingFilters extends Equatable {
  const ListingFilters({
    this.motorcycleId,
    this.minYear,
    this.maxPrice,
    this.maxMileage,
    this.location,
    this.sellerType,
    this.minDealScore,
    this.maxRiskScore,
    this.activeOnly = true,
  });

  static const empty = ListingFilters();

  final String? motorcycleId;
  final int? minYear;
  final double? maxPrice;
  final int? maxMileage;
  final String? location;
  final SellerType? sellerType;

  /// Listings without a score never match a set score criterion.
  final int? minDealScore;
  final int? maxRiskScore;
  final bool activeOnly;

  /// How many filters differ from the defaults (shown on the filter button).
  int get appliedCount => [
    motorcycleId != null,
    minYear != null,
    maxPrice != null,
    maxMileage != null,
    location != null,
    sellerType != null,
    minDealScore != null,
    maxRiskScore != null,
    !activeOnly,
  ].where((applied) => applied).length;

  @override
  List<Object?> get props => [
    motorcycleId,
    minYear,
    maxPrice,
    maxMileage,
    location,
    sellerType,
    minDealScore,
    maxRiskScore,
    activeOnly,
  ];
}
