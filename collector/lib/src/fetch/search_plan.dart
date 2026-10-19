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

/// The searches for [site] of the models in [catalog], in catalog order. Models
/// with the same address share one search; on OLX it asks for the earliest
/// year any of them tracks. Unusable addresses are left out and reported in
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
          site == FetchSite.olx
              ? base.replace(
                  queryParameters: {
                    ...base.queryParameters,
                    olxYearFrom:
                        '${entries.map((e) => e.minYear).reduce(_min)}',
                  },
                )
              : base,
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
    ..remove(olxYearFrom);
  return params.isEmpty
      ? Uri.parse(url.toString().split('?').first)
      : url.replace(queryParameters: params);
}
