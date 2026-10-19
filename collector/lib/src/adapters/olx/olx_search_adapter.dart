import 'dart:convert';
import 'dart:io';

import '../../normalized/normalized_listing.dart';
import '../../normalized/normalizers.dart';
import '../source_adapter.dart';
import 'olx_raw_listing.dart';

/// One parsed OLX search results page.
class OlxSearchPage {
  const OlxSearchPage({
    required this.search,
    required this.pageNumber,
    required this.totalPages,
    required this.total,
    required this.records,
    required this.problems,
  });

  /// What was searched (category and filters, without the page), so the
  /// pages of one search can be put together.
  final String search;
  final int pageNumber;
  final int totalPages;

  /// How many listings the whole search has, according to the site.
  final int total;
  final List<OlxRawListing> records;

  /// Results on the page that could not be read.
  final List<String> problems;
}

/// Reads OLX search results pages (saved by `make fetch` or by hand) out of
/// a folder. Results carry the full description, so no listing pages are
/// needed. A search spans several pages; it counts as complete only when
/// all of them are in the folder.
class OlxSearchAdapter implements SourceAdapter<OlxRawListing> {
  OlxSearchAdapter(this.directory, {this.maxAge = const Duration(hours: 48)});

  static const sourceId = 'olx';

  final String directory;

  /// Older pages are reported, so a removal run is never based on them.
  final Duration maxAge;

  @override
  String get source => sourceId;

  @override
  Future<ParseResult<OlxRawListing>> read() async {
    final dir = Directory(directory);
    if (!await dir.exists()) {
      throw FileSystemException('Folder not found', directory);
    }

    final files =
        (await dir.list().toList())
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.html'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final records = <OlxRawListing>[];
    final issues = <ParseIssue>[];
    final pagesBySearch = <String, Set<int>>{};
    final totalPages = <String, int>{};
    final firstFile = <String, int>{};

    for (var i = 0; i < files.length; i++) {
      final name = files[i].uri.pathSegments.last;
      try {
        final bytes = await files[i].readAsBytes();
        final page = parseSearchPage(utf8.decode(bytes, allowMalformed: true));
        records.addAll(page.records);
        (pagesBySearch[page.search] ??= {}).add(page.pageNumber);
        totalPages[page.search] = page.totalPages;
        firstFile.putIfAbsent(page.search, () => i);

        for (final problem in page.problems) {
          issues.add(ParseIssue(i, '$name: $problem'));
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

    for (final MapEntry(key: search, value: pages) in pagesBySearch.entries) {
      final expected = totalPages[search]!;
      if (pages.length < expected) {
        issues.add(
          ParseIssue(
            firstFile[search]!,
            '$search: ${pages.length} of $expected page(s) saved '
            '(the others were not read)',
          ),
        );
      }
    }
    return ParseResult(records, issues);
  }

  /// The address of page [page] of a search (the first page has none).
  static Uri pageUrl(Uri search, int page) => search.replace(
    queryParameters: {...search.queryParameters, 'page': '$page'},
  );

  static final _state = RegExp(
    r'window\.__PRERENDERED_STATE__\s*=\s*("(?:[^"\\]|\\.)*")',
  );

  /// Pure parsing step, so it can be tested without files.
  /// Throws [FormatException] when the page is not a search results page.
  OlxSearchPage parseSearchPage(String html) {
    final match = _state.firstMatch(html);
    if (match == null) {
      throw const FormatException('no __PRERENDERED_STATE__ block');
    }

    final Object? state;
    try {
      state = jsonDecode(jsonDecode(match.group(1)!) as String);
    } on Object {
      throw const FormatException('__PRERENDERED_STATE__ is not valid JSON');
    }

    final listing = _map(_map(_map(state)?['listing'])?['listing']);
    final ads = listing?['ads'];
    if (listing == null || ads is! List) {
      throw const FormatException('not a search results page');
    }

    final request = _map(listing['requestParams']);
    final categoryPath = '${request?['categoryPath'] ?? ''}';
    final filters = _map(request?['params']) ?? const {};
    final search = [
      categoryPath,
      for (final key in filters.keys.toList()..sort())
        if (key != 'page') '$key=${filters[key]}',
    ].join(' ');

    final brand = categoryPath.split('/').length > 2
        ? categoryPath.split('/').last
        : null;

    final records = <OlxRawListing>[];
    final problems = <String>[];
    for (final ad in ads) {
      try {
        final map = _map(ad);
        if (map == null) throw const FormatException('a result is not an ad');
        records.add(_fromAd(map, brand));
      } on FormatException catch (e) {
        problems.add(e.message);
      }
    }

    return OlxSearchPage(
      search: search,
      pageNumber: _int(listing['pageNumber']) ?? 0,
      totalPages: _int(listing['totalPages']) ?? 1,
      total: _int(listing['totalElements']) ?? ads.length,
      records: records,
      problems: problems,
    );
  }
}

OlxRawListing _fromAd(Map<String, dynamic> ad, String? brand) {
  final id = ad['id']?.toString();
  final url = ad['url'];
  if (id == null || id.isEmpty || url is! String) {
    throw const FormatException('a result has no id or url');
  }

  final params = <String, Map<String, dynamic>>{};
  final list = ad['params'];
  if (list is List) {
    for (final p in list) {
      final map = _map(p);
      final key = map?['key'];
      if (key is String) params[key] = map!;
    }
  }
  String? value(String key) => params[key]?['value']?.toString();
  String? normalized(String key) => params[key]?['normalizedValue']?.toString();

  // Trade-only and "price on request" ads have no price; the mapper
  // rejects them, but they are still live listings.
  final regular = _map(_map(ad['price'])?['regularPrice']);
  final price = regular?['value'];

  final user = _map(ad['user']);
  final company = '${user?['company_name'] ?? ''}'.trim();
  final userName = '${user?['name'] ?? ''}'.trim();
  // Some business accounts are named "Particular": they are private sellers.
  final isBusiness =
      ad['isBusiness'] == true &&
      parseSellerType(company.isNotEmpty ? company : userName) !=
          SellerType.private;

  final location = _map(ad['location']);
  final city = location?['cityName'];
  final region = location?['regionName'];

  final partner = '${_map(ad['partner'])?['code'] ?? ''}';
  final external = ad['externalUrl'];
  final photos = ad['photos'];

  return OlxRawListing(
    id: id,
    url: url,
    status: '${ad['status']}',
    title: '${ad['title'] ?? ''}',
    price: price is num ? price : null,
    currency: '${regular?['currencyCode']}',
    categoryBrand: brand,
    model: value('modelo'),
    year: int.tryParse(normalized('year') ?? ''),
    mileageKm: int.tryParse(normalized('quilometros') ?? ''),
    isBusiness: isBusiness,
    businessName: !isBusiness
        ? null
        : company.isNotEmpty
        ? company
        : (userName.isEmpty ? null : userName),
    location: city is String && city.isNotEmpty
        ? city
        : (region is String && region.isNotEmpty ? region : null),
    description: cleanDescription(ad['description']),
    partner: partner.isEmpty ? null : partner,
    externalUrl: external is String && external.isNotEmpty ? external : null,
    images: [
      if (photos is List)
        for (final p in photos.take(10))
          if (p is String) p,
    ],
  );
}

Map<String, dynamic>? _map(Object? o) => o is Map<String, dynamic> ? o : null;

int? _int(Object? o) => o is num ? o.toInt() : null;
