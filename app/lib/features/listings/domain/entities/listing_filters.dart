import 'package:equatable/equatable.dart';

import 'listing.dart';

class ListingFilters extends Equatable {
  const ListingFilters({
    this.motorcycleIds = const [],
    this.minYear,
    this.maxPrice,
    this.maxMileage,
    this.location,
    this.sellerType,
    this.minDealScore,
    this.maxRiskScore,
    this.maxDistanceKm,
    this.extras = const [],
    this.onlyMyColours = false,
    this.activeOnly = true,
  });

  static const empty = ListingFilters();

  /// The models asked for (catalog ids); empty: any model.
  final List<String> motorcycleIds;
  final int? minYear;
  final double? maxPrice;
  final int? maxMileage;
  final String? location;
  final SellerType? sellerType;

  /// Listings without a score never match a set score criterion.
  final int? minDealScore;
  final int? maxRiskScore;

  /// Km from the person's home; listings whose place is unknown never match.
  final int? maxDistanceKm;

  /// Equipment codes the ad must all mention (`listing_extras`); empty: any.
  final List<String> extras;

  /// Only listings in the person's favourite colours for their model
  /// (`listings.my_colour`); listings of unknown colour never match.
  final bool onlyMyColours;
  final bool activeOnly;

  /// How many filters differ from the defaults (shown on the filter button).
  int get appliedCount => [
    motorcycleIds.isNotEmpty,
    minYear != null,
    maxPrice != null,
    maxMileage != null,
    location != null,
    sellerType != null,
    minDealScore != null,
    maxRiskScore != null,
    maxDistanceKm != null,
    extras.isNotEmpty,
    onlyMyColours,
    !activeOnly,
  ].where((applied) => applied).length;

  @override
  List<Object?> get props => [
    motorcycleIds,
    minYear,
    maxPrice,
    maxMileage,
    location,
    sellerType,
    minDealScore,
    maxRiskScore,
    maxDistanceKm,
    extras,
    onlyMyColours,
    activeOnly,
  ];
}
