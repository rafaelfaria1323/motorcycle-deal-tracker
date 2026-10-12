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
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.motorcycleId,
    this.year,
    this.mileage,
    this.price,
    this.sellerName,
    this.location,
    this.description,
  });

  final String id;
  final String source;
  final String url;
  final String brand;
  final String model;
  final String? motorcycleId;
  final int? year;
  final int? mileage;
  final double? price;
  final SellerType sellerType;
  final String? sellerName;
  final String? location;
  final String? description;
  final List<String> images;
  final ListingStatus status;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  @override
  List<Object?> get props => [id, price, status, lastSeenAt];
}