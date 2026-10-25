import 'dart:convert';

import '../../normalized/listing_details.dart';
import '../../normalized/normalizers.dart';
import '../json_blob.dart';
import '../json_values.dart';
import '../saved_pages.dart';
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
    final files = await listHtmlFiles(directory);

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

  /// The listing object inside the page.
  /// Throws [FormatException] when the page is not a listing page.
  Map<String, dynamic> _advert(String html) {
    final data = extractNextData(
      html,
      hint: ' (is this a Standvirtual listing page?)',
    );

    final advert = asMap(asMap(asMap(data)?['props'])?['pageProps'])?['advert'];
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

    final params = asMap(advert['parametersDict']) ?? const {};
    final brand = _label(params, 'make');
    final model = _label(params, 'model');
    if (brand == null || model == null) {
      throw const FormatException('listing has no make or model');
    }

    final price = asMap(advert['price']);
    final priceValue = num.tryParse('${price?['value']}');
    if (priceValue == null) {
      throw const FormatException('listing has no price');
    }

    final seller = asMap(advert['seller']);

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

    final params = asMap(advert['parametersDict']) ?? const {};
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
      siteColour: _value(params, 'color') ?? _label(params, 'color'),
      images: _images(advert['images']),
    );
  }
}

Map<String, dynamic>? _first(Map<String, dynamic> params, String key) {
  final values = asMap(params[key])?['values'];
  if (values is List && values.isNotEmpty) return asMap(values.first);
  return null;
}

String? _value(Map<String, dynamic> params, String key) =>
    _first(params, key)?['value']?.toString();

String? _label(Map<String, dynamic> params, String key) =>
    _first(params, key)?['label']?.toString();

/// The dealer's municipality ("concelho X"), falling back to the city text.
String? _location(Map<String, dynamic>? seller) {
  final location = asMap(seller?['location']);
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
  final photos = asMap(images)?['photos'];
  if (photos is! List) return const [];
  return cleanImages([
    for (final p in photos)
      if (asMap(p)?['url'] is String) asMap(p)!['url'] as String,
  ]).take(maxImages).toList();
}
