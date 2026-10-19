import 'catalog.dart';

/// Decides which catalog model a listing is from the words sellers and sites
/// use. Shared by every source, so a bike is matched the same way wherever
/// it is listed.
class ModelResolver {
  const ModelResolver(this.catalog);

  final Catalog catalog;

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
    if (_notTheseBikes.any(normalizeKey(text).contains)) return null;

    final brandKey = normalizeKey(brand);
    final entries = [
      for (final e in catalog.entries)
        if (normalizeKey(e.brand) == brandKey) e,
    ];

    // 1. The text names the model ("CB" + "650 RA", "R" + "YZF-R7").
    final tokens = _tokens(text);
    final named = [
      for (final e in entries)
        if (_hasModel(tokens, normalizeKey(e.model))) e,
    ];
    if (named.length > 1) return null; // ambiguous
    var found = named.isEmpty ? null : named.first;

    // 2. The text names only the family ("CB", "R"): the engine size decides,
    //    but only when exactly one catalog model of that family fits it.
    final cc = engineCc;
    if (found == null && cc != null) {
      final familyKey = normalizeKey(family);
      final byEngine = [
        for (final e in entries)
          if (_family(normalizeKey(e.model)) == familyKey && _fits(e, cc)) e,
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
  ///
  /// The key without its closing letters counts too: sellers write "CBR 650"
  /// for the CBR650R, the only CBR650 made in the tracked years. Older bikes
  /// with the same digits are left out by [_notTheseBikes] and the year range.
  static bool _hasModel(List<String> tokens, String key) {
    final accepted = {
      for (final s in _codeSuffixes) '$key$s',
      key.replaceFirst(RegExp(r'(?<=[0-9])[a-z]+$'), ''),
    };
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
