import 'package:equatable/equatable.dart';

import 'listing.dart';

/// A listing the user is considering, with their own note about it and
/// what they checked when they saw the bike.
class Favourite extends Equatable {
  const Favourite({
    required this.listingId,
    required this.createdAt,
    this.note,
    this.checklist = const {},
    this.targetPrice,
    this.listing,
  });

  final String listingId;
  final DateTime createdAt;

  /// Private to the user ("Liguei, ainda disponível"); null when empty.
  final String? note;

  /// The viewing checklist's marks by item key (`viewing_checklist.dart`);
  /// items not looked at yet are missing.
  final Map<String, ChecklistEntry> checklist;

  /// The price the user would pay: when the listing drops to it or below,
  /// an alert says so ("Chegou ao seu preço"). Null when not set.
  final double? targetPrice;

  /// The listing itself, when it was loaded with the favourite.
  final Listing? listing;

  Favourite withNote(String? note) => Favourite(
    listingId: listingId,
    createdAt: createdAt,
    note: note,
    checklist: checklist,
    targetPrice: targetPrice,
    listing: listing,
  );

  Favourite withChecklist(Map<String, ChecklistEntry> checklist) => Favourite(
    listingId: listingId,
    createdAt: createdAt,
    note: note,
    checklist: checklist,
    targetPrice: targetPrice,
    listing: listing,
  );

  Favourite withTargetPrice(double? targetPrice) => Favourite(
    listingId: listingId,
    createdAt: createdAt,
    note: note,
    checklist: checklist,
    targetPrice: targetPrice,
    listing: listing,
  );

  @override
  List<Object?> get props => [
    listingId,
    createdAt,
    note,
    checklist,
    targetPrice,
    listing,
  ];
}

enum ChecklistMark { ok, issue }

/// One item of the viewing checklist: looked at and fine, or a problem,
/// with an optional note ("DOT 2017").
class ChecklistEntry extends Equatable {
  const ChecklistEntry({this.mark, this.note});

  final ChecklistMark? mark;
  final String? note;

  /// Neither marked nor noted: the same as not there.
  bool get isEmpty => mark == null && note == null;

  @override
  List<Object?> get props => [mark, note];
}
