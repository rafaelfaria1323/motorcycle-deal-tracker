import '../../catalog/catalog.dart';
import '../../normalized/normalized_listing.dart';
import '../../normalized/normalizers.dart';
import 'manual_adapter.dart';
import 'manual_raw_listing.dart';

/// Maps manual import records to the normalized listing.
class ManualMapper(final Catalog catalog, {int? currentYear}) {
  final int currentYear = currentYear ?? DateTime.now().year;

  static const _oldestYear = 1980;
  static const _maxMileageKm = 500000;

  MapOutcome map(ManualRawListing raw, {bool matchCatalog = true}) {
    final warnings = <String>[];

    final price = raw.priceEur.toDouble();
    if (price <= 0) return const Rejected('"price_eur" must be greater than 0');

    final year = raw.year;
    if (year != null && (year < _oldestYear || year > currentYear + 1)) {
      return Rejected('year $year is out of range');
    }

    final mileage = raw.mileageKm;
    if (mileage != null && (mileage < 0 || mileage > _maxMileageKm)) {
      return Rejected('mileage $mileage km is out of range');
    }

    // Exact catalog match only: a near miss such as "MT-07 Tracer" is a
    // different bike, and a wrong match would distort the market prices.
    final entry = matchCatalog ? catalog.find(raw.brand, raw.model) : null;
    if (entry == null) {
      final near = catalog.nearMiss(raw.brand, raw.model);
      warnings.add(
        near == null
            ? '"${raw.brand} ${raw.model}" is not a followed model, '
                  'so it gets no market price'
            : '"${raw.brand} ${raw.model}" is not a followed model; if it is a '
                  'variant of ${near.model}, put the extra text in "variant"',
      );
    } else if (year != null && year < entry.minYear) {
      return Rejected(
        'year $year is below the tracked range '
        '(${entry.minYear}+ for ${entry.brand} ${entry.model})',
      );
    }

    var sellerType = SellerType.unknown;
    final rawSeller = raw.sellerType;
    if (rawSeller != null) {
      final parsed = parseSellerType(rawSeller);
      if (parsed == null) {
        warnings.add('unknown seller_type "$rawSeller"');
      } else {
        sellerType = parsed;
      }
    }

    // Data minimization: only business names are kept, never private sellers'.
    final sellerName = sellerType == .dealer ? raw.sellerName : null;
    if (raw.sellerName != null && sellerName == null) {
      warnings.add('seller_name dropped (kept only for dealers)');
    }

    final images = cleanImages(raw.images);
    if (images.length != raw.images.length) {
      warnings.add(
        '${raw.images.length - images.length} image link(s) dropped '
        '(invalid or duplicated)',
      );
    }

    return Mapped(
      NormalizedListing(
        source: ManualAdapter.sourceId,
        sourceListingId: canonicalListingId(raw.url),
        url: raw.url,
        motorcycleSlug: entry?.slug,
        brand: entry?.brand ?? raw.brand,
        model: entry?.model ?? raw.model,
        variant: raw.variant,
        year: year,
        mileage: mileage,
        price: double.parse(price.toStringAsFixed(2)),
        sellerType: sellerType,
        sellerName: sellerName,
        location: raw.location,
        description: raw.description,
        images: images,
      ),
      warnings,
    );
  }
}
