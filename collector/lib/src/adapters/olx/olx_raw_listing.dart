/// A listing as shown in an OLX search results page.
class OlxRawListing {
  const OlxRawListing({
    required this.id,
    required this.url,
    required this.status,
    required this.title,
    required this.price,
    required this.currency,
    this.categoryBrand,
    this.model,
    this.year,
    this.mileageKm,
    this.isBusiness = false,
    this.businessName,
    this.location,
    this.description,
    this.partner,
    this.externalUrl,
    this.images = const [],
  });

  final String id;
  final String url;
  final String status;
  final String title;
  final num price;
  final String currency;

  /// The brand the search's category stands for ("yamaha" in
  /// `.../motociclos-scooters/yamaha`); null when the search has none.
  final String? categoryBrand;

  /// OLX's own model field ("MT-07"). It also covers related bikes (OLX
  /// files the Tracer 7 under MT-07), so the title decides.
  final String? model;
  final int? year;
  final int? mileageKm;
  final bool isBusiness;

  /// Only read for business sellers; private sellers' names are never read.
  final String? businessName;
  final String? location;

  /// Plain text.
  final String? description;

  /// Set when OLX shows a copy of another site's ad ("standvirtual").
  final String? partner;
  final String? externalUrl;
  final List<String> images;
}
