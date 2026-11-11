import 'package:supabase/supabase.dart';

import '../audit/text_audit.dart';

/// What the weekly description check (N.55) reads; it writes nothing.
class AuditStore(final SupabaseClient _client) {
  /// Up to [limit] matched ads first seen since [since], with the rules'
  /// reading (`text_audit_sample`).
  Future<List<AuditListing>> sample(DateTime since, int limit) async {
    final rows = await _client.rpc<List<dynamic>>(
      'text_audit_sample',
      params: {'p_since': since.toUtc().toIso8601String(), 'p_limit': limit},
    );
    return [
      for (final r in rows) AuditListing.fromRow(r as Map<String, dynamic>),
    ];
  }

  /// Up to [limit] titles first seen since [since] that match no model
  /// (`unmatched_title_sample`).
  Future<List<UnmatchedTitle>> unmatchedTitles(
    DateTime since,
    int limit,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'unmatched_title_sample',
      params: {'p_since': since.toUtc().toIso8601String(), 'p_limit': limit},
    );
    return [
      for (final r in rows) UnmatchedTitle.fromRow(r as Map<String, dynamic>),
    ];
  }
}
