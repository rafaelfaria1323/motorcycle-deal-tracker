import '../../catalog/catalog.dart';
import '../../catalog/model_resolver.dart';
import '../../normalized/normalized_listing.dart';
import '../manual/manual_mapper.dart';
import '../manual/manual_raw_listing.dart';
import 'standvirtual_raw_listing.dart';

class StandvirtualMapper {
  StandvirtualMapper(this.catalog, {int? currentYear})
    : _base = ManualMapper(catalog, currentYear: currentYear),
      _models = ModelResolver(catalog);

  final Catalog catalog;
  final ManualMapper _base;
  final ModelResolver _models;

  /// The id a Standvirtual ad is stored under.
  static String listingId(String adId) => 'standvirtual.com/$adId';

  MapOutcome map(StandvirtualRawListing raw) {
    if (raw.status != 'ACTIVE') {
      return Rejected('listing is not active (${raw.status})');
    }
    if (raw.currency != 'EUR') {
      return Rejected('price is in ${raw.currency}, not EUR');
    }

    final entry = _models.resolve(
      brand: raw.brand,
      family: raw.model,
      text: '${raw.model} ${raw.version ?? ''}',
      engineCc: raw.engineCc,
    );

    // Unresolved: keep the source's full text, without letting the base
    // mapper's exact lookup undo the resolver's decision.
    final model =
        entry?.model ?? [raw.model, raw.version].whereType<String>().join(' ');

    final outcome = _base.map(
      ManualRawListing(
        url: raw.url,
        brand: raw.brand,
        model: model,
        variant: entry != null ? raw.version : null,
        priceEur: raw.price,
        year: raw.year,
        mileageKm: raw.mileageKm,
        sellerType: raw.sellerType,
        sellerName: raw.sellerName,
        location: raw.location,
        description: raw.description,
        images: raw.images,
      ),
      matchCatalog: entry != null,
    );

    return switch (outcome) {
      Mapped(:final listing, :final warnings) => Mapped(
        listing.fromSite(
          source: 'standvirtual',
          // The numeric ad id survives the title being edited.
          sourceListingId: listingId(raw.id),
          priceBeforeDrop: raw.priceBeforeDrop?.toDouble(),
          publishedAt: raw.createdAt,
          siteRefreshedAt: raw.bumpedAt,
        ),
        warnings,
      ),
      Rejected() => outcome,
    };
  }
}
