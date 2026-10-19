/// Lenient readers for decoded JSON: a value of the wrong type becomes null.
Map<String, dynamic>? asMap(Object? o) => o is Map<String, dynamic> ? o : null;

int? asInt(Object? o) => o is num ? o.toInt() : null;

/// An ISO 8601 string as a UTC time.
DateTime? asTime(Object? o) =>
    o is String ? DateTime.tryParse(o)?.toUtc() : null;
