import 'dart:convert';
import 'dart:io';

import '../../normalized/normalized_listing.dart';
import '../../normalized/normalizers.dart';
import '../../fetch/search_manifest.dart';
import '../json_blob.dart';
import '../json_values.dart';
import '../site_model.dart';
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
    this.models = const [],
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

  /// The models OLX offers for the page's brand.
  final List<SiteModel> models;
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
    final manifest = await SearchManifest.readFrom(directory);
    final recordSearches = <String?>[];

    final records = <OlxRawListing>[];
    final issues = <ParseIssue>[];
    final models = <SiteModel>[];
    final pagesBySearch = <String, Set<int>>{};
    final totalPages = <String, int>{};
    final firstFile = <String, int>{};
    final manifestSearch = <String, String?>{};

    for (var i = 0; i < files.length; i++) {
      final name = files[i].uri.pathSegments.last;
      final search = manifest?.files[name];
      try {
        final bytes = await files[i].readAsBytes();
        final page = parseSearchPage(utf8.decode(bytes, allowMalformed: true));
        records.addAll(page.records);
        recordSearches.addAll([for (final _ in page.records) search]);
        models.addAll(page.models);
        (pagesBySearch[page.search] ??= {}).add(page.pageNumber);
        totalPages[page.search] = page.totalPages;
        firstFile.putIfAbsent(page.search, () => i);
        manifestSearch.putIfAbsent(page.search, () => search);

        for (final problem in page.problems) {
          issues.add(ParseIssue(i, '$name: $problem', search: search));
        }
        final age = DateTime.now().difference(await files[i].lastModified());
        if (age > maxAge) {
          issues.add(
            ParseIssue(
              i,
              '$name: saved ${age.inHours} h ago (older than '
              '${maxAge.inHours} h), so it may be out of date',
              search: search,
            ),
          );
        }
      } on FormatException catch (e) {
        issues.add(ParseIssue(i, '$name: ${e.message}', search: search));
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
            search: manifestSearch[search],
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
    final state = extractJsonBlob(
      html,
      _state,
      '__PRERENDERED_STATE__',
      quoted: true,
    );

    final listing = asMap(asMap(asMap(state)?['listing'])?['listing']);
    final ads = listing?['ads'];
    if (listing == null || ads is! List) {
      throw const FormatException('not a search results page');
    }

    final request = asMap(listing['requestParams']);
    final categoryPath = '${request?['categoryPath'] ?? ''}';
    final filters = asMap(request?['params']) ?? const {};
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
        final map = asMap(ad);
        if (map == null) throw const FormatException('a result is not an ad');
        records.add(_fromAd(map, brand));
      } on FormatException catch (e) {
        problems.add(e.message);
      }
    }

    return OlxSearchPage(
      search: search,
      pageNumber: asInt(listing['pageNumber']) ?? 0,
      totalPages: asInt(listing['totalPages']) ?? 1,
      total: asInt(listing['totalElements']) ?? ads.length,
      records: records,
      problems: problems,
      models: olxSiteModels(listing, brand),
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
      final map = asMap(p);
      final key = map?['key'];
      if (key is String) params[key] = map!;
    }
  }
  String? value(String key) => params[key]?['value']?.toString();
  String? normalized(String key) => params[key]?['normalizedValue']?.toString();

  // Trade-only and "price on request" ads have no price; the mapper
  // rejects them, but they are still live listings.
  final regular = asMap(asMap(ad['price'])?['regularPrice']);
  final price = regular?['value'];

  final user = asMap(ad['user']);
  final company = '${user?['company_name'] ?? ''}'.trim();
  final userName = '${user?['name'] ?? ''}'.trim();
  // Some business accounts are named "Particular": they are private sellers.
  final isBusiness =
      ad['isBusiness'] == true &&
      parseSellerType(company.isNotEmpty ? company : userName) !=
          SellerType.private;

  final location = asMap(ad['location']);
  final city = location?['cityName'];
  final region = location?['regionName'];

  final partner = '${asMap(ad['partner'])?['code'] ?? ''}';
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
    createdAt: asTime(ad['createdTime']),
    refreshedAt: asTime(ad['lastRefreshTime']),
  );
}
