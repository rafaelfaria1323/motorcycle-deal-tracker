/// Lowercase letters and digits only, so "MT-07", "mt 07" and "MT07" match.
String normalizeKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class CatalogEntry {
  const CatalogEntry({
    required this.slug,
    required this.brand,
    required this.model,
    required this.minYear,
    this.id,
    this.aliases = const [],
    this.excludedWords = const [],
    this.engineCcMin,
    this.engineCcMax,
    this.olxSearch,
    this.standvirtualSearch,
  });

  final String slug;
  final String brand;
  final String model;
  final int minYear;
  final String? id;

  /// Other ways sellers name the model ("Hornet 750" for the CB750 Hornet).
  final List<String> aliases;

  /// Text that makes a listing another bike, even though it names this model
  /// ("Tracer" in an MT-07 Tracer, "650F" for a CB650F).
  final List<String> excludedWords;

  /// The engine sizes (cc) sellers state for the model; null when unknown.
  final int? engineCcMin;
  final int? engineCcMax;

  /// The search address that lists the model on each site, if any.
  final String? olxSearch;
  final String? standvirtualSearch;
}

class Catalog {
  const Catalog(this.entries);

  /// The four MVP models with their matching rules. The collector loads the
  /// catalog from the `motorcycles` table; this one is for tests and dry runs.
  factory Catalog.mvp() => const Catalog([
    CatalogEntry(
      slug: 'yamaha-mt-07',
      brand: 'Yamaha',
      model: 'MT-07',
      minYear: 2026,
      excludedWords: ['tracer'],
      engineCcMin: 680,
      engineCcMax: 710,
    ),
    CatalogEntry(
      slug: 'yamaha-r7',
      brand: 'Yamaha',
      model: 'R7',
      minYear: 2026,
      engineCcMin: 680,
      engineCcMax: 710,
    ),
    CatalogEntry(
      slug: 'honda-cb650r',
      brand: 'Honda',
      model: 'CB650R',
      minYear: 2025,
      excludedWords: ['650f'],
      engineCcMin: 640,
      engineCcMax: 660,
    ),
    CatalogEntry(
      slug: 'honda-cbr650r',
      brand: 'Honda',
      model: 'CBR650R',
      minYear: 2025,
      excludedWords: ['650f'],
      engineCcMin: 640,
      engineCcMax: 660,
    ),
  ]);

  final List<CatalogEntry> entries;

  /// Exact match on brand and model, ignoring case and punctuation.
  CatalogEntry? find(String brand, String model) {
    final b = normalizeKey(brand);
    final m = normalizeKey(model);
    for (final e in entries) {
      if (normalizeKey(e.brand) == b && normalizeKey(e.model) == m) return e;
    }
    return null;
  }

  /// A catalog model that the given model merely starts with, such as
  /// "MT-07 ABS". Only used for a hint; it is never treated as a match.
  CatalogEntry? nearMiss(String brand, String model) {
    final b = normalizeKey(brand);
    final m = normalizeKey(model);
    for (final e in entries) {
      if (normalizeKey(e.brand) == b && m.startsWith(normalizeKey(e.model))) {
        return e;
      }
    }
    return null;
  }
}
