enum SellerType { private, dealer, unknown }

/// A listing in the shape of the `listings` table, whatever source it came from.
class const NormalizedListing({
  required final String source,
  required final String sourceListingId,
  required final String url,
  required final String brand,
  required final String model,
  required final double price,
  required final SellerType sellerType,
  required final List<String> images,

  /// Catalog model this listing belongs to; null when it is not in the catalog.
  final String? motorcycleSlug,
  final String? variant,
  final int? year,
  final int? mileage,
  final String? sellerName,
  final String? location,
  final String? description,

  /// What the source says the price was before its last cut; may predate
  /// our tracking. Null when the source shows no cut or doesn't say.
  final double? priceBeforeDrop,

  /// When the source says the ad was first published, and when it was last
  /// renewed there; null when the source doesn't say.
  final DateTime? publishedAt,
  final DateTime? siteRefreshedAt,
}) {
  /// The same listing as told by a site: its own source and id, and what
  /// only the site knows (an earlier price, the ad's dates). Every other
  /// field is kept, so a new field can't be dropped by one mapper.
  NormalizedListing fromSite({
    required String source,
    required String sourceListingId,
    double? priceBeforeDrop,
    DateTime? publishedAt,
    DateTime? siteRefreshedAt,
  }) => NormalizedListing(
    source: source,
    sourceListingId: sourceListingId,
    url: url,
    motorcycleSlug: motorcycleSlug,
    brand: brand,
    model: model,
    variant: variant,
    year: year,
    mileage: mileage,
    price: price,
    priceBeforeDrop: priceBeforeDrop,
    sellerType: sellerType,
    sellerName: sellerName,
    location: location,
    description: description,
    images: images,
    publishedAt: publishedAt,
    siteRefreshedAt: siteRefreshedAt,
  );
}

/// Result of mapping one raw record.
sealed class const MapOutcome();

/// The record is usable. Warnings are things worth a look, not blockers.
class const Mapped(
  final NormalizedListing listing, [
  final List<String> warnings = const [],
]) extends MapOutcome;

/// The record is not usable and will not be stored.
class const Rejected(final String reason) extends MapOutcome;
