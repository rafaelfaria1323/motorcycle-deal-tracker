import 'package:equatable/equatable.dart';

/// One site's live listings and the facts they miss (view
/// `source_data_quality`). "Scored" listings are the tracked models'
/// listings that are not duplicates: the ones the scores are built from.
class const SourceQuality({
  required final String source,
  required final int liveCount,

  /// Not one of the catalog's models (or of a model switched off).
  required final int unmatchedCount,
  required final int duplicateCount,
  required final int scoredCount,
  required final int missingYear,
  required final int missingMileage,
  required final int missingLocation,

  /// Standvirtual listing pages not read yet.
  required final int detailsPending,

  /// The latest time any live listing was seen on the site: stale when the
  /// site stops answering (its listings stay live).
  final DateTime? lastSeenAt,

  /// Live listings whose price halved or rose by half or more in one step
  /// in the last 30 days: likely misreads.
  final int sharpPriceChanges = 0,
}) extends Equatable {
  factory SourceQuality.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return SourceQuality(
      source: json['source'] as String,
      liveCount: n('live_count'),
      unmatchedCount: n('unmatched_count'),
      duplicateCount: n('duplicate_count'),
      scoredCount: n('scored_count'),
      missingYear: n('missing_year'),
      missingMileage: n('missing_mileage'),
      missingLocation: n('missing_location'),
      detailsPending: n('details_pending'),
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      sharpPriceChanges: n('sharp_price_changes'),
    );
  }

  @override
  List<Object?> get props => [
    source,
    liveCount,
    unmatchedCount,
    duplicateCount,
    scoredCount,
    missingYear,
    missingMileage,
    missingLocation,
    detailsPending,
    lastSeenAt,
    sharpPriceChanges,
  ];
}
