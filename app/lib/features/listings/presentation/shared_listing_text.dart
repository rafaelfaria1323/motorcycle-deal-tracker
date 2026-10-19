import '../domain/entities/catalog_model.dart';

/// Where a saved link comes from and the id that makes saving it twice
/// update the same listing.
typedef SharedSource = ({String source, String sourceListingId, String url});

/// Sites the collector reads by itself: their ads are not added by hand.
const collectedHosts = {'olx.pt', 'standvirtual.com'};

/// Null when [link] is not an https/http address. The address is kept
/// without its query and fragment (Facebook adds tracking to every link).
SharedSource? sharedSource(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      uri.host.isEmpty) {
    return null;
  }
  final host = siteHost(uri.host);
  final path = uri.path.endsWith('/') && uri.path.length > 1
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  final url = 'https://${uri.host.toLowerCase()}${uri.path}';

  if (host == 'facebook.com' || host == 'fb.com') {
    final item = RegExp(r'/marketplace/item/(\d+)').firstMatch(path);
    return (
      source: 'facebook',
      sourceListingId: item != null
          ? 'facebook.com/marketplace/item/${item.group(1)}'
          : 'facebook.com$path',
      url: item != null
          ? 'https://www.facebook.com/marketplace/item/${item.group(1)}/'
          : url,
    );
  }
  if (host == 'custojusto.pt') {
    // Ad addresses end with the ad's number.
    final number = RegExp(r'(\d{5,})$').firstMatch(path);
    return (
      source: 'custojusto',
      sourceListingId: number != null
          ? 'custojusto.pt/${number.group(1)}'
          : 'custojusto.pt$path',
      url: url,
    );
  }
  return (source: 'other', sourceListingId: '$host$path', url: url);
}

/// "www.m.facebook.com" -> "facebook.com"
String siteHost(String host) =>
    host.toLowerCase().replaceFirst(RegExp(r'^((www|m|web|mobile)\.)+'), '');

/// The catalog model the text names, or null when none or several do
/// equally well. Words are joined in groups of up to three, so "MT 07",
/// "MT-07" and "CB 650 R" find their model, while "YZF-R125" does not
/// find the R1. The longest name wins ("Tracer 7" over a bare "7").
CatalogModel? guessModel(String text, List<CatalogModel> models) {
  final tokens = [
    for (final m in RegExp(r'[a-z0-9]+').allMatches(text.toLowerCase()))
      m.group(0)!,
  ];
  final candidates = <String>{
    for (var i = 0; i < tokens.length; i++)
      for (var n = 1; n <= 3 && i + n <= tokens.length; n++)
        tokens.sublist(i, i + n).join(),
  };

  CatalogModel? best;
  var bestLength = 0;
  var tie = false;
  for (final m in models) {
    final key = m.model.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (key.isEmpty || !candidates.contains(key)) continue;
    if (key.length > bestLength) {
      best = m;
      bestLength = key.length;
      tie = false;
    } else if (key.length == bestLength) {
      tie = true;
    }
  }
  return tie ? null : best;
}

/// An amount: "7 500", "7.500", "7,500", "6 990,00" or plain "6990".
const _amount =
    r'(\d{1,3}(?:[ .,\u00a0\u202f]\d{3})+(?:[.,]\d{2})?|\d+(?:[.,]\d{2})?)';

final _euros = RegExp(
  '€\\s*$_amount|$_amount\\s*(?:€|EUR\\b)',
  caseSensitive: false,
);

/// The first amount in euros: "7 500 €", "€7,500", "7.500€", "6 990,00 €".
double? parsePrice(String text) {
  final match = _euros.firstMatch(text);
  if (match == null) return null;
  final number = (match.group(1) ?? match.group(2)!)
      // Cents: a comma or dot followed by exactly two digits at the end.
      .replaceFirst(RegExp(r'[.,]\d{2}$'), '');
  final value = double.tryParse(number.replaceAll(RegExp(r'\D'), ''));
  return value == null || value <= 0 ? null : value;
}

/// A plausible registration year in the text (1980 to next year).
int? parseYear(String text, {DateTime? now}) {
  final latest = (now ?? DateTime.now()).year + 1;
  for (final m in RegExp(r'(?<!\d)(19[89]\d|20\d\d)(?!\d)').allMatches(text)) {
    final year = int.parse(m.group(1)!);
    if (year <= latest) return year;
  }
  return null;
}

/// "12 000 km", "12.000 kms", "8500km".
int? parseMileage(String text) {
  final m = RegExp(
    r'(\d{1,3}(?:[ .  ]\d{3})+|\d+)\s*kms?\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  return int.tryParse(m.group(1)!.replaceAll(RegExp(r'\D'), ''));
}

/// What is wrong with the form, by field; empty when it can be saved.
Map<String, String> sharedListingProblems({
  required String link,
  required String? modelId,
  required String price,
  required String year,
  required String mileage,
  DateTime? now,
}) {
  final problems = <String, String>{};
  final source = sharedSource(link);
  if (source == null) {
    problems['link'] = 'Cole o endereço do anúncio (começa por https://).';
  } else if (collectedHosts.contains(siteHost(Uri.parse(link.trim()).host))) {
    problems['link'] =
        'Os anúncios do OLX e do Standvirtual já são recolhidos '
        'automaticamente.';
  }
  if (modelId == null) problems['model'] = 'Escolha o modelo.';

  final p = parseAmount(price);
  if (p == null || p <= 0) problems['price'] = 'Indique o preço em euros.';

  if (year.trim().isNotEmpty) {
    final y = int.tryParse(year.trim());
    final latest = (now ?? DateTime.now()).year + 1;
    if (y == null || y < 1980 || y > latest) {
      problems['year'] = 'Indique um ano entre 1980 e $latest.';
    }
  }
  if (mileage.trim().isNotEmpty) {
    final km = int.tryParse(mileage.trim().replaceAll(RegExp(r'[ .]'), ''));
    if (km == null || km < 0 || km > 500000) {
      problems['mileage'] = 'Indique os quilómetros (até 500 000).';
    }
  }
  return problems;
}

/// The form's price: "6 990", "6.990", "6990,50" or "6990 €".
double? parseAmount(String text) => double.tryParse(
  text.replaceAll(RegExp(r'[\s.€]'), '').replaceAll(',', '.'),
);

/// What the share button (or a link) fills in, from the address's query:
/// u = link, t = title, p = price text, d = description, l = location,
/// i = photo. Price, year and km are read from the text; the owner checks
/// everything before saving.
typedef SharedPrefill = ({
  String link,
  String title,
  double? price,
  int? year,
  int? mileage,
  String location,
  String description,
  String? image,
});

SharedPrefill sharedPrefill(Map<String, String> query, {DateTime? now}) {
  String q(String key) => (query[key] ?? '').trim();
  final title = q('t');
  final description = q('d');
  final image = q('i');
  return (
    link: q('u'),
    title: title,
    price: parsePrice(q('p')) ?? parsePrice(title),
    year: parseYear(title, now: now) ?? parseYear(description, now: now),
    mileage: parseMileage(title) ?? parseMileage(description),
    location: q('l').replaceFirst(RegExp(r',\s*Portugal$'), ''),
    description: description,
    image: image.startsWith('https://') ? image : null,
  );
}

/// The snackbar text for a failed save, from the Postgres error code.
String sharedSaveErrorText(String? postgresCode) => switch (postgresCode) {
  '42501' => 'Não foi possível guardar: é preciso ter sessão iniciada.',
  '22023' => 'O servidor recusou os dados. Verifique o preço, o ano e os km.',
  _ => 'Não foi possível guardar. Tente novamente.',
};
