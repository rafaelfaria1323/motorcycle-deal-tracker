/// Lenient readers for decoded JSON: a value of the wrong type becomes null.
Map<String, dynamic>? asMap(Object? o) => o is Map<String, dynamic> ? o : null;

/// A list, or an empty one for anything else.
List<Object?> asList(Object? o) => o is List ? o : const [];

int? asInt(Object? o) => o is num && o.isFinite ? o.toInt() : null;

/// An ISO 8601 string as a UTC time.
DateTime? asTime(Object? o) =>
    o is String ? DateTime.tryParse(o)?.toUtc() : null;
