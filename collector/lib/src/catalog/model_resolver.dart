import 'catalog.dart';

/// Decides which catalog model a listing is from the words sellers and sites
/// use. Shared by every source, so a bike is matched the same way wherever
/// it is listed.
class ModelResolver(final Catalog catalog) {
  this {
    for (final entry in catalog.entries) {
      (_byBrand[normalizeKey(entry.brand)] ??= []).add(_ModelRule(entry));
    }
  }

  final _byBrand = <String, List<_ModelRule>>{};
  static final _wordSeparator = RegExp(r'[^a-z0-9]+');
  static final _engineToken = RegExp(r'^[0-9]+cc$');

  /// The catalog model, or null when it is not clearly one.
  ///
  /// [text] holds everything that names the model (model, version, title);
  /// [family] is the site's own model field ("CB", "R"), used with
  /// [engineCc] when the text names only the family.
  CatalogEntry? resolve({
    required String brand,
    required String family,
    required String text,
    int? engineCc,
  }) {
    // A model's excluded words (searched in the letters and digits of the
    // text) rule out that model only: "MT-07 Tracer" can still be a Tracer 7.
    final textKey = normalizeKey(text);
    final brandKey = normalizeKey(brand);
    final entries = [
      for (final e in _byBrand[brandKey] ?? const <_ModelRule>[])
        if (!e.excludedWords.any(textKey.contains)) e,
    ];

    // 1. The text names the model ("CB" + "650 RA", "R" + "YZF-R7").
    final tokens = _tokens(text);
    final named = [
      for (final e in entries)
        if (e.hasModel(tokens)) e,
    ];
    if (named.length > 1) return null; // ambiguous
    var found = named.isEmpty ? null : named.first;

    // 2. The text names only the family ("CB", "R"): the engine size decides,
    //    but only when exactly one catalog model of that family fits it. A
    //    model without engine limits (added in the app) fits every size, so
    //    it can't be chosen this way: a Forza 125 is not the Forza 350.
    final cc = engineCc;
    if (found == null && cc != null) {
      final familyKey = normalizeKey(family);
      final byEngine = [
        for (final e in entries)
          if ((e.entry.engineCcMin != null || e.entry.engineCcMax != null) &&
              e.family == familyKey &&
              e.fits(cc))
            e,
      ];
      if (byEngine.length == 1) found = byEngine.first;
    }

    // 3. A stated engine size that does not fit rules the match out.
    if (found != null && cc != null && !found.fits(cc)) return null;
    return found?.entry;
  }

  /// The words of [text]; an engine size loses its unit ("350cc" -> "350",
  /// so "ADV 350cc" names the ADV 350).
  static List<String> _tokens(String text) => text
      .toLowerCase()
      .split(_wordSeparator)
      .map((t) => _engineToken.hasMatch(t) ? t.substring(0, t.length - 2) : t)
      .where((t) => t.isNotEmpty)
      .toList();
}

/// Catalog-only work, prepared once per resolver rather than once per ad.
class _ModelRule(final CatalogEntry entry) {
  final String family = normalizeKey(entry.model)
      .replaceFirst(_familySuffix, '');
  final List<String> excludedWords = entry.excludedWords
      .map(normalizeKey)
      .toList();
  final Set<String> accepted = _acceptedNames(entry);
  late final int longest = accepted
      .map((key) => key.length)
      .reduce((a, b) => a > b ? a : b);

  /// Honda's ABS and E-Clutch codes: CB650RA, CB650RAC are still a CB650R.
  static const _codeSuffixes = ['', 'a', 'ac'];
  static final _familySuffix = RegExp(r'[0-9].*$');
  static final _closingLetters = RegExp(r'(?<=[0-9])[a-z]+$');

  static Set<String> _acceptedNames(CatalogEntry entry) {
    final names = <String>{};
    for (final name in [entry.model, ...entry.aliases]) {
      final key = normalizeKey(name);
      names.addAll([
        for (final suffix in _codeSuffixes) '$key$suffix',
        key.replaceFirst(_closingLetters, ''),
      ]);
    }
    return names;
  }

  bool fits(int cc) {
    final min = entry.engineCcMin;
    final max = entry.engineCcMax;
    return (min == null || cc >= min) && (max == null || cc <= max);
  }

  /// True when the model name or an alias ("cbr650r", or with a Honda code
  /// suffix) is spelled by up to four consecutive words starting in the first
  /// three.
  ///
  /// A name without its closing letters counts too: sellers write "CBR 650"
  /// for the CBR650R, the only CBR650 made in the tracked years. Older bikes
  /// with the same digits are left out by excluded words and the year range.
  bool hasModel(List<String> tokens) {
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
