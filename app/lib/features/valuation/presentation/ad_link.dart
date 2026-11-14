/// "Avaliar um anúncio" (N.102): the OLX or Standvirtual ad in what the
/// person pasted, as the database reads it (`ad_link_source`,
/// `ad_link_code`; keep both in step).
library;

final _olx = RegExp(
  r'^https?://(www\.|m\.)?olx\.pt/d/(pt/)?anuncio/[^?#\s]*-ID[0-9A-Za-z]+\.html',
  caseSensitive: false,
);
final _standvirtual = RegExp(
  r'^https?://(www\.|m\.)?standvirtual\.com/motos/anuncio/[^?#\s]*-ID[0-9A-Za-z]+\.html',
  caseSensitive: false,
);
final _url = RegExp(r'https?://\S+', caseSensitive: false);

/// The ad's link (without the query or fragment) when [text] holds one:
/// the address alone, or a site's share text with the address in it.
/// Null for anything else (another site, a search, a car).
String? adLinkOf(String text) {
  for (final match in _url.allMatches(text)) {
    final url = match.group(0)!;
    for (final site in [_olx, _standvirtual]) {
      if (site.matchAsPrefix(url) case final ad?) return ad.group(0);
    }
  }
  return null;
}
