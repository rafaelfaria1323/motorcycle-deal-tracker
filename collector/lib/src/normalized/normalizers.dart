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
