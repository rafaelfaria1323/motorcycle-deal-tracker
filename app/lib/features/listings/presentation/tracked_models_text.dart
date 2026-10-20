import '../../../core/formatting/formatters.dart';
import '../domain/entities/catalog_model.dart';

const olxSearchPrefix =
    'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/';
const standvirtualSearchPrefix = 'https://www.standvirtual.com/motos/';

/// The collector's request budget per site and run, and the number of OLX
/// searches (1 to 4 pages each) above which it may run out.
const requestsPerRun = 20;
const comfortableOlxSearches = 5;

/// "Desde 2023 · OLX e Standvirtual".
String modelSubtitle(CatalogModel m) {
  final sites = [
    if (m.olxSearch != null) 'OLX',
    if (m.standvirtualSearch != null) 'Standvirtual',
  ];
  return [
    'Desde ${m.minYear}',
    sites.isEmpty ? 'sem pesquisa' : sites.join(' e '),
  ].join(' · ');
}

/// "Preço de uma nova: 8 250 € (verificado em 13/10/2026)".
String newPriceSubtitle(CatalogModel m) {
  final price = m.newPrice;
  if (price == null) return 'Sem preço de uma nova';
  final checked = m.newPriceCheckedAt;
  return 'Preço de uma nova: ${Formatters.price(price)}'
      '${checked == null ? '' : ' (verificado em ${Formatters.date(checked)})'}';
}

/// Reads a price typed as "8250", "8 250", "8.250 €" or "8250,50". Empty
/// clears the price.
({double? price, String? error}) parseNewPrice(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'[\s\u00a0\u202f€]'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  if (cleaned.isEmpty) return (price: null, error: null);
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0 || value > 200000) {
    return (price: null, error: 'Preço inválido');
  }
  return (price: value, error: null);
}

/// The searches the collector will run for the tracked models: models that
/// share an address (ignoring year and page) share a search.
({int olx, int standvirtual}) searchCounts(List<CatalogModel> models) {
  String key(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasQuery) return url;
    final params = {...uri.queryParameters}
      ..remove('page')
      ..remove('search[filter_float_year:from]');
    return '${uri.replace(queryParameters: params)}';
  }

  final tracked = models.where((m) => m.isTracked);
  return (
    olx: {
      for (final m in tracked)
        if (m.olxSearch case final url?) key(url),
    }.length,
    standvirtual: {for (final m in tracked) ?m.standvirtualSearch}.length,
  );
}

/// What the tracked models cost in requests, and a warning when the budget
/// may run out.
List<String> budgetLines(List<CatalogModel> models) {
  final counts = searchCounts(models);
  return [
    'Pesquisas em cada recolha: ${counts.olx} no OLX e '
        '${counts.standvirtual} no Standvirtual (limite de $requestsPerRun '
        'pedidos por site).',
    if (counts.olx > comfortableOlxSearches)
      'Muitas pesquisas no OLX: cada uma usa 1 a 4 pedidos. Se o limite for '
          'atingido, as pesquisas dos modelos adicionados mais recentemente '
          'ficam para a recolha seguinte.',
  ];
}

/// Problems with the "add a model" form, by field; empty when it is fine.
Map<String, String> newModelProblems({
  required String brand,
  required String model,
  required String year,
  required String olxSearch,
  required String standvirtualSearch,
  int? currentYear,
}) {
  final maxYear = (currentYear ?? DateTime.now().year) + 1;
  final parsedYear = int.tryParse(year.trim());
  final olx = olxSearch.trim();
  final sv = standvirtualSearch.trim();

  return {
    if (brand.trim().isEmpty) 'brand': 'Indique a marca',
    if (model.trim().isEmpty) 'model': 'Indique o modelo',
    if (parsedYear == null || parsedYear < 1990 || parsedYear > maxYear)
      'year': 'Ano entre 1990 e $maxYear',
    if (olx.isEmpty && sv.isEmpty)
      'olx': 'Indique pelo menos uma pesquisa (OLX ou Standvirtual)',
    if (olx.isNotEmpty && !olx.startsWith(olxSearchPrefix))
      'olx': 'Tem de ser uma pesquisa de motociclos do OLX ($olxSearchPrefix…)',
    if (sv.isNotEmpty && !sv.startsWith(standvirtualSearchPrefix))
      'standvirtual':
          'Tem de ser uma pesquisa do Standvirtual ($standvirtualSearchPrefix…)',
  };
}

/// The snackbar text for a failed catalog change, from the Postgres error
/// code (null when the error was not a database one).
String catalogSaveErrorText(String? postgresCode) => switch (postgresCode) {
  '23505' => 'Esse modelo já está na lista.',
  '42501' => 'Não foi possível guardar: é preciso ter sessão iniciada.',
  _ => 'Não foi possível guardar. Tente novamente.',
};

/// "Z 650, Z-650" -> ["Z 650", "Z-650"].
List<String> parseAliases(String text) => [
  for (final part in text.split(','))
    if (part.trim().isNotEmpty) part.trim(),
];
