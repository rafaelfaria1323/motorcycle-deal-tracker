import 'dart:convert';
import 'dart:io';

import '../../normalized/listing_details.dart';
import '../../normalized/normalizers.dart';
import '../source_adapter.dart';
import 'standvirtual_mapper.dart';
import 'standvirtual_raw_listing.dart';

/// Reads listing pages saved from the browser (File > Save, "HTML only") out of
/// a folder, and parses listing pages fetched for their details.
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
        (await dir.list().toList())
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.html'))
            .toList()
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

  static final _nextData = RegExp(
    r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
    dotAll: true,
  );

  /// The listing object inside the page.
  /// Throws [FormatException] when the page is not a listing page.
  Map<String, dynamic> _advert(String html) {
    final match = _nextData.firstMatch(html);
    if (match == null) {
      throw const FormatException(
        'no __NEXT_DATA__ block (is this a Standvirtual listing page?)',
      );
    }

    final Object? data;
    try {
      data = jsonDecode(match.group(1)!);
    } on FormatException {
      throw const FormatException('__NEXT_DATA__ is not valid JSON');
    }

    final advert = _map(_map(_map(data)?['props'])?['pageProps'])?['advert'];
    if (advert is! Map<String, dynamic>) {
      throw const FormatException(
        'no listing data (a search page, or a removed listing?)',
      );
    }
    return advert;
  }

  /// Pure parsing step, so it can be tested without files.
  StandvirtualRawListing parsePage(String html) {
    final advert = _advert(html);

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
      priceBeforeDrop: priceBeforeDrop(advert['priceDrop'], priceValue),
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
      description: cleanDescription(advert['description']),
      images: _images(advert['images']),
    );
  }

  /// The facts a listing page adds to a listing stored from a search.
  ListingDetails parseDetails(String html) {
    final advert = _advert(html);

    final id = advert['id']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('listing has no id');
    }

    final params = _map(advert['parametersDict']) ?? const {};
    final warranty = _value(params, 'maker_warranty_valid_until_date');
    final published = advert['originalCreatedAt'] ?? advert['createdAt'];

    return ListingDetails(
      sourceListingId: StandvirtualMapper.listingId(id),
      description: cleanDescription(advert['description']),
      registrations: int.tryParse(
        _value(params, 'number_of_registrations') ?? '',
      ),
      serviceBook: switch (_value(params, 'complete_review_book')) {
        '1' => true,
        '0' => false,
        _ => null,
      },
      origin: _value(params, 'origin'),
      warrantyUntil:
          warranty != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(warranty)
          ? warranty
          : null,
      dealerWarrantyMonths: int.tryParse(
        _value(params, 'vendors_warranty_valid_until_date') ?? '',
      ),
      publishedAt: published is String ? published : null,
    );
  }
}

Map<String, dynamic>? _map(Object? o) => o is Map<String, dynamic> ? o : null;

Map<String, dynamic>? _first(Map<String, dynamic> params, String key) {
  final values = _map(params[key])?['values'];
  if (values is List && values.isNotEmpty) return _map(values.first);
  return null;
}

String? _value(Map<String, dynamic> params, String key) =>
    _first(params, key)?['value']?.toString();

String? _label(Map<String, dynamic> params, String key) =>
    _first(params, key)?['label']?.toString();

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
