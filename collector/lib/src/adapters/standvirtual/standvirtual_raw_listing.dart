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
    this.priceBeforeDrop,
    this.images = const [],
    this.createdAt,
    this.bumpedAt,
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

  /// Lowest price in the 30 days before the site's last price cut, as the
  /// site reports it; null when it shows no cut.
  final num? priceBeforeDrop;
  final List<String> images;

  /// When the ad was published, from search results (listing pages give
  /// it through `ListingDetails`).
  final DateTime? createdAt;

  /// When the seller last pushed the ad back to the top of the results.
  final DateTime? bumpedAt;
}

/// Reads Standvirtual's `priceDrop` (`{percentage, lowestPrice: {minorAmount,
/// currencyCode}}`). Only a euro price above [price] counts.
num? priceBeforeDrop(Object? priceDrop, num price) {
  if (priceDrop is! Map) return null;
  final lowest = priceDrop['lowestPrice'];
  if (lowest is! Map || lowest['currencyCode'] != 'EUR') return null;
  final minor = lowest['minorAmount'];
  if (minor is! num) return null;
  final before = minor / 100;
  return before > price ? before : null;
}
