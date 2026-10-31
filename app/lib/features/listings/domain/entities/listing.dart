import 'package:equatable/equatable.dart';

import 'photo_hint.dart';

enum ListingStatus { active, priceChanged, removed, sold, unknown }

enum SellerType { private, dealer, unknown }

class const Listing({
  required final String id,
  required final String source,
  required final String url,
  required final String brand,
  required final String model,
  required final ListingStatus status,
  required final SellerType sellerType,
  required final List<String> images,
  final String? motorcycleId,
  final String? duplicateOf,
  final int? riskScore,
  final int? year,
  final int? mileage,

  /// The ad's mileage field was empty and [mileage] was read from its
  /// description (`mileage_in_text`).
  final bool mileageFromText = false,
  final int? dealScore,
  final double? initialPrice,

  /// Highest earlier price the site reported, possibly from before we
  /// started tracking (Standvirtual's price-drop note).
  final double? priceBeforeDrop,
  final double? price,
  final Map<String, dynamic>? scoreBreakdown,
  final String? sellerName,
  final String? location,
  final String? description,
  final DateTime? firstSeenAt,
  final DateTime? lastSeenAt,
  final int? registrations,

  /// The existing `first_owner` scoring signal, including claims in the ad
  /// when no owner count is known. Lists load only the risk-reason codes.
  final bool hasFirstOwnerSignal = false,
  final bool? serviceBook,
  final String? origin,
  final DateTime? warrantyUntil,
  final int? dealerWarrantyMonths,
  final DateTime? publishedAt,

  /// When the site last renewed (bumped) the ad; OLX shows this date.
  final DateTime? siteRefreshedAt,

  /// The earlier ad of the same bike when it was taken down and listed
  /// again, when the bike first went on sale, and that ad's last price.
  final String? relistedFrom,
  final DateTime? relistedSince,
  final double? relistedPrice,

  /// Official new-bike list price of the matched model, and when it was last
  /// checked. Only loaded on the detail page.
  final double? newPrice,
  final DateTime? newPriceCheckedAt,

  /// Engine size of the matched model (the middle of its catalog range).
  /// Only loaded on the detail page.
  final int? engineCc,

  /// Straight-line km from the signed-in person's home (the computed field
  /// `distance_km`); null without a home or a known place.
  final int? distanceKm,

  /// The bike's colour as a code ('blue', `listings.colour`): the site's
  /// field, or read from the variant or description; null when unknown.
  final String? colour,

  /// The colour is one of the signed-in person's favourites (the computed
  /// field `my_colour`). A plus shown to them, never part of the Deal Score.
  final bool myColour = false,

  /// What the image model may have seen in the first photos, likeliest
  /// first. Only loaded on the detail page; hints, never a score.
  final List<PhotoHint> photoHints = const [],

  /// When someone asked for every photo to be examined (P.4); null once
  /// done or never asked. Only loaded on the detail page.
  final DateTime? photoExamRequestedAt,

  /// When every photo was shown to the image model (P.4); null: only the
  /// first ones. Only loaded on the detail page.
  final DateTime? photosExaminedAllAt,
}) extends Equatable {
  /// The price changes are measured from: the first price we saw, or a
  /// higher earlier price the site reported.
  double? get referencePrice {
    final initial = initialPrice;
    final before = priceBeforeDrop;
    if (before == null) return initial;
    if (initial == null || before > initial) return before;
    return initial;
  }

  /// Whether [referencePrice] comes from the site rather than from us.
  bool get referenceIsFromSite =>
      priceBeforeDrop != null &&
      referencePrice == priceBeforeDrop &&
      priceBeforeDrop != initialPrice;

  /// Current price minus [referencePrice]; null when either is unknown.
  double? get priceChange {
    final current = price;
    final reference = referencePrice;
    if (current == null || reference == null) return null;
    return current - reference;
  }

  bool get hasPriceChanged => (priceChange ?? 0).abs() >= 1;

  bool get isRemoved => status == .removed;

  /// Still on sale, as the database's live statuses.
  bool get isLive => status == .active || status == .priceChanged;

  @override
  List<Object?> get props => [
    id,
    price,
    initialPrice,
    priceBeforeDrop,
    dealScore,
    status,
    lastSeenAt,
  ];
}
