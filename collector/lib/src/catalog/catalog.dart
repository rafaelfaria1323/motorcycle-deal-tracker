/// Lowercase letters and digits only, so "MT-07", "mt 07" and "MT07" match.
String normalizeKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class CatalogEntry {
  const CatalogEntry({
    required this.slug,
    required this.brand,
    required this.model,
    required this.minYear,
  });

  final String slug;
  final String brand;
  final String model;
  final int minYear;
}

class Catalog {
  const Catalog(this.entries);

  /// The four MVP models. In 5.5 this is loaded from the `motorcycles` table.
  factory Catalog.mvp() => const Catalog([
    CatalogEntry(
      slug: 'yamaha-mt-07',
      brand: 'Yamaha',
      model: 'MT-07',
      minYear: 2026,
    ),
    CatalogEntry(
      slug: 'yamaha-r7',
      brand: 'Yamaha',
      model: 'R7',
      minYear: 2026,
    ),
    CatalogEntry(
      slug: 'honda-cb650r',
      brand: 'Honda',
      model: 'CB650R',
      minYear: 2025,
    ),
    CatalogEntry(
      slug: 'honda-cbr650r',
      brand: 'Honda',
      model: 'CBR650R',
      minYear: 2025,
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
