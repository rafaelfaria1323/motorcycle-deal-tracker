/// A listing as shown in an OLX search results page.
class const OlxRawListing({
  required final String id,
  required final String url,
  required final String status,
  required final String title,

  /// Null for trade-only or "price on request" ads.
  final num? price,
  required final String currency,

  /// The brand the search's category stands for ("yamaha" in
  /// `.../motociclos-scooters/yamaha`); null when the search has none.
  final String? categoryBrand,

  /// OLX's own model field ("MT-07"). It also covers related bikes (OLX
  /// files the Tracer 7 under MT-07), so the title decides.
  final String? model,
  final int? year,
  final int? mileageKm,
  final bool isBusiness = false,

  /// Only read for business sellers; private sellers' names are never read.
  final String? businessName,
  final String? location,

  /// Plain text.
  final String? description,

  /// Set when OLX shows a copy of another site's ad ("standvirtual").
  final String? partner,
  final String? externalUrl,
  final List<String> images = const [],

  /// When the ad was first published, and when the seller last renewed or
  /// promoted it (OLX shows and sorts by the latter).
  final DateTime? createdAt,
  final DateTime? refreshedAt,
});
