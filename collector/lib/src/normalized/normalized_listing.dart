enum SellerType { private, dealer, unknown }

/// A listing in the shape of the `listings` table, whatever source it came from.
class NormalizedListing {
  const NormalizedListing({
    required this.source,
    required this.sourceListingId,
    required this.url,
    required this.brand,
    required this.model,
    required this.price,
    required this.sellerType,
    required this.images,
    this.motorcycleSlug,
    this.variant,
    this.year,
    this.mileage,
    this.sellerName,
    this.location,
    this.description,
    this.priceBeforeDrop,
    this.publishedAt,
    this.siteRefreshedAt,
  });

  final String source;
  final String sourceListingId;
  final String url;

  /// Catalog model this listing belongs to; null when it is not in the catalog.
  final String? motorcycleSlug;
  final String brand;
  final String model;
  final String? variant;
  final int? year;
  final int? mileage;
  final double price;

  /// What the source says the price was before its last cut; may predate
  /// our tracking. Null when the source shows no cut or doesn't say.
  final double? priceBeforeDrop;
  final SellerType sellerType;
  final String? sellerName;
  final String? location;
  final String? description;
  final List<String> images;

  /// When the source says the ad was first published, and when it was last
  /// renewed there; null when the source doesn't say.
  final DateTime? publishedAt;
  final DateTime? siteRefreshedAt;
}

/// Result of mapping one raw record.
sealed class MapOutcome {
  const MapOutcome();
}

/// The record is usable. Warnings are things worth a look, not blockers.
class Mapped extends MapOutcome {
  const Mapped(this.listing, [this.warnings = const []]);

  final NormalizedListing listing;
  final List<String> warnings;
}

/// The record is not usable and will not be stored.
class Rejected extends MapOutcome {
  const Rejected(this.reason);

  final String reason;
}
