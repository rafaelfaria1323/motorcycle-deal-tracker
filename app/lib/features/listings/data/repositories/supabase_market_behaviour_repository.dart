import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/market_behaviour.dart';
import '../../domain/repositories/market_behaviour_repository.dart';

class SupabaseMarketBehaviourRepository implements MarketBehaviourRepository {
  SupabaseMarketBehaviourRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MarketBehaviour?> getForModel(String motorcycleId) async {
    final row = await _client
        .from('model_market_behaviour')
        .select()
        .eq('motorcycle_id', motorcycleId)
        .maybeSingle();
    if (row == null) return null;

    int count(String key) => (row[key] as num?)?.toInt() ?? 0;

    return MarketBehaviour(
      liveCount: count('live_count'),
      goneCount: count('gone_count'),
      pricedCount: count('priced_count'),
      droppedCount: count('dropped_count'),
      medianDaysToGone: (row['median_days_to_gone'] as num?)?.toInt(),
      medianDaysListedLive: (row['median_days_listed_live'] as num?)?.toInt(),
      medianDropPct: (row['median_drop_pct'] as num?)?.toDouble(),
      depreciation: await _depreciation(motorcycleId),
    );
  }

  Future<Depreciation?> _depreciation(String motorcycleId) async {
    final row = await _client
        .from('model_depreciation')
        .select()
        .eq('motorcycle_id', motorcycleId)
        .maybeSingle();
    if (row == null) return null;

    return Depreciation(
      sampleCount: (row['sample_count'] as num).toInt(),
      isFitted: row['is_fitted'] as bool,
      perYear: (row['per_year'] as num).toDouble(),
      per1000Km: (row['per_1000km'] as num).toDouble(),
    );
  }
}
