import 'package:equatable/equatable.dart';

import 'listing.dart';

class const ListingFilters({
  /// The models asked for (catalog ids); empty: any model.
  final List<String> motorcycleIds = const [],
  final int? minYear,
  final int? maxYear,

  /// Placeholder prices under 300 € never match a set price criterion.
  final double? minPrice,
  final double? maxPrice,
  final int? maxMileage,

  /// One of `portugueseDistricts`; listings whose place is unknown never
  /// match (`listings.district`).
  final String? district,
  final SellerType? sellerType,

  /// Listings without a score never match a set score criterion.
  final int? minDealScore,
  final int? maxRiskScore,

  /// Km from the person's home; listings whose place is unknown never match.
  final int? maxDistanceKm,

  /// Equipment codes the ad must all mention (`listing_extras`); empty: any.
  final List<String> extras = const [],

  /// Only listings in the person's favourite colours for their model
  /// (`listings.my_colour`); listings of unknown colour never match.
  final bool onlyMyColours = false,
  final bool activeOnly = true,
}) extends Equatable {
  static const empty = ListingFilters();

  /// How many filters differ from the defaults (shown on the filter button).
  int get appliedCount => [
    motorcycleIds.isNotEmpty,
    minYear != null,
    maxYear != null,
    minPrice != null,
    maxPrice != null,
    maxMileage != null,
    district != null,
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
    maxYear,
    minPrice,
    maxPrice,
    maxMileage,
    district,
    sellerType,
    minDealScore,
    maxRiskScore,
    maxDistanceKm,
    extras,
    onlyMyColours,
    activeOnly,
  ];
}
