import 'dart:convert';
import 'dart:io';

import '../source_adapter.dart';
import 'standvirtual_raw_listing.dart';

/// Reads listing pages saved from the browser (File > Save, "HTML only") out of
/// a folder. Nothing is requested from the website: the files are all it sees.
class StandvirtualPageAdapter implements SourceAdapter<StandvirtualRawListing> {
  StandvirtualPageAdapter(this.directory);

  final String directory;

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
        records.add(parsePage(utf8.decode(bytes, allowMalformed: true)));
      } on FormatException catch (e) {
        issues.add(ParseIssue(i, '$name: ${e.message}'));
      }
    }
    return ParseResult(records, issues);
  }

  static final _nextData = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true);

  /// Pure parsing step, so it can be tested without files.
  /// Throws [FormatException] when the page is not a listing page.
  StandvirtualRawListing parsePage(String html) {
    final match = _nextData.firstMatch(html);
    if (match == null) {
      throw const FormatException('no __NEXT_DATA__ block (is this a Standvirtual listing page?)');
    }

    final Object? data;
    try {
      data = jsonDecode(match.group(1)!);
    } on FormatException {
      throw const FormatException('__NEXT_DATA__ is not valid JSON');
    }

    final advert = _map(_map(_map(data)?['props'])?['pageProps'])?['advert'];
    if (advert is! Map<String, dynamic>) {
      throw const FormatException('no listing data (a search page, or a removed listing?)');
    }

    final id = advert['id']?.toString();
    final url = advert['url'];
    if (id == null || id.isEmpty || url is! String) {
      throw const FormatException('listing has no id or url');
    }

    final params = _map(advert['parametersDict']) ?? const {};
    final brand = _label(params, 'make');
    final model = _label(params, 'model');
    if (brand == null || model == null) {
      throw const FormatException('listing has no make or model');
    }

    final price = _map(advert['price']);
    final priceValue = num.tryParse('${price?['value']}');
    if (priceValue == null) {
      throw const FormatException('listing has no price');
    }

    final seller = _map(advert['seller']);

    return StandvirtualRawListing(
      id: id,
      url: url,
      status: '${advert['status']}',
      brand: brand,
      model: model,
      version: _label(params, 'version'),
      price: priceValue,
      currency: '${price?['currency']}',
      year: int.tryParse(_value(params, 'first_registration_year') ?? ''),
      mileageKm: int.tryParse(_value(params, 'mileage') ?? ''),
      engineCc: int.tryParse(_value(params, 'engine_capacity') ?? ''),
      sellerType: switch (seller?['type']) {
        'PROFESSIONAL' => 'dealer',
        'PRIVATE' => 'private',
        _ => null,
      },
      sellerName: seller?['name'] as String?,
      location: _location(seller),
      description: _cleanDescription(advert['description']),
      images: _images(advert['images']),
    );
  }
}

Map<String, dynamic>? _map(Object? o) => o is Map<String, dynamic> ? o : null;

Map<String, dynamic>? _first(Map<String, dynamic> params, String key) {
  final values = _map(params[key])?['values'];
  if (values is List && values.isNotEmpty) return _map(values.first);
  return null;
}

String? _value(Map<String, dynamic> params, String key) => _first(params, key)?['value']?.toString();

String? _label(Map<String, dynamic> params, String key) => _first(params, key)?['label']?.toString();

/// The dealer's municipality ("concelho X"), falling back to the city text.
String? _location(Map<String, dynamic>? seller) {
  final location = _map(seller?['location']);
  if (location == null) return null;
  final short = location['shortAddress'];
  if (short is String) {
    final m = RegExp(r'concelho ([^(]+)\(').firstMatch(short);
    if (m != null) return m.group(1)!.trim();
  }
  final city = location['city'];
  return city is String && city.trim().isNotEmpty ? city.trim() : null;
}

List<String> _images(Object? images) {
  final photos = _map(images)?['photos'];
  if (photos is! List) return const [];
  return [
    for (final p in photos)
      if (_map(p)?['url'] is String) _map(p)!['url'] as String,
  ].take(10).toList();
}

// Text dealers' systems add to every ad. Left in, it makes unrelated bikes
// from one dealer look like duplicates of each other.
const _boilerplate = ['A informação disponibilizada', 'Anúncio introduzido por rotina informática'];

String? _cleanDescription(Object? html) {
  if (html is! String) return null;
  final text = html
      .replaceAll(RegExp(r'<br\s*/?>|</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !_boilerplate.any(l.contains))
      .toList();
  return lines.isEmpty ? null : lines.join('\n');
}
