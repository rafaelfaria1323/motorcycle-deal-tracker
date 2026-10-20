import 'package:equatable/equatable.dart';

import 'listing.dart';

/// A listing the user is considering, with their own note about it.
class Favourite extends Equatable {
  const Favourite({
    required this.listingId,
    required this.createdAt,
    this.note,
    this.listing,
  });

  final String listingId;
  final DateTime createdAt;

  /// Private to the user ("Liguei, ainda disponível"); null when empty.
  final String? note;

  /// The listing itself, when it was loaded with the favourite.
  final Listing? listing;

  Favourite withNote(String? note) => Favourite(
    listingId: listingId,
    createdAt: createdAt,
    note: note,
    listing: listing,
  );

  @override
  List<Object?> get props => [listingId, createdAt, note, listing];
}
