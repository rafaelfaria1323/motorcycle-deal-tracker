import 'package:equatable/equatable.dart';

/// One site's live listings and the facts they miss (view
/// `source_data_quality`). "Scored" listings are the tracked models'
/// listings that are not duplicates: the ones the scores are built from.
class SourceQuality extends Equatable {
  const SourceQuality({
    required this.source,
    required this.liveCount,
    required this.unmatchedCount,
    required this.duplicateCount,
    required this.scoredCount,
    required this.missingYear,
    required this.missingMileage,
    required this.missingLocation,
    required this.detailsPending,
  });

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
    );
  }

  final String source;
  final int liveCount;

  /// Not one of the catalog's models (or of a model switched off).
  final int unmatchedCount;
  final int duplicateCount;
  final int scoredCount;
  final int missingYear;
  final int missingMileage;
  final int missingLocation;

  /// Standvirtual listing pages not read yet.
  final int detailsPending;

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
  ];
}
