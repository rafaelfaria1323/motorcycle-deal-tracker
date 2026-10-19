import 'package:equatable/equatable.dart';

/// An ad from a site the collector does not read, as the owner saves it.
class SharedListingDraft extends Equatable {
  const SharedListingDraft({
    required this.source,
    required this.sourceListingId,
    required this.url,
    required this.motorcycleId,
    required this.price,
    this.year,
    this.mileage,
    this.location,
    this.sellerType = 'unknown',
    this.description,
    this.images = const [],
  });

  /// 'facebook', 'custojusto' or 'other'.
  final String source;
  final String sourceListingId;
  final String url;
  final String motorcycleId;
  final double price;
  final int? year;
  final int? mileage;
  final String? location;

  /// 'private', 'dealer' or 'unknown'.
  final String sellerType;
  final String? description;
  final List<String> images;

  @override
  List<Object?> get props => [
    source,
    sourceListingId,
    url,
    motorcycleId,
    price,
    year,
    mileage,
    location,
    sellerType,
    description,
    images,
  ];
}
