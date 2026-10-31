import 'dart:convert';

/// The part of robots.txt we need: the Allow and Disallow rules of the `*`
/// group. As RFC 9309 says, the longest matching rule decides and an Allow
/// wins a tie (a CDN's `Disallow: /` with `Allow: /v1/files/` allows the
/// files). Addresses and rules are compared percent-decoded where the octet
/// is ASCII (`%5B` is `[`), and encoded where it isn't, so a rule written
/// either way matches the address we ask for. `*` is any text and `$` the
/// end, only as the rule's last character.
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
    final target = _canonical(pathAndQuery);
    _Rule? decisive;
    for (final rule in _rules) {
      if (!rule.pattern.hasMatch(target)) continue;
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
    final anchored = rule.endsWith(r'$');
    final body = anchored ? rule.substring(0, rule.length - 1) : rule;
    // `*` is a wildcard only as written; an encoded one (%2A) is literal.
    final parts = body.split('*');
    out.write(parts.map((p) => RegExp.escape(_canonical(p))).join('.*'));
    if (anchored) out.write(r'$');
    return RegExp(out.toString());
  }

  static final _escape = RegExp('%([0-9A-Fa-f]{2})');

  /// [text] with ASCII octets percent-decoded and every other one
  /// percent-encoded in capitals, the form both sides are compared in.
  static String _canonical(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (rune < 0x80) {
        out.writeCharCode(rune);
      } else {
        for (final byte in utf8.encode(String.fromCharCode(rune))) {
          out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
        }
      }
    }
    return out.toString().replaceAllMapped(_escape, (m) {
      final code = int.parse(m[1]!, radix: 16);
      return code < 0x80
          ? String.fromCharCode(code)
          : '%${m[1]!.toUpperCase()}';
    });
  }
}

typedef _Rule = ({RegExp pattern, String text, bool allow});
