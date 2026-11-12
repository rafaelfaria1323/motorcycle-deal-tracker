import '../catalog/catalog.dart';
import 'polite_fetcher.dart';

/// One search to fetch, and the tracked models it is run for.
class const PlannedSearch(final Uri url, final List<String> models);

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

/// Standvirtual's engine-size filter (cc from, cc to), any whole number.
const standvirtualEngineFrom = 'search[filter_float_engine_capacity:from]';
const standvirtualEngineTo = 'search[filter_float_engine_capacity:to]';

/// The engine-size search beside a Standvirtual word search inside a model
/// filter ("/motos/honda/cbr/q-650"): the words find only the ads whose
/// version spells them, and many CBR650R ads are titled "Honda CBR" with
/// the version empty (2026-11-12: 1 ad for "q-650", 8 for CBR at 640-660
/// cc). The engine size finds those, but not an ad that leaves it empty,
/// so both are read. Null when [base] is not such a search or one of
/// [entries] has no engine limits.
Uri? standvirtualEngineSearch(Uri base, List<CatalogEntry> entries) {
  final segments = base.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 4 || !segments.last.startsWith('q-')) return null;
  if (entries.any((e) => e.engineCcMin == null || e.engineCcMax == null)) {
    return null;
  }
  return base.replace(
    pathSegments: segments.take(3),
    queryParameters: {
      ...base.queryParameters,
      standvirtualEngineFrom:
          '${entries.map((e) => e.engineCcMin!).reduce(_min)}',
      standvirtualEngineTo:
          '${entries.map((e) => e.engineCcMax!).reduce(_max)}',
    },
  );
}

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
/// them: [olxEngineBand]; on Standvirtual, a word search inside a model
/// filter is followed by its engine-size search, [standvirtualEngineSearch]).
/// Unusable addresses are left out and reported in `problems`.
({List<PlannedSearch> searches, List<String> problems}) planSearches(
  Catalog catalog,
  FetchSite site,
) {
  final groups = <String, (Uri, List<CatalogEntry>)>{};
  final problems = <String>[];

  for (final entry in catalog.entries) {
    final raw = site == .olx
        ? entry.olxSearch
        : site == .standvirtual
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

  // Searches with the same address (an engine-size search can repeat
  // another) are read once, for all their models.
  final searches = <String, (Uri, List<String>)>{};
  void add(Uri url, List<CatalogEntry> entries) {
    final models = searches.putIfAbsent(url.toString(), () => (url, [])).$2;
    for (final e in entries) {
      final name = '${e.brand} ${e.model}';
      if (!models.contains(name)) models.add(name);
    }
  }

  for (final (base, entries) in groups.values) {
    final yearFrom = '${entries.map((e) => e.minYear).reduce(_min)}';
    add(
      base.replace(
        queryParameters: {
          ...base.queryParameters,
          site == .olx ? olxYearFrom : standvirtualYearFrom: yearFrom,
          if (site == .olx) olxEngineSize: ?olxEngineBand(entries),
        },
      ),
      entries,
    );
    if (site == .standvirtual) {
      final engine = standvirtualEngineSearch(base, entries);
      if (engine != null) {
        add(
          engine.replace(
            queryParameters: {
              ...engine.queryParameters,
              standvirtualYearFrom: yearFrom,
            },
          ),
          entries,
        );
      }
    }
  }

  return (
    searches: [
      for (final (url, models) in searches.values) PlannedSearch(url, models),
    ],
    problems: problems,
  );
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;

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
