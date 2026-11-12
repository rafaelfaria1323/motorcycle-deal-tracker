import 'package:supabase/supabase.dart';

import '../audit/score_check.dart';

/// What the weekly score check (N.61) reads; it writes nothing.
class ScoreCheckStore(final SupabaseClient _client) {
  /// Per model, the ads gone in the last [days] days and how they left
  /// (`score_check_models`).
  Future<List<ModelCheck>> models(int days) async {
    final rows = await _client.rpc<List<dynamic>>(
      'score_check_models',
      params: {'p_days': days},
    );
    return [
      for (final r in rows) ModelCheck.fromRow(r as Map<String, dynamic>),
    ];
  }

  /// Per Deal Score band, the ads first seen [horizon] to [days] days ago
  /// and how many likely sold within [horizon] days (`score_check_bands`).
  Future<List<BandCheck>> bands(int days, int horizon) async {
    final rows = await _client.rpc<List<dynamic>>(
      'score_check_bands',
      params: {'p_days': days, 'p_horizon': horizon},
    );
    return [for (final r in rows) BandCheck.fromRow(r as Map<String, dynamic>)];
  }
}
