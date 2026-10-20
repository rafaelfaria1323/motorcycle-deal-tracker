import 'dart:convert';

import '../../fetch/search_manifest.dart';
import '../json_blob.dart';
import '../json_values.dart';
import '../site_model.dart';
import '../saved_pages.dart';
import '../source_adapter.dart';
import 'standvirtual_raw_listing.dart';

/// One parsed search results page.
class StandvirtualSearchPage {
  const StandvirtualSearchPage({
    required this.records,
    required this.problems,
    required this.total,
    required this.offset,
    required this.shown,
    this.pageSize = 32,
    this.models = const [],
  });

  final List<StandvirtualRawListing> records;

  /// Results on the page that could not be read.
  final List<String> problems;

  /// How many listings the whole search has, according to the site.
  final int total;
  final int offset;

  /// How many results this page holds.
  final int shown;

  /// How many results a page of this search holds.
  final int pageSize;

  /// The brands and models in the page's filters.
  final List<SiteModel> models;

  bool get isComplete => offset + shown >= total;

  /// How many pages the whole search spans.
  int get totalPages => total <= 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
}

/// Reads search results pages (saved by `make fetch` or by hand) out of a
/// folder. The pages hold everything but the description, so listing pages
/// are only read for details; a search over 32 listings spans pages
/// (`?page=N`), all of which must be saved for it to count as read.
class StandvirtualSearchAdapter
    implements SourceAdapter<StandvirtualRawListing> {
  StandvirtualSearchAdapter(
    this.directory, {
    this.maxAge = const Duration(hours: 48),
  });

  final String directory;

  /// Older pages are reported, so a removal run is never based on them.
  final Duration maxAge;

  @override
  String get source => 'standvirtual';

  @override
  Future<ParseResult<StandvirtualRawListing>> read() async {
    final files = await listHtmlFiles(directory);
    final manifest = await SearchManifest.readFrom(directory);
    final recordSearches = <String?>[];

    final records = <StandvirtualRawListing>[];
    final issues = <ParseIssue>[];
    final models = <SiteModel>[];
    // Per search (the manifest's, or the file's own without one): listings
    // the site says it has, listings on the pages saved, and the first file.
    final totals = <String, int>{};
    final shown = <String, int>{};
    final firstFile = <String, (int, String, String?)>{};

    for (var i = 0; i < files.length; i++) {
      final name = files[i].uri.pathSegments.last;
      final search = manifest?.files[name];
      try {
        final bytes = await files[i].readAsBytes();
        final page = parseSearchPage(utf8.decode(bytes, allowMalformed: true));
        records.addAll(page.records);
        recordSearches.addAll([for (final _ in page.records) search]);
        models.addAll(page.models);

        for (final problem in page.problems) {
          issues.add(ParseIssue(i, '$name: $problem', search: search));
        }
        final key = search ?? name;
        totals[key] = page.total;
        shown[key] = (shown[key] ?? 0) + page.shown;
        firstFile.putIfAbsent(key, () => (i, name, search));
        final age = DateTime.now().difference(await files[i].lastModified());
        final stale = staleIssue(i, name, age, maxAge, search: search);
        if (stale != null) issues.add(stale);
      } on FormatException catch (e) {
        issues.add(ParseIssue(i, '$name: ${e.message}', search: search));
      }
    }
    for (final MapEntry(:key, value: (i, name, search)) in firstFile.entries) {
      final held = shown[key]!;
      if (held < totals[key]!) {
        issues.add(
          ParseIssue(
            i,
            '$name: holds $held of ${totals[key]} listings (more pages '
            'exist and were not read)',
            search: search,
          ),
        );
      }
    }
    return ParseResult(
      records,
      issues,
      recordSearches: manifest == null ? null : recordSearches,
      manifest: manifest,
      siteModels: uniqueSiteModels(models),
    );
  }

  /// Page [page] of [search].
  static Uri pageUrl(Uri search, int page) => search.replace(
    queryParameters: {...search.queryParameters, 'page': '$page'},
  );

  /// Pure parsing step, so it can be tested without files.
  /// Throws [FormatException] when the page is not a search results page.
  StandvirtualSearchPage parseSearchPage(String html) {
    final data = extractJsonBlob(html, nextDataBlock, '__NEXT_DATA__');

    final urql = asMap(
      asMap(asMap(data)?['props'])?['pageProps'],
    )?['urqlState'];
    if (urql is! Map<String, dynamic>) {
      throw const FormatException('no search data (is this a search page?)');
    }

    // The search results are one cache entry among several (the filters,
    // with the brand and model lists, are another); its payload is JSON
    // inside JSON.
    Map<String, dynamic>? search;
    var models = const <SiteModel>[];
    for (final entry in urql.values) {
      Object? payload = asMap(entry)?['data'];
      if (payload is String) {
        try {
          payload = jsonDecode(payload);
        } on FormatException {
          continue;
        }
      }
      search ??= asMap(asMap(payload)?['advertSearch']);
      if (asMap(asMap(payload)?['filters']) case final filters?
          when models.isEmpty) {
        models = standvirtualSiteModels(filters);
      }
    }
    if (search == null) {
      throw const FormatException('no search results found in the page');
    }

    final edges = search['edges'];
    if (edges is! List) {
      throw const FormatException('search results have no listings list');
    }
    final topAds = search['topads'] is List
        ? search['topads'] as List
        : const <Object?>[];

    final records = <StandvirtualRawListing>[];
    final problems = <String>[];
    for (final edge in edges) {
      final node = asMap(asMap(edge)?['node']);
      final bump = asMap(asMap(edge)?['vas'])?['bumpDate'];
      if (node == null) {
        problems.add('a result had no data');
        continue;
      }
      try {
        records.add(_fromNode(node, bumpDate: bump));
      } on FormatException catch (e) {
        problems.add(e.message);
      }
    }

    return StandvirtualSearchPage(
      records: records,
      problems: problems,
      total: asInt(search['totalCount']) ?? edges.length,
      offset: asInt(asMap(search['pageInfo'])?['currentOffset']) ?? 0,
      shown: edges.length + topAds.length,
      pageSize: asInt(asMap(search['pageInfo'])?['pageSize']) ?? 32,
      models: models,
    );
  }
}

StandvirtualRawListing _fromNode(
  Map<String, dynamic> node, {
  Object? bumpDate,
}) {
  final id = node['id']?.toString();
  final url = node['url'];
  if (id == null || id.isEmpty || url is! String) {
    throw const FormatException('a result has no id or url');
  }

  final params = <String, Map<String, dynamic>>{};
  final list = node['parameters'];
  if (list is List) {
    for (final p in list) {
      final map = asMap(p);
      final key = map?['key'];
      if (key is String) params[key] = map!;
    }
  }
  String? display(String key) => params[key]?['displayValue']?.toString();
  String? value(String key) => params[key]?['value']?.toString();

  final brand = display('make');
  final model = display('model');
  if (brand == null || model == null) {
    throw FormatException('$id: no make or model');
  }

  final amount = asMap(asMap(node['price'])?['amount']);
  final price = num.tryParse('${amount?['value']}');
  if (price == null) throw FormatException('$id: no price');

  final sellerName = asMap(node['sellerLink'])?['name'];
  final thumbnail = asMap(node['thumbnail'])?['x2'];

  return StandvirtualRawListing(
    id: id,
    url: url,
    status: 'ACTIVE',
    // only live listings are shown in a search
    brand: brand,
    model: model,
    version: display('version'),
    price: price,
    currency: '${amount?['currencyCode']}',
    priceBeforeDrop: priceBeforeDrop(node['priceDrop'], price),
    year: int.tryParse(value('first_registration_year') ?? ''),
    mileageKm: int.tryParse(value('mileage') ?? ''),
    engineCc: int.tryParse(value('engine_capacity') ?? ''),
    sellerType: switch (asMap(node['seller'])?['__typename']) {
      'ProfessionalSeller' => 'dealer',
      'PrivateSeller' => 'private',
      _ => null,
    },
    sellerName: sellerName is String ? sellerName : null,
    location: _location(asMap(node['location'])),
    images: [if (thumbnail is String) thumbnail],
    createdAt: asTime(node['createdAt']),
    bumpedAt: asTime(bumpDate),
  );
}

/// The city, unless the site spells out a long list of parishes; then the
/// district.
String? _location(Map<String, dynamic>? location) {
  final city = asMap(location?['city'])?['name'];
  final region = asMap(location?['region'])?['name'];
  if (city is String && city.isNotEmpty && !city.contains(',')) return city;
  if (region is String && region.isNotEmpty) return region;
  return city is String && city.isNotEmpty ? city : null;
}
