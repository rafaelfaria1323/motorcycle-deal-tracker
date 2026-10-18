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
    this.price,
    this.scoreBreakdown,
    this.sellerName,
    this.location,
    this.description,
    this.firstSeenAt,
    this.lastSeenAt,
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

  /// Current price minus the first price we saw; null when either is unknown.
  double? get priceChange {
    final current = price;
    final initial = initialPrice;
    if (current == null || initial == null) return null;
    return current - initial;
  }

  bool get hasPriceChanged => (priceChange ?? 0).abs() >= 1;

  bool get isRemoved => status == ListingStatus.removed;

  @override
  List<Object?> get props => [
    id,
    price,
    initialPrice,
    dealScore,
    status,
    lastSeenAt,
  ];
}
