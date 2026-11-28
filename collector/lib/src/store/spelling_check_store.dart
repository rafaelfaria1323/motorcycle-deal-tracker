import 'package:supabase/supabase.dart';

import '../audit/spelling_check.dart';

/// What the weekly spelling check (N.137) reads; it writes nothing.
class SpellingCheckStore(final SupabaseClient _client) {
  /// The matched, non-duplicate ads seen in the last [days] days
  /// (`spelling_check_texts`), [pageSize] at a time by id.
  Future<List<SpellingAd>> ads(int days, {int pageSize = 500}) async {
    final ads = <SpellingAd>[];
    String? after;
    while (true) {
      final rows = await _client.rpc<List<dynamic>>(
        'spelling_check_texts',
        params: {'p_days': days, 'p_after': after, 'p_limit': pageSize},
      );
      ads.addAll([
        for (final r in rows) SpellingAd.fromRow(r as Map<String, dynamic>),
      ]);
      if (rows.length < pageSize) return ads;
      after = ads.last.id;
    }
  }

  /// What the description rules read in each of [texts], in order
  /// (`text_rule_codes`, at most 1000 at a time).
  Future<List<Set<String>>> ruleCodes(List<String> texts) async {
    if (texts.isEmpty) return const [];
    final rows = await _client.rpc<List<dynamic>>(
      'text_rule_codes',
      params: {'p_texts': texts},
    );
    final codes = List<Set<String>>.generate(texts.length, (_) => {});
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      codes[(row['i'] as num).toInt() - 1] = {
        for (final c in row['codes'] as List<dynamic>) c as String,
      };
    }
    return codes;
  }
}
