/// A listing as read from a saved Standvirtual page.
class StandvirtualRawListing {
  const StandvirtualRawListing({
    required this.id,
    required this.url,
    required this.status,
    required this.brand,
    required this.model,
    required this.price,
    required this.currency,
    this.year,
    this.mileageKm,
    this.engineCc,
    this.sellerType,
    this.sellerName,
    this.location,
    this.description,
    this.version,
    this.images = const [],
  });

  final String id;
  final String url;
  final String status;
  final String brand;
  final String model;
  final num price;
  final String currency;
  final int? year;
  final int? mileageKm;
  final int? engineCc;

  /// 'dealer' or 'private' when known.
  final String? sellerType;
  final String? sellerName;
  final String? location;
  final String? description;
  final String? version;
  final List<String> images;
}
