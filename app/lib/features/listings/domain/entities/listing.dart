import 'package:equatable/equatable.dart';

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
    this.serviceBook,
    this.origin,
    this.warrantyUntil,
    this.dealerWarrantyMonths,
    this.publishedAt,
    this.siteRefreshedAt,
    this.newPrice,
    this.newPriceCheckedAt,
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
  final bool? serviceBook;
  final String? origin;
  final DateTime? warrantyUntil;
  final int? dealerWarrantyMonths;
  final DateTime? publishedAt;

  /// When the site last renewed (bumped) the ad; OLX shows this date.
  final DateTime? siteRefreshedAt;

  /// Official new-bike list price of the matched model, and when it was last
  /// checked. Only loaded on the detail page.
  final double? newPrice;
  final DateTime? newPriceCheckedAt;

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
