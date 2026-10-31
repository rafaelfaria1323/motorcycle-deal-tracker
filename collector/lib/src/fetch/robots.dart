/// The part of robots.txt we need: the Allow and Disallow rules of the `*`
/// group. As RFC 9309 says, the longest matching rule decides and an Allow
/// wins a tie (a CDN's `Disallow: /` with `Allow: /v1/files/` allows the
/// files).
class RobotsRules._(final List<_Rule> _rules) {
  factory RobotsRules.parse(String text) {
    final rules = <_Rule>[];
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
        final allow = field == 'allow';
        if (inStarGroup && (allow || field == 'disallow') && value.isNotEmpty) {
          rules.add((pattern: _toRegExp(value), text: value, allow: allow));
        }
      }
    }
    return RobotsRules._(rules);
  }

  /// [pathAndQuery] is the path plus `?query`, e.g. `/motos/x?page=2`.
  bool isAllowed(String pathAndQuery) => _decisive(pathAndQuery)?.allow ?? true;

  /// The line that decides [pathAndQuery], for logs: `Disallow: /`.
  String decidingRule(String pathAndQuery) {
    final rule = _decisive(pathAndQuery);
    if (rule == null) return 'no rule';
    return '${rule.allow ? 'Allow' : 'Disallow'}: ${rule.text}';
  }

  _Rule? _decisive(String pathAndQuery) {
    _Rule? decisive;
    for (final rule in _rules) {
      if (!rule.pattern.hasMatch(pathAndQuery)) continue;
      if (decisive == null ||
          rule.text.length > decisive.text.length ||
          (rule.text.length == decisive.text.length && rule.allow)) {
        decisive = rule;
      }
    }
    return decisive;
  }

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

typedef _Rule = ({RegExp pattern, String text, bool allow});
