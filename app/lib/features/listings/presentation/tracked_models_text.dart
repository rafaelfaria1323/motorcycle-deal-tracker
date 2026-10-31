import '../../../core/formatting/formatters.dart';
import '../domain/entities/catalog_model.dart';
import 'colour_text.dart';
import '../../../core/localization/localizations.dart';

const olxSearchPrefix =
    'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/';
const standvirtualSearchPrefix = 'https://www.standvirtual.com/motos/';

/// "Desde 2023 · OLX e Standvirtual · Azul, Preto".
String modelSubtitle(CatalogModel m, {AppLanguage language = .portuguese}) {
  final sites = [
    if (m.olxSearch != null) 'OLX',
    if (m.standvirtualSearch != null) 'Standvirtual',
  ];
  return [
    language.messages.fromTrackedModelsText(minYear: m.minYear.toString()),
    sites.isEmpty
        ? language.messages.noSearch
        : sites.join(language.messages.andTrackedModelsText),
    ?favouriteColoursText(m.colours, language: language),
  ].join(' · ');
}

/// "Preço de uma nova: 8 250 € (verificado em 13/10/2026)".
String newPriceSubtitle(CatalogModel m, {AppLanguage language = .portuguese}) {
  final price = m.newPrice;
  if (price == null) return language.messages.noNewBikePrice;
  final checked = m.newPriceCheckedAt;
  return language.messages.newBikePriceLine(
    price: Formatters.price(price, language: language),
    checkedNote: checked == null
        ? ''
        : language.messages.checkedOn(date: Formatters.date(checked)),
  );
}

/// Reads a price typed as "8250", "8 250", "8.250 €" or "8250,50". Empty
/// clears the price.
({double? price, String? error}) parseNewPrice(
  String text, {
  AppLanguage language = .portuguese,
}) {
  final cleaned = text.replaceAll(RegExp(r'[\s\u00a0\u202f€]'), '');
  if (cleaned.isEmpty) return (price: null, error: null);
  final value = Formatters.parsePrice(cleaned, language: language);
  if (value == null || value <= 0 || value > 200000) {
    return (price: null, error: language.messages.invalidPrice);
  }
  return (price: value, error: null);
}

/// The searches the collector will run: for the models followed by this
/// account or another. Models that share an address (ignoring year and
/// page) share a search.
({int olx, int standvirtual}) searchCounts(List<CatalogModel> models) {
  String key(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasQuery) return url;
    final params = {...uri.queryParameters}
      ..remove('page')
      ..remove('search[filter_float_year:from]');
    return '${uri.replace(queryParameters: params)}';
  }

  final tracked = models.where((m) => m.isTracked || m.isCollected);
  return (
    olx: {
      for (final m in tracked)
        if (m.olxSearch case final url?) key(url),
    }.length,
    standvirtual: {for (final m in tracked) ?m.standvirtualSearch}.length,
  );
}

/// The searches each collection runs for the collected models (of every
/// account). There is no request cap: every page of each search is read.
String searchesLine(
  List<CatalogModel> models, {
  AppLanguage language = .portuguese,
}) {
  final counts = searchCounts(models);
  return language.messages.searchesPerCollection(
    olx: counts.olx.toString(),
    standvirtual: counts.standvirtual.toString(),
  );
}

/// Problems with the "add a model" form, by field; empty when it is fine.
Map<String, String> newModelProblems({
  required String brand,
  required String model,
  required String year,
  int? currentYear,
  AppLanguage language = .portuguese,
}) {
  final maxYear = (currentYear ?? DateTime.now().year) + 1;
  final parsedYear = int.tryParse(year.trim());
  final nameCharacters = RegExp(r'[\p{L}\p{N}]', unicode: true);

  return {
    if (!nameCharacters.hasMatch(brand)) 'brand': language.messages.enterMake,
    if (!nameCharacters.hasMatch(model)) 'model': language.messages.enterModel,
    if (parsedYear == null || parsedYear < 1990 || parsedYear > maxYear)
      'year': language.messages.yearBetween1990And(
        maxYear: (maxYear).toString(),
      ),
  };
}

/// The snackbar text for a failed catalog change, from the Postgres error
/// code (null when the error was not a database one).
String catalogSaveErrorText(
  String? postgresCode, {
  AppLanguage language = .portuguese,
}) => switch (postgresCode) {
  '23505' => language.messages.thatModelIsAlreadyInList,
  '42501' => language.messages.couldNotSaveYouNeedToBeSigned,
  _ => language.messages.couldNotSaveTryAgain,
};

/// "Z 650, Z-650" -> ["Z 650", "Z-650"].
List<String> parseAliases(String text) => [
  for (final part in text.split(','))
    if (part.trim().isNotEmpty) part.trim(),
];
