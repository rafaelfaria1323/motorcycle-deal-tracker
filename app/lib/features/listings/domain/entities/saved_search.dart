import 'package:equatable/equatable.dart';

import 'listing_filters.dart';

class const SavedSearch({
  required final String id,
  required final ListingFilters filters,
  required final DateTime createdAt,
  final String? name,
  final bool notifyNewListing = true,
  final bool notifyPriceReduction = true,
  final bool notifyExcellentDeal = false,
  final bool notifyListingRemoved = false,
}) extends Equatable {
  /// A search not saved yet, for the "Nova pesquisa" sheet.
  factory SavedSearch.draft() => SavedSearch(
    id: '',
    filters: ListingFilters.empty,
    createdAt: DateTime.now(),
  );

  // Used by alerts in Sprint 8.

  bool get isDraft => id.isEmpty;

  SavedSearch copyWith({
    String? name,
    ListingFilters? filters,
    bool? notifyNewListing,
    bool? notifyPriceReduction,
    bool? notifyExcellentDeal,
    bool? notifyListingRemoved,
  }) {
    return SavedSearch(
      id: id,
      name: name ?? this.name,
      filters: filters ?? this.filters,
      createdAt: createdAt,
      notifyNewListing: notifyNewListing ?? this.notifyNewListing,
      notifyPriceReduction: notifyPriceReduction ?? this.notifyPriceReduction,
      notifyExcellentDeal: notifyExcellentDeal ?? this.notifyExcellentDeal,
      notifyListingRemoved: notifyListingRemoved ?? this.notifyListingRemoved,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    filters,
    createdAt,
    notifyNewListing,
    notifyPriceReduction,
    notifyExcellentDeal,
    notifyListingRemoved,
  ];
}

extension ListingFiltersCriteria on ListingFilters {
  /// True when at least one search criterion is set. "Only live listings" is
  /// not a criterion: a saved search always looks at live listings.
  bool get hasCriteria =>
      motorcycleIds.isNotEmpty ||
      minYear != null ||
      maxPrice != null ||
      maxMileage != null ||
      location != null ||
      sellerType != null ||
      minDealScore != null ||
      maxRiskScore != null ||
      maxDistanceKm != null ||
      extras.isNotEmpty ||
      onlyMyColours;

  /// The same criteria without the live-only switch, which is not saved.
  ListingFilters get criteriaOnly => ListingFilters(
    motorcycleIds: motorcycleIds,
    minYear: minYear,
    maxPrice: maxPrice,
    maxMileage: maxMileage,
    location: location,
    sellerType: sellerType,
    minDealScore: minDealScore,
    maxRiskScore: maxRiskScore,
    maxDistanceKm: maxDistanceKm,
    extras: extras,
    onlyMyColours: onlyMyColours,
  );
}

extension SameCriteria on ListingFilters {
  /// True when both ask for the same thing: the live-only switch is left
  /// out (it is not saved) and the order of models and extras doesn't count.
  bool sameCriteriaAs(ListingFilters other) =>
      _sorted(criteriaOnly) == _sorted(other.criteriaOnly);
}

ListingFilters _sorted(ListingFilters f) => ListingFilters(
  motorcycleIds: [...f.motorcycleIds]..sort(),
  minYear: f.minYear,
  maxPrice: f.maxPrice,
  maxMileage: f.maxMileage,
  location: f.location,
  sellerType: f.sellerType,
  minDealScore: f.minDealScore,
  maxRiskScore: f.maxRiskScore,
  maxDistanceKm: f.maxDistanceKm,
  extras: [...f.extras]..sort(),
  onlyMyColours: f.onlyMyColours,
);

/// The saved search asking for the same as [filters], other than the one
/// with id [except] (the search being edited); null when there is none.
SavedSearch? savedSearchLike(
  Iterable<SavedSearch> searches,
  ListingFilters filters, {
  String? except,
}) {
  for (final search in searches) {
    if (search.id != except && search.filters.sameCriteriaAs(filters)) {
      return search;
    }
  }
  return null;
}
