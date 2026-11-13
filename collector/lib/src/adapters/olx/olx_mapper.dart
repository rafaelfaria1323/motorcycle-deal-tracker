import '../../catalog/catalog.dart';
import '../../catalog/model_resolver.dart';
import '../../normalized/normalized_listing.dart';
import '../manual/manual_mapper.dart';
import '../manual/manual_raw_listing.dart';
import 'olx_raw_listing.dart';

class OlxMapper(final Catalog catalog, {int? currentYear}) {
  final ManualMapper _base = ManualMapper(catalog, currentYear: currentYear);
  final ModelResolver _models = ModelResolver(catalog);

  /// The id an OLX ad is stored under.
  static String listingId(String adId) => 'olx.pt/$adId';

  /// The Standvirtual ad an OLX ad copies ("ID8Q1m16", from its
  /// `externalUrl` ".../honda-cbr-ID8Q1m16.html"); null for an OLX ad of
  /// its own, or a copy whose address doesn't name the ad.
  static String? standvirtualOriginal(OlxRawListing raw) {
    if (raw.partner != 'standvirtual') return null;
    final url = raw.externalUrl;
    if (url == null) return null;
    return RegExp(r'-(ID[0-9A-Za-z]+)\.html').firstMatch(url)?.group(1);
  }

  /// Maps an OLX ad. A copy of a Standvirtual ad is rejected unless
  /// [keepCopy]: the import keeps it only when the original isn't stored
  /// (N.70, `olx_copies_to_skip`).
  MapOutcome map(OlxRawListing raw, {bool keepCopy = false}) {
    if (raw.status != 'active') {
      return Rejected('listing is not active (${raw.status})');
    }
    // Standvirtual dealers' ads are copied to OLX automatically; the
    // original is collected from Standvirtual with more detail, when its
    // searches find it.
    if (raw.partner == 'standvirtual' && !keepCopy) {
      return Rejected('copy of a Standvirtual ad (${raw.externalUrl ?? '?'})');
    }
    final price = raw.price;
    if (price == null) return const Rejected('no price (trade or on request)');
    if (raw.currency != 'EUR') {
      return Rejected('price is in ${raw.currency}, not EUR');
    }

    final brand = _brand(raw);
    final family = raw.model ?? '';
    final title = _withoutBrand(raw.title, brand);
    final entry =
        _models.resolve(brand: brand, family: family, text: '$family $title') ??
        _fromDescription(raw.description, brand, family);

    // Unresolved: keep the title, without letting the base mapper's
    // exact lookup undo the resolver's decision.
    final model = entry?.model ?? title;

    final outcome = _base.map(
      ManualRawListing(
        url: raw.url,
        brand: brand,
        model: model,
        // The title, as Standvirtual's version: it often names what the
        // description doesn't ("35kW A2", "com quickshifter"), read by the
        // risk and extras rules.
        variant: entry != null ? _titleText(title) : null,
        priceEur: price,
        year: raw.year,
        mileageKm: raw.mileageKm,
        sellerType: raw.isBusiness ? 'dealer' : 'private',
        sellerName: raw.businessName,
        location: raw.location,
        description: raw.description,
        images: raw.images,
      ),
      matchCatalog: entry != null,
    );

    return switch (outcome) {
      Mapped(:final listing, :final warnings) => Mapped(
        listing.fromSite(
          source: 'olx',
          // The numeric ad id survives the title being edited.
          sourceListingId: listingId(raw.id),
          publishedAt: raw.createdAt,
          siteRefreshedAt: raw.refreshedAt,
        ),
        warnings,
      ),
      Rejected() => outcome,
    };
  }

  /// The title without the brand and the words around it ("Moto Yamaha
  /// YZF-R7" -> "YZF-R7", "Vendo mota Honda Forza 350" -> "Forza 350"), so
  /// the model sits at the start where the resolver looks for it. The brand
  /// counts as the second word at most, or later when every word before it
  /// is [_saleWords]: "R7 troca Yamaha" keeps its model. A title laid out
  /// as a form loses its label and the brand named again ("Honda •
  /// Modelo: Honda PCX 125 DX" -> "PCX 125 DX").
  static String _withoutBrand(String title, String brand) {
    final whole = title.trim();
    final words = whole.split(RegExp(r'\s+'));
    final key = brand.toLowerCase();
    final at = words.indexWhere((w) => w.toLowerCase() == key);
    if (at < 0) return whole;
    if (at > 1 &&
        !words.take(at).every((w) => _saleWords.contains(w.toLowerCase()))) {
      return whole;
    }
    var start = at + 1;
    while (start < words.length && _isLeadIn(words[start], key)) {
      start++;
    }
    final rest = words.sublist(start).join(' ');
    return rest.isEmpty ? whole : rest;
  }

  /// A word before the model that names nothing: a bullet or dash, a
  /// form's label ("Modelo:", "Marca:") or the brand again.
  static bool _isLeadIn(String word, String brandKey) {
    final letters = normalizeKey(word);
    return letters.isEmpty ||
        letters == brandKey ||
        (word.endsWith(':') && _labels.contains(letters));
  }

  /// Labels of titles laid out as a form.
  static const _labels = {'modelo', 'marca', 'model'};

  /// The model the description names after the brand near its start
  /// ("VENDE-SE – HONDA CBR650R E-Clutch 2026", under a title of only
  /// "Honda CBR"), when it is of the ad's own OLX model [family] (its
  /// letters, [_familyKey]): a description can name other bikes ("troco
  /// por Honda CB650R"). Null without a family or when the start of the
  /// description names no model.
  CatalogEntry? _fromDescription(
    String? description,
    String brand,
    String family,
  ) {
    final familyKey = _familyKey(family);
    if (description == null || familyKey.isEmpty) return null;
    final words = description.trim().split(RegExp(r'\s+'));
    final brandKey = normalizeKey(brand);
    final at = words
        .take(_descriptionWords)
        .toList()
        .indexWhere((w) => normalizeKey(w) == brandKey);
    if (at < 0) return null;
    final entry = _models.resolve(
      brand: brand,
      family: family,
      text: words.skip(at + 1).take(4).join(' '),
    );
    if (entry == null) return null;
    return _familyKey(entry.model) == familyKey ? entry : null;
  }

  /// A model's letters before its first digit: "MT-07" and "MT-09" are
  /// "mt", "CBR650R" is "cbr".
  static String _familyKey(String model) =>
      normalizeKey(model).replaceFirst(RegExp(r'[0-9].*$'), '');

  /// How far into the description the brand is looked for.
  static const _descriptionWords = 12;

  /// [title] without anything shaped like a Portuguese phone number (nine
  /// digits from 2 or 9, spaced or not): nobody's phone number is stored.
  static String? _titleText(String title) {
    final text = title
        .replaceAll(
          RegExp(r'(?<!\d)(\+?351\s*)?[29]\d{2}[\s.]?\d{3}[\s.]?\d{3}(?!\d)'),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  /// Words sellers put before the brand ("Vendo mota Honda ...").
  static const _saleWords = {
    'vendo',
    'vende',
    'vende-se',
    'vendese',
    'venda',
    'mota',
    'moto',
    'motociclo',
    'motocicleta',
    'scooter',
    'a',
    'uma',
    'minha',
  };

  /// The brand of the search's category (spelled as in the catalog when
  /// it is there): it wins over the title, so "Honda CB650R (troca por
  /// Yamaha)" is a Honda. Without a category, the catalog brand named in
  /// the title, otherwise the title's first word as written.
  String _brand(OlxRawListing raw) {
    final category = normalizeKey(raw.categoryBrand ?? '');
    final words = {
      for (final w in raw.title.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
        if (w.isNotEmpty) w,
    };
    for (final e in catalog.entries) {
      final key = normalizeKey(e.brand);
      if (category.isEmpty ? words.contains(key) : key == category) {
        return e.brand;
      }
    }
    final fallback = raw.categoryBrand ?? raw.title.split(' ').first;
    return fallback.isEmpty
        ? fallback
        : fallback[0].toUpperCase() + fallback.substring(1);
  }
}
