/// The part of robots.txt we need: the Disallow rules of the `*` group.
/// (Standvirtual's file has a single `Allow: /`, so Allow lines are ignored.)
class RobotsRules {
  RobotsRules(this._disallow);

  factory RobotsRules.parse(String text) {
    final patterns = <RegExp>[];
    var inStarGroup = false;
    var previousWasAgent = false;

    for (final raw in text.split('\n')) {
      final line = raw.split('#').first.trim();
      if (line.isEmpty) continue;
      final colon = line.indexOf(':');
      if (colon < 0) continue;

      final field = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();

      if (field == 'user-agent') {
        // Consecutive User-agent lines share one group.
        if (!previousWasAgent) inStarGroup = false;
        if (value == '*') inStarGroup = true;
        previousWasAgent = true;
      } else {
        previousWasAgent = false;
        if (inStarGroup && field == 'disallow' && value.isNotEmpty) {
          patterns.add(_toRegExp(value));
        }
      }
    }
    return RobotsRules(patterns);
  }

  final List<RegExp> _disallow;

  /// [pathAndQuery] is the path plus `?query`, e.g. `/motos/x?page=2`.
  bool isAllowed(String pathAndQuery) =>
      !_disallow.any((rule) => rule.hasMatch(pathAndQuery));

  static RegExp _toRegExp(String rule) {
    final out = StringBuffer('^');
    for (final rune in rule.runes) {
      final c = String.fromCharCode(rune);
      if (c == '*') {
        out.write('.*');
      } else if (c == r'$') {
        out.write(r'$');
      } else {
        out.write(RegExp.escape(c));
      }
    }
    return RegExp(out.toString());
  }
}
