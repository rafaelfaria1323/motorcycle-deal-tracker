import 'package:equatable/equatable.dart';

import 'photo_hint.dart';

enum ListingStatus { active, priceChanged, removed, sold, unknown }

enum SellerType { private, dealer, unknown }

class Listing extends Equatable {
  const Listing({
    required this.id,
    required this.source,
    required this.url,
    required this.brand,
    required this.model,
    required this.status,
    required this.sellerType,
    required this.images,
    this.motorcycleId,
    this.duplicateOf,
    this.riskScore,
    this.year,
    this.mileage,
    this.mileageFromText = false,
    this.dealScore,
    this.initialPrice,
    this.priceBeforeDrop,
    this.price,
    this.scoreBreakdown,
    this.sellerName,
    this.location,
    this.description,
    this.firstSeenAt,
    this.lastSeenAt,
    this.registrations,
    this.hasFirstOwnerSignal = false,
    this.serviceBook,
    this.origin,
    this.warrantyUntil,
    this.dealerWarrantyMonths,
    this.publishedAt,
    this.siteRefreshedAt,
    this.relistedFrom,
    this.relistedSince,
    this.relistedPrice,
    this.newPrice,
    this.newPriceCheckedAt,
    this.engineCc,
    this.distanceKm,
    this.colour,
    this.myColour = false,
    this.photoHints = const [],
  });

  final String id;
  final String source;
  final String url;
  final String brand;
  final String model;
  final String? motorcycleId;
  final String? duplicateOf;
  final int? riskScore;
  final int? year;
  final int? mileage;

  /// The ad's mileage field was empty and [mileage] was read from its
  /// description (`mileage_in_text`).
  final bool mileageFromText;
  final int? dealScore;
  final double? initialPrice;

  /// Highest earlier price the site reported, possibly from before we
  /// started tracking (Standvirtual's price-drop note).
  final double? priceBeforeDrop;
  final double? price;
  final Map<String, dynamic>? scoreBreakdown;
  final SellerType sellerType;
  final String? sellerName;
  final String? location;
  final String? description;
  final List<String> images;
  final ListingStatus status;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final int? registrations;

  /// The existing `first_owner` scoring signal, including claims in the ad
  /// when no owner count is known. Lists load only the risk-reason codes.
  final bool hasFirstOwnerSignal;
  final bool? serviceBook;
  final String? origin;
  final DateTime? warrantyUntil;
  final int? dealerWarrantyMonths;
  final DateTime? publishedAt;

  /// When the site last renewed (bumped) the ad; OLX shows this date.
  final DateTime? siteRefreshedAt;

  /// The earlier ad of the same bike when it was taken down and listed
  /// again, when the bike first went on sale, and that ad's last price.
  final String? relistedFrom;
  final DateTime? relistedSince;
  final double? relistedPrice;

  /// Official new-bike list price of the matched model, and when it was last
  /// checked. Only loaded on the detail page.
  final double? newPrice;
  final DateTime? newPriceCheckedAt;

  /// Engine size of the matched model (the middle of its catalog range).
  /// Only loaded on the detail page.
  final int? engineCc;

  /// Straight-line km from the signed-in person's home (the computed field
  /// `distance_km`); null without a home or a known place.
  final int? distanceKm;

  /// The bike's colour as a code ('blue', `listings.colour`): the site's
  /// field, or read from the variant or description; null when unknown.
  final String? colour;

  /// The colour is one of the signed-in person's favourites (the computed
  /// field `my_colour`). A plus shown to them, never part of the Deal Score.
  final bool myColour;

  /// What the image model may have seen in the first photos, likeliest
  /// first. Only loaded on the detail page; hints, never a score.
  final List<PhotoHint> photoHints;

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

  bool get isRemoved => status == ListingStatus.removed;

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
