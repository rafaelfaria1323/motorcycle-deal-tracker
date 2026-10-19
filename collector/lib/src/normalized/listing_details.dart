/// What a listing page adds to a listing already stored from a search.
class ListingDetails {
  const ListingDetails({
    required this.sourceListingId,
    this.description,
    this.registrations,
    this.serviceBook,
    this.origin,
    this.warrantyUntil,
    this.dealerWarrantyMonths,
    this.publishedAt,
  });

  final String sourceListingId;
  final String? description;

  /// How many owners have registered it (1 = first owner).
  final int? registrations;
  final bool? serviceBook;

  /// As the source says it, e.g. 'national'.
  final String? origin;

  /// Manufacturer warranty end, `yyyy-mm-dd`.
  final String? warrantyUntil;
  final int? dealerWarrantyMonths;

  /// First publication (not the date of the last paid "bump").
  final String? publishedAt;

  Map<String, dynamic> toJson() => {
    'source_listing_id': sourceListingId,
    'description': description,
    'registrations': registrations,
    'service_book': serviceBook,
    'origin': origin,
    'warranty_until': warrantyUntil,
    'dealer_warranty_months': dealerWarrantyMonths,
    'published_at': publishedAt,
  };
}
