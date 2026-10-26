import 'package:equatable/equatable.dart';

import 'listing.dart';

enum AlertType {
  newListing,
  priceReduction,
  excellentOpportunity,
  listingRemoved,

  /// A followed bike (favourite or alerted by a saved search) is on sale
  /// again in a new ad.
  backOnMarket,

  /// A favourite is on sale at the user's target price or less.
  targetPriceReached,
  unknown,
}

/// A notification for the current user about one listing.
class ListingAlert extends Equatable {
  const ListingAlert({
    required this.id,
    required this.type,
    required this.listing,
    required this.createdAt,
    this.searchId,
    this.searchName,
    this.oldPrice,
    this.newPrice,
    this.readAt,
  });

  final String id;
  final AlertType type;
  final Listing listing;
  final DateTime createdAt;

  /// The originating search; null for favourites or a deleted search.
  final String? searchId;
  final String? searchName;
  final double? oldPrice;
  final double? newPrice;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  ListingAlert copyWith({DateTime? readAt, bool clearReadAt = false}) {
    return ListingAlert(
      id: id,
      type: type,
      listing: listing,
      createdAt: createdAt,
      searchId: searchId,
      searchName: searchName,
      oldPrice: oldPrice,
      newPrice: newPrice,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    listing,
    createdAt,
    searchId,
    searchName,
    readAt,
  ];
}
