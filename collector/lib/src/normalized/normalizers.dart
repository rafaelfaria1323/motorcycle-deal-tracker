import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

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

/// The most photos kept per listing (ads rarely have more; the list is
/// stored with every listing).
const maxImages = 30;

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

const _blockEnds = {'br', 'p', 'div', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};
final _spaces = RegExp(r'[ \t]+');
final _numericReference = RegExp(r'&#([xX][0-9a-fA-F]+|[0-9]+);?');

/// Protects the HTML tokenizer from overflowing numeric references.
/// [preserveLength] keeps source offsets usable against the original HTML.
String safeNumericReferences(String html, {bool preserveLength = false}) =>
    html.replaceAllMapped(_numericReference, (match) {
      final digits = match[1]!;
      final hex = digits.startsWith('x') || digits.startsWith('X');
      final value = int.tryParse(
        hex ? digits.substring(1) : digits,
        radix: hex ? 16 : 10,
      );
      // The HTML tokenizer's int.parse throws on oversized references.
      return value == null || value < 0 || value > 0x10FFFF
          ? '\uFFFD' * (preserveLength ? match[0]!.length : 1)
          : match[0]!;
    });

void _descriptionText(dom.Node node, StringBuffer text) {
  if (node is dom.Text) {
    text.write(node.data);
    return;
  }
  if (node is! dom.Element) return;
  final tag = node.localName;
  if (tag == 'script' || tag == 'style') return;
  if (tag == 'li') text.write('- ');
  for (final child in node.nodes) {
    _descriptionText(child, text);
  }
  if (_blockEnds.contains(tag)) text.writeln();
}

/// Plain text from a listing's HTML description, without the boilerplate
/// sentences dealers' systems add; null when nothing is left.
String? cleanDescription(Object? html) {
  if (html is! String) return null;

  final buffer = StringBuffer();
  for (final node in parseFragment(safeNumericReferences(html)).nodes) {
    _descriptionText(node, buffer);
  }
  var text = buffer.toString().replaceAll('\u00a0', ' ');

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
