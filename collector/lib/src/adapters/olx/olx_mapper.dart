import '../../catalog/catalog.dart';
import '../../catalog/model_resolver.dart';
import '../../normalized/normalized_listing.dart';
import '../manual/manual_mapper.dart';
import '../manual/manual_raw_listing.dart';
import 'olx_raw_listing.dart';

class OlxMapper {
  OlxMapper(this.catalog, {int? currentYear})
    : _base = ManualMapper(catalog, currentYear: currentYear),
      _models = ModelResolver(catalog);

  final Catalog catalog;
  final ManualMapper _base;
  final ModelResolver _models;

  /// The id an OLX ad is stored under.
  static String listingId(String adId) => 'olx.pt/$adId';

  MapOutcome map(OlxRawListing raw) {
    if (raw.status != 'active') {
      return Rejected('listing is not active (${raw.status})');
    }
    // Standvirtual dealers' ads are copied to OLX automatically; the
    // original is collected from Standvirtual with more detail.
    if (raw.partner == 'standvirtual') {
      return Rejected('copy of a Standvirtual ad (${raw.externalUrl ?? '?'})');
    }
    if (raw.currency != 'EUR') {
      return Rejected('price is in ${raw.currency}, not EUR');
    }

    final brand = _brand(raw);
    final family = raw.model ?? '';
    final entry = _models.resolve(
      brand: brand,
      family: family,
      text: '$family ${raw.title}',
    );

    // Unresolved: keep the title, so the base mapper cannot match the
    // site's model field ("MT-07" for a Tracer 7) by accident.
    final model = entry?.model ?? raw.title;

    final outcome = _base.map(
      ManualRawListing(
        url: raw.url,
        brand: brand,
        model: model,
        priceEur: raw.price,
        year: raw.year,
        mileageKm: raw.mileageKm,
        sellerType: raw.isBusiness ? 'dealer' : 'private',
        sellerName: raw.businessName,
        location: raw.location,
        description: raw.description,
        images: raw.images,
      ),
    );

    return switch (outcome) {
      Mapped(:final listing, :final warnings) => Mapped(
        NormalizedListing(
          source: 'olx',
          // The numeric ad id survives the title being edited.
          sourceListingId: listingId(raw.id),
          url: listing.url,
          motorcycleSlug: listing.motorcycleSlug,
          brand: listing.brand,
          model: listing.model,
          year: listing.year,
          mileage: listing.mileage,
          price: listing.price,
          sellerType: listing.sellerType,
          sellerName: listing.sellerName,
          location: listing.location,
          description: listing.description,
          images: listing.images,
        ),
        warnings,
      ),
      Rejected() => outcome,
    };
  }

  /// The catalog brand named by the search's category or the title,
  /// otherwise the category or the title's first word as written.
  String _brand(OlxRawListing raw) {
    final category = normalizeKey(raw.categoryBrand ?? '');
    final words = {
      for (final w in raw.title.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
        if (w.isNotEmpty) w,
    };
    for (final e in catalog.entries) {
      final key = normalizeKey(e.brand);
      if (key == category || words.contains(key)) return e.brand;
    }
    final fallback = raw.categoryBrand ?? raw.title.split(' ').first;
    return fallback.isEmpty
        ? fallback
        : fallback[0].toUpperCase() + fallback.substring(1);
  }
}
