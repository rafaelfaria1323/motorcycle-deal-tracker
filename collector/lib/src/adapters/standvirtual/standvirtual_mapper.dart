import '../../catalog/catalog.dart';
import '../../normalized/normalized_listing.dart';
import '../manual/manual_mapper.dart';
import '../manual/manual_raw_listing.dart';
import 'standvirtual_raw_listing.dart';

class StandvirtualMapper {
  StandvirtualMapper(this.catalog, {int? currentYear}) : _base = ManualMapper(catalog, currentYear: currentYear);

  final Catalog catalog;
  final ManualMapper _base;

  /// Words that make a listing a different bike than the catalog model it
  /// otherwise looks like (an MT-07 Tracer is not an MT-07).
  static const _otherBikePrefixes = ['tracer'];

  MapOutcome map(StandvirtualRawListing raw) {
    if (raw.status != 'ACTIVE') {
      return Rejected('listing is not active (${raw.status})');
    }
    if (raw.currency != 'EUR') {
      return Rejected('price is in ${raw.currency}, not EUR');
    }

    final entry = _resolve(raw);

    // Unresolved: keep the full text, so the base mapper cannot match the
    // bare family name ("R", "CB") or the base of a variant by accident.
    final model = entry?.model ?? [raw.model, raw.version].whereType<String>().join(' ');

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
    );

    return switch (outcome) {
      Mapped(:final listing, :final warnings) => Mapped(
        NormalizedListing(
          source: 'standvirtual',
          // The numeric ad id survives the title being edited.
          sourceListingId: 'standvirtual.com/${raw.id}',
          url: listing.url,
          motorcycleSlug: listing.motorcycleSlug,
          brand: listing.brand,
          model: listing.model,
          variant: listing.variant,
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

  /// The catalog model named by the model + version text, or null when none
  /// or more than one is.
  CatalogEntry? _resolve(StandvirtualRawListing raw) {
    final tokens = _tokens('${raw.model} ${raw.version ?? ''}');
    if (tokens.any((t) => _otherBikePrefixes.any(t.startsWith))) {
      return null;
    }

    final brand = normalizeKey(raw.brand);
    CatalogEntry? found;
    for (final entry in catalog.entries) {
      if (normalizeKey(entry.brand) != brand) continue;
      if (_hasModel(tokens, normalizeKey(entry.model))) {
        if (found != null) return null; // ambiguous
        found = entry;
      }
    }
    return found;
  }
}

List<String> _tokens(String text) =>
    text.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();

/// True when [key] ("cbr650r") is spelled by up to four consecutive words
/// starting in the first three ("cbr" "650r", "cbr650r", "cbr" "650" "r").
bool _hasModel(List<String> tokens, String key) {
  for (var start = 0; start < tokens.length && start <= 2; start++) {
    var joined = '';
    for (var end = start; end < tokens.length && end < start + 4; end++) {
      joined += tokens[end];
      if (joined == key) return true;
      if (joined.length >= key.length) break;
    }
  }
  return false;
}
