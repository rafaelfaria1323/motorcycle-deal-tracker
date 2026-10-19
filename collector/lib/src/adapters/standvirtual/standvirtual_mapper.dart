import '../../catalog/catalog.dart';
import '../../normalized/normalized_listing.dart';
import '../manual/manual_mapper.dart';
import '../manual/manual_raw_listing.dart';
import 'standvirtual_raw_listing.dart';

class StandvirtualMapper {
  StandvirtualMapper(this.catalog, {int? currentYear})
    : _base = ManualMapper(catalog, currentYear: currentYear);

  final Catalog catalog;
  final ManualMapper _base;

  /// Text that makes a listing a different bike than the catalog model it
  /// otherwise looks like (searched in the letters and digits of the text):
  /// an MT-07 Tracer and a CB650F are not an MT-07 and a CB650R.
  static const _notTheseBikes = ['tracer', '650f'];

  /// Honda's ABS and E-Clutch codes: CB650RA, CB650RAC are still a CB650R.
  static const _codeSuffixes = ['', 'a', 'ac'];

  /// Engine sizes (cc) sellers state for each catalog model.
  static const _displacement = <String, (int, int)>{
    'yamaha-mt-07': (680, 710),
    'yamaha-r7': (680, 710),
    'honda-cb650r': (640, 660),
    'honda-cbr650r': (640, 660),
  };

  /// The id a Standvirtual ad is stored under.
  static String listingId(String adId) => 'standvirtual.com/$adId';

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
    );

    return switch (outcome) {
      Mapped(:final listing, :final warnings) => Mapped(
        NormalizedListing(
          source: 'standvirtual',
          // The numeric ad id survives the title being edited.
          sourceListingId: listingId(raw.id),
          url: listing.url,
          motorcycleSlug: listing.motorcycleSlug,
          brand: listing.brand,
          model: listing.model,
          variant: listing.variant,
          year: listing.year,
          mileage: listing.mileage,
          price: listing.price,
          priceBeforeDrop: raw.priceBeforeDrop?.toDouble(),
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

  /// The catalog model this listing is, or null when it is not clearly one.
  CatalogEntry? _resolve(StandvirtualRawListing raw) {
    final text = normalizeKey('${raw.model} ${raw.version ?? ''}');
    if (_notTheseBikes.any(text.contains)) return null;

    final brand = normalizeKey(raw.brand);
    final entries = [
      for (final e in catalog.entries)
        if (normalizeKey(e.brand) == brand) e,
    ];

    // 1. The text names the model ("CB" + "650 RA", "R" + "YZF-R7").
    final tokens = _tokens('${raw.model} ${raw.version ?? ''}');
    final named = [
      for (final e in entries)
        if (_hasModel(tokens, normalizeKey(e.model))) e,
    ];
    if (named.length > 1) return null; // ambiguous
    var found = named.isEmpty ? null : named.first;

    // 2. The text names only the family ("CB", "R"): the engine size decides,
    //    but only when exactly one catalog model of that family fits it.
    final cc = raw.engineCc;
    if (found == null && cc != null) {
      final family = normalizeKey(raw.model);
      final byEngine = [
        for (final e in entries)
          if (_family(normalizeKey(e.model)) == family && _fits(e, cc)) e,
      ];
      if (byEngine.length == 1) found = byEngine.first;
    }

    // 3. A stated engine size that does not fit rules the match out.
    if (found != null && cc != null && !_fits(found, cc)) return null;
    return found;
  }

  bool _fits(CatalogEntry entry, int cc) {
    final range = _displacement[entry.slug];
    return range == null || (cc >= range.$1 && cc <= range.$2);
  }

  /// `cbr650r` -> `cbr`, `r7` -> `r`: the letters before the first digit.
  static String _family(String key) =>
      key.replaceFirst(RegExp(r'[0-9].*$'), '');

  static List<String> _tokens(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  /// True when [key] ("cbr650r", or with a Honda code suffix) is spelled by up
  /// to four consecutive words starting in the first three.
  static bool _hasModel(List<String> tokens, String key) {
    final accepted = {for (final s in _codeSuffixes) '$key$s'};
    final longest = accepted
        .map((k) => k.length)
        .reduce((a, b) => a > b ? a : b);

    for (var start = 0; start < tokens.length && start <= 2; start++) {
      var joined = '';
      for (var end = start; end < tokens.length && end < start + 4; end++) {
        joined += tokens[end];
        if (accepted.contains(joined)) return true;
        if (joined.length >= longest) break;
      }
    }
    return false;
  }
}
