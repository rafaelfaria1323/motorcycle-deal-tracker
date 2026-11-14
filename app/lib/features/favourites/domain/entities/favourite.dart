import 'package:equatable/equatable.dart';

import '../../../listings/domain/entities/listing.dart';

/// A listing the user is considering, with their own note about it and
/// what they checked when they saw the bike.
class const Favourite({
  required final String listingId,
  required final DateTime createdAt,

  /// Private to the user ("Liguei, ainda disponível"); null when empty.
  final String? note,

  /// The viewing checklist's marks by item key (`viewing_checklist.dart`);
  /// items not looked at yet are missing.
  final Map<String, ChecklistEntry> checklist = const {},

  /// The price the user would pay: when the listing drops to it or below,
  /// an alert says so ("Chegou ao seu preço"). Null when not set.
  final double? targetPrice,

  /// When the user is going to see the bike (local time): the day before,
  /// a notification reminds them and points to the checklist (N.65). Null
  /// when no visit is planned.
  final DateTime? visitAt,

  /// The ad as it was when the user last opened it (N.97): what has
  /// changed since is told in Favoritos and on its page. Null when unknown.
  final FavouriteSeen? seen,

  /// The listing itself, when it was loaded with the favourite.
  final Listing? listing,
}) extends Equatable {
  Favourite withNote(String? note) => Favourite(
    listingId: listingId,
    createdAt: createdAt,
    note: note,
    checklist: checklist,
    targetPrice: targetPrice,
    visitAt: visitAt,
    seen: seen,
    listing: listing,
  );

  Favourite withChecklist(Map<String, ChecklistEntry> checklist) => Favourite(
    listingId: listingId,
    createdAt: createdAt,
    note: note,
    checklist: checklist,
    targetPrice: targetPrice,
    visitAt: visitAt,
    seen: seen,
    listing: listing,
  );

  Favourite withTargetPrice(double? targetPrice) => Favourite(
    listingId: listingId,
    createdAt: createdAt,
    note: note,
    checklist: checklist,
    targetPrice: targetPrice,
    visitAt: visitAt,
    seen: seen,
    listing: listing,
  );

  Favourite withSeen(FavouriteSeen? seen) => Favourite(
    listingId: listingId,
    createdAt: createdAt,
    note: note,
    checklist: checklist,
    targetPrice: targetPrice,
    visitAt: visitAt,
    seen: seen,
    listing: listing,
  );

  Favourite withVisit(DateTime? visitAt) => Favourite(
    listingId: listingId,
    createdAt: createdAt,
    note: note,
    checklist: checklist,
    targetPrice: targetPrice,
    visitAt: visitAt,
    seen: seen,
    listing: listing,
  );

  @override
  List<Object?> get props => [
    listingId,
    createdAt,
    note,
    checklist,
    targetPrice,
    visitAt,
    seen,
    listing,
  ];
}

/// How a favourite's ad was when its owner last opened it (N.97), kept by
/// the database from the listing.
class const FavouriteSeen({
  required final DateTime at,
  final double? price,
  final int? mileage,
  final ListingStatus? status,
}) extends Equatable {
  /// [listing] as it is now, seen [at].
  factory FavouriteSeen.of(Listing listing, DateTime at) => FavouriteSeen(
    at: at,
    price: listing.price,
    mileage: listing.mileage,
    status: listing.status,
  );

  @override
  List<Object?> get props => [at, price, mileage, status];
}

enum ChecklistMark { ok, issue }

/// One item of the viewing checklist: looked at and fine, or a problem,
/// with an optional note ("DOT 2017").
class const ChecklistEntry({final ChecklistMark? mark, final String? note})
    extends Equatable {
  /// Neither marked nor noted: the same as not there.
  bool get isEmpty => mark == null && note == null;

  @override
  List<Object?> get props => [mark, note];
}
