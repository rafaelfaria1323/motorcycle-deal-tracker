/// A listing exactly as written in a manual import file.
class ManualRawListing {
  const ManualRawListing({
    required this.url,
    required this.brand,
    required this.model,
    required this.priceEur,
    this.variant,
    this.year,
    this.mileageKm,
    this.sellerType,
    this.sellerName,
    this.location,
    this.description,
    this.images = const [],
  });

  /// Throws [FormatException] when the record is malformed.
  factory ManualRawListing.fromJson(Map<String, dynamic> json) {
    final url = _requiredString(json, 'url');
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      throw FormatException('"url" must be an http(s) link');
    }

    return ManualRawListing(
      url: url,
      brand: _requiredString(json, 'brand'),
      model: _requiredString(json, 'model'),
      priceEur: _requiredNumber(json, 'price_eur'),
      variant: _optionalString(json, 'variant'),
      year: _optionalInt(json, 'year'),
      mileageKm: _optionalInt(json, 'mileage_km'),
      sellerType: _optionalString(json, 'seller_type'),
      sellerName: _optionalString(json, 'seller_name'),
      location: _optionalString(json, 'location'),
      description: _optionalString(json, 'description'),
      images: _stringList(json, 'images'),
    );
  }

  final String url;
  final String brand;
  final String model;
  final num priceEur;
  final String? variant;
  final int? year;
  final int? mileageKm;
  final String? sellerType;
  final String? sellerName;
  final String? location;
  final String? description;
  final List<String> images;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('"$key" is required and must be a non-empty string');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  throw FormatException('"$key" must be a string');
}

num _requiredNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value >= 0) return value;
  throw FormatException('"$key" is required and must be a number >= 0');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is double && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw FormatException('"$key" must be a whole number');
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is List && value.every((e) => e is String)) {
    return List<String>.from(value);
  }
  throw FormatException('"$key" must be a list of strings');
}
