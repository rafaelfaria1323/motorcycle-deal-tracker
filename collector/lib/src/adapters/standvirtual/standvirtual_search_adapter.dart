import 'dart:convert';
import 'dart:io';

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
  });

  final List<StandvirtualRawListing> records;

  /// Results on the page that could not be read.
  final List<String> problems;

  /// How many listings the whole search has, according to the site.
  final int total;
  final int offset;

  /// How many results this page holds.
  final int shown;

  bool get isComplete => offset + shown >= total;
}

/// Reads search results pages (saved by `make fetch` or by hand) out of a
/// folder. One page lists a whole model, so no listing pages are needed.
class StandvirtualSearchAdapter implements SourceAdapter<StandvirtualRawListing> {
  StandvirtualSearchAdapter(this.directory, {this.maxAge = const Duration(hours: 48)});

  final String directory;

  /// Older pages are reported, so a removal run is never based on them.
  final Duration maxAge;

  @override
  String get source => 'standvirtual';

  @override
  Future<ParseResult<StandvirtualRawListing>> read() async {
    final dir = Directory(directory);
    if (!await dir.exists()) {
      throw FileSystemException('Folder not found', directory);
    }

    final files =
        (await dir.list().toList()).whereType<File>().where((f) => f.path.toLowerCase().endsWith('.html')).toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final records = <StandvirtualRawListing>[];
    final issues = <ParseIssue>[];

    for (var i = 0; i < files.length; i++) {
      final name = files[i].uri.pathSegments.last;
      try {
        final bytes = await files[i].readAsBytes();
        final page = parseSearchPage(utf8.decode(bytes, allowMalformed: true));
        records.addAll(page.records);

        for (final problem in page.problems) {
          issues.add(ParseIssue(i, '$name: $problem'));
        }
        if (!page.isComplete) {
          issues.add(
            ParseIssue(
              i,
              '$name: holds ${page.offset + page.shown} of ${page.total} '
              'listings (more pages exist and were not read)',
            ),
          );
        }
        final age = DateTime.now().difference(await files[i].lastModified());
        if (age > maxAge) {
          issues.add(
            ParseIssue(
              i,
              '$name: saved ${age.inHours} h ago (older than '
              '${maxAge.inHours} h), so it may be out of date',
            ),
          );
        }
      } on FormatException catch (e) {
        issues.add(ParseIssue(i, '$name: ${e.message}'));
      }
    }
    return ParseResult(records, issues);
  }

  static final _nextData = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true);

  /// Pure parsing step, so it can be tested without files.
  /// Throws [FormatException] when the page is not a search results page.
  StandvirtualSearchPage parseSearchPage(String html) {
    final match = _nextData.firstMatch(html);
    if (match == null) {
      throw const FormatException('no __NEXT_DATA__ block');
    }

    final Object? data;
    try {
      data = jsonDecode(match.group(1)!);
    } on FormatException {
      throw const FormatException('__NEXT_DATA__ is not valid JSON');
    }

    final urql = _map(_map(_map(data)?['props'])?['pageProps'])?['urqlState'];
    if (urql is! Map<String, dynamic>) {
      throw const FormatException('no search data (is this a search page?)');
    }

    // The search results are one cache entry among several; its payload is
    // JSON inside JSON.
    Map<String, dynamic>? search;
    for (final entry in urql.values) {
      Object? payload = _map(entry)?['data'];
      if (payload is String) {
        try {
          payload = jsonDecode(payload);
        } on FormatException {
          continue;
        }
      }
      final found = _map(_map(payload)?['advertSearch']);
      if (found != null) {
        search = found;
        break;
      }
    }
    if (search == null) {
      throw const FormatException('no search results found in the page');
    }

    final edges = search['edges'];
    if (edges is! List) {
      throw const FormatException('search results have no listings list');
    }
    final topAds = search['topads'] is List ? search['topads'] as List : [];

    final records = <StandvirtualRawListing>[];
    final problems = <String>[];
    for (final edge in edges) {
      final node = _map(_map(edge)?['node']);
      if (node == null) {
        problems.add('a result had no data');
        continue;
      }
      try {
        records.add(_fromNode(node));
      } on FormatException catch (e) {
        problems.add(e.message);
      }
    }

    return StandvirtualSearchPage(
      records: records,
      problems: problems,
      total: _int(search['totalCount']) ?? edges.length,
      offset: _int(_map(search['pageInfo'])?['currentOffset']) ?? 0,
      shown: edges.length + topAds.length,
    );
  }
}

StandvirtualRawListing _fromNode(Map<String, dynamic> node) {
  final id = node['id']?.toString();
  final url = node['url'];
  if (id == null || id.isEmpty || url is! String) {
    throw const FormatException('a result has no id or url');
  }

  final params = <String, Map<String, dynamic>>{};
  final list = node['parameters'];
  if (list is List) {
    for (final p in list) {
      final map = _map(p);
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

  final amount = _map(_map(node['price'])?['amount']);
  final price = num.tryParse('${amount?['value']}');
  if (price == null) throw FormatException('$id: no price');

  final sellerName = _map(node['sellerLink'])?['name'];
  final thumbnail = _map(node['thumbnail'])?['x2'];

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
    year: int.tryParse(value('first_registration_year') ?? ''),
    mileageKm: int.tryParse(value('mileage') ?? ''),
    engineCc: int.tryParse(value('engine_capacity') ?? ''),
    sellerType: switch (_map(node['seller'])?['__typename']) {
      'ProfessionalSeller' => 'dealer',
      'PrivateSeller' => 'private',
      _ => null,
    },
    sellerName: sellerName is String ? sellerName : null,
    location: _location(_map(node['location'])),
    images: [if (thumbnail is String) thumbnail],
  );
}

/// The city, unless the site spells out a long list of parishes; then the
/// district.
String? _location(Map<String, dynamic>? location) {
  final city = _map(location?['city'])?['name'];
  final region = _map(location?['region'])?['name'];
  if (city is String && city.isNotEmpty && !city.contains(',')) return city;
  if (region is String && region.isNotEmpty) return region;
  return city is String && city.isNotEmpty ? city : null;
}

Map<String, dynamic>? _map(Object? o) => o is Map<String, dynamic> ? o : null;

int? _int(Object? o) => o is num ? o.toInt() : null;
