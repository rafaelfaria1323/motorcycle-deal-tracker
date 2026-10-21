import '../catalog/catalog.dart';
import 'polite_fetcher.dart';

/// One search to fetch, and the tracked models it is run for.
class PlannedSearch {
  const PlannedSearch(this.url, this.models);

  final Uri url;
  final List<String> models;
}

/// OLX's "year from" filter. The collector sets it from the models' first
/// tracked year, whatever the stored address says.
const olxYearFrom = 'search[filter_float_year:from]';

/// Standvirtual's "first registration from" filter, set the same way, so
/// older bikes don't use up pages (a search spans pages of 32).
const standvirtualYearFrom =
    'search[filter_float_first_registration_year:from]';

/// OLX's engine-size filter. OLX's model filter is a family ("R" holds the
/// R125, R3, R6, R7 and R1; "CB" every CB from 125 to 1000 cc), so a search
/// for one model also brings every other model of the family: pages spent
/// on ads no account follows. When every model of a search lies inside one
/// of OLX's engine-size bands, the search asks for that band only.
const olxEngineSize = 'search[filter_enum_cilindrada][0]';

/// OLX's engine-size bands (value, cc from, cc to), as listed by the
/// site's own filter in its search pages (`filter_enum_cilindrada`). Change
/// them only from that list: an unknown value would make OLX return nothing.
const olxEngineBands = [
  (value: 'ate-50-cc', from: 0, to: 50),
  (value: '51-125-cc', from: 51, to: 125),
  (value: '126-500-cc', from: 126, to: 500),
  (value: '501-1000-cc', from: 501, to: 1000),
  (value: 'mais-de-1000-cc', from: 1001, to: 100000),
];

/// The band that holds every one of [entries], or null when one has no
/// engine size or they don't fit one band.
String? olxEngineBand(Iterable<CatalogEntry> entries) {
  for (final band in olxEngineBands) {
    if (entries.every(
      (e) =>
          e.engineCcMin != null &&
          e.engineCcMax != null &&
          e.engineCcMin! >= band.from &&
          e.engineCcMax! <= band.to,
    )) {
      return band.value;
    }
  }
  return null;
}

/// The searches for [site] of the models in [catalog], in catalog order. Models
/// with the same address share one search, which asks for the earliest year
/// any of them tracks (and, on OLX, the engine-size band that holds all of
/// them: [olxEngineBand]). Unusable addresses are left out and reported in
/// `problems`.
({List<PlannedSearch> searches, List<String> problems}) planSearches(
  Catalog catalog,
  FetchSite site,
) {
  final groups = <String, (Uri, List<CatalogEntry>)>{};
  final problems = <String>[];

  for (final entry in catalog.entries) {
    final raw = site == FetchSite.olx
        ? entry.olxSearch
        : site == FetchSite.standvirtual
        ? entry.standvirtualSearch
        : null;
    if (raw == null || raw.trim().isEmpty) continue;

    final url = Uri.tryParse(raw.trim());
    final problem = url == null
        ? 'not an address'
        : urlProblem(url, site: site);
    if (problem != null) {
      problems.add('${entry.brand} ${entry.model}: "$raw" ($problem)');
      continue;
    }
    final base = _withoutPageOrYear(url!);
    groups.putIfAbsent(base.toString(), () => (base, [])).$2.add(entry);
  }

  return (
    searches: [
      for (final (base, entries) in groups.values)
        PlannedSearch(
          base.replace(
            queryParameters: {
              ...base.queryParameters,
              site == FetchSite.olx ? olxYearFrom : standvirtualYearFrom:
                  '${entries.map((e) => e.minYear).reduce(_min)}',
              if (site == FetchSite.olx) olxEngineSize: ?olxEngineBand(entries),
            },
          ),
          [for (final e in entries) '${e.brand} ${e.model}'],
        ),
    ],
    problems: problems,
  );
}

int _min(int a, int b) => a < b ? a : b;

Uri _withoutPageOrYear(Uri url) {
  if (!url.hasQuery) return url;
  final params = {...url.queryParameters}
    ..remove('page')
    ..remove(olxYearFrom)
    ..remove(standvirtualYearFrom)
    ..removeWhere((key, _) => key.startsWith('search[filter_enum_cilindrada]'));
  return params.isEmpty
      ? Uri.parse(url.toString().split('?').first)
      : url.replace(queryParameters: params);
}
