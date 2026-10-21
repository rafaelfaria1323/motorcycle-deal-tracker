import '../../domain/entities/dealer_reliability.dart';

/// The view's key: trimmed and lower case.
String dealerKey(String sellerName) => sellerName.trim().toLowerCase();

DealerReliability dealerFromJson(Map<String, dynamic> row) {
  int count(String key) => (row[key] as num?)?.toInt() ?? 0;
  final firstSeen = row['first_seen_at'];
  return DealerReliability(
    name: row['seller_name'] as String,
    bikes: count('bikes'),
    live: count('live'),
    relisted: count('relisted'),
    sharpChanges: count('sharp_changes'),
    missingMileage: count('missing_mileage'),
    repeated: count('repeated'),
    dropped: count('dropped'),
    firstSeenAt: firstSeen is String ? DateTime.tryParse(firstSeen) : null,
  );
}
