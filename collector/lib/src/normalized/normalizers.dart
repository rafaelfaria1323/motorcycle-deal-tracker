import 'normalized_listing.dart';

/// Stable id derived from a listing URL: host without "www." + path + the
/// meaningful query parameters (sorted). Scheme, fragment, trailing slash and
/// tracking parameters are ignored.
String canonicalListingId(String url) {
  final uri = Uri.parse(url);

  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);

  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path == '/') path = '';

  final keys = uri.queryParameters.keys.where((k) => !_isTracking(k)).toList()
    ..sort();
  final query = keys.isEmpty
      ? ''
      : '?${keys.map((k) => '$k=${uri.queryParameters[k]}').join('&')}';

  return '$host$path$query';
}

bool _isTracking(String key) {
  final k = key.toLowerCase();
  return k.startsWith('utm_') ||
      const {'fbclid', 'gclid', 'msclkid', 'ref'}.contains(k);
}

const _privateWords = {'private', 'particular'};
const _dealerWords = {
  'dealer',
  'profissional',
  'stand',
  'concessionario',
  'concessionário',
};

/// Null when the text is not a known seller type.
SellerType? parseSellerType(String value) {
  final v = value.trim().toLowerCase();
  if (_privateWords.contains(v)) return SellerType.private;
  if (_dealerWords.contains(v)) return SellerType.dealer;
  return null;
}

/// Keeps valid http(s) image links, without duplicates, in their original order.
List<String> cleanImages(List<String> images) {
  final seen = <String>{};
  final result = <String>[];
  for (final image in images) {
    final link = image.trim();
    final uri = Uri.tryParse(link);
    final valid =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (valid && seen.add(link)) result.add(link);
  }
  return result;
}

// Sentences dealers' systems add to every ad. Left in, they make unrelated
// bikes from one dealer look like duplicates of each other. Only these
// sentences are removed; the rest of the paragraph stays.
final _boilerplate = [
  RegExp(r'A informação disponibilizada[^.]*\.?', caseSensitive: false),
  RegExp(
    r'Anúncio introduzido por rotina informática\.?',
    caseSensitive: false,
  ),
  RegExp(
    r'Todos os dados carecem de confirmação presencial\.?',
    caseSensitive: false,
  ),
];

// Compiled once: cleanDescription runs for every OLX ad and listing page.
final _blockEnd = RegExp(
  r'<br\s*/?>|</p>|</div>|</li>|</h\d>',
  caseSensitive: false,
);
final _listItem = RegExp(r'<li[^>]*>', caseSensitive: false);
final _tag = RegExp(r'<[^>]+>');
final _charCode = RegExp(r'&#(\d+);');
final _spaces = RegExp(r'[ \t]+');

/// Plain text from a listing's HTML description, without the boilerplate
/// sentences dealers' systems add; null when nothing is left.
String? cleanDescription(Object? html) {
  if (html is! String) return null;

  var text = html
      // Block ends and line breaks become new lines; list items get a dash.
      .replaceAll(_blockEnd, '\n')
      .replaceAll(_listItem, '- ')
      .replaceAll(_tag, '')
      .replaceAllMapped(_charCode, (m) => String.fromCharCode(int.parse(m[1]!)))
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');

  for (final sentence in _boilerplate) {
    text = text.replaceAll(sentence, '');
  }

  final lines = text
      .split('\n')
      .map((l) => l.replaceAll(_spaces, ' ').trim())
      .where((l) => l.isNotEmpty && l != '-')
      .toList();
  return lines.isEmpty ? null : lines.join('\n');
}
