import 'package:equatable/equatable.dart';

import 'listing.dart';

/// What the A2 licence filter asks for (`listings.a2`): [ready] for a bike
/// of 35 kW or less, or an ad that says it is an A2 version; [restrictable]
/// also takes a bike of 70 kW or less, which can be limited to 35 kW.
enum A2Fit { ready, restrictable }

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

  /// Only bikes for an A2 licence (`listings.a2`); a model of unknown
  /// power matches only through an ad that says it is an A2 version.
  final A2Fit? a2,
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
    a2 != null,
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
    a2,
    activeOnly,
  ];
}
