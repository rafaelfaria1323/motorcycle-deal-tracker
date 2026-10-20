import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/market_behaviour.dart';
import '../../domain/entities/model_market.dart';
import '../../domain/repositories/market_behaviour_repository.dart';

class SupabaseMarketBehaviourRepository implements MarketBehaviourRepository {
  SupabaseMarketBehaviourRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MarketBehaviour?> getForModel(String motorcycleId) async {
    final (row, depreciation) = await (
      _behaviour(motorcycleId),
      _depreciation(motorcycleId),
    ).wait;
    return row == null
        ? null
        : _behaviourFrom(
            row,
            depreciation == null ? null : _depreciationFrom(depreciation),
          );
  }

  @override
  Future<Map<String, double>> getLivePrices(String motorcycleId) async {
    final rows = await _client
        .from('listings')
        .select('id, price')
        .eq('motorcycle_id', motorcycleId)
        .isFilter('duplicate_of', null)
        .inFilter('status', ['active', 'price_changed'])
        .not('price', 'is', null);
    return {
      for (final r in rows) r['id'] as String: (r['price'] as num).toDouble(),
    };
  }

  @override
  Future<List<ModelMarket>> getTrackedModels() async {
    final models = await _client
        .from('motorcycles')
        .select('id, brand, model')
        .eq('is_active', true);
    final ids = [for (final m in models) m['id'] as String];
    if (ids.isEmpty) return const [];

    Future<Map<String, Map<String, dynamic>>> byModel(String view) async {
      final rows = await _client
          .from(view)
          .select()
          .inFilter('motorcycle_id', ids);
      return {for (final r in rows) r['motorcycle_id'] as String: r};
    }

    final (prices, behaviour, depreciation) = await (
      byModel('model_price_summary'),
      byModel('model_market_behaviour'),
      byModel('model_depreciation'),
    ).wait;

    return [
      for (final m in models)
        _modelMarket(
          m,
          prices[m['id']],
          behaviour[m['id']],
          depreciation[m['id']],
        ),
    ];
  }

  ModelMarket _modelMarket(
    Map<String, dynamic> model,
    Map<String, dynamic>? prices,
    Map<String, dynamic>? behaviour,
    Map<String, dynamic>? depreciation,
  ) {
    double number(String key) => (prices![key] as num).toDouble();
    return ModelMarket(
      motorcycleId: model['id'] as String,
      brand: model['brand'] as String,
      model: model['model'] as String,
      prices: prices == null
          ? null
          : PriceSpread(
              count: (prices['priced_live_count'] as num).toInt(),
              min: number('min_price'),
              p25: number('p25_price'),
              median: number('median_price'),
              p75: number('p75_price'),
              max: number('max_price'),
              medianYear: (prices['median_year'] as num?)?.toInt(),
              medianMileage: (prices['median_mileage'] as num?)?.toInt(),
            ),
      behaviour: behaviour == null
          ? null
          : _behaviourFrom(
              behaviour,
              depreciation == null ? null : _depreciationFrom(depreciation),
            ),
    );
  }

  MarketBehaviour _behaviourFrom(
    Map<String, dynamic> row,
    Depreciation? depreciation,
  ) {
    int count(String key) => (row[key] as num?)?.toInt() ?? 0;

    return MarketBehaviour(
      liveCount: count('live_count'),
      goneCount: count('gone_count'),
      pricedCount: count('priced_count'),
      droppedCount: count('dropped_count'),
      medianDaysToGone: (row['median_days_to_gone'] as num?)?.toInt(),
      medianDaysListedLive: (row['median_days_listed_live'] as num?)?.toInt(),
      medianDropPct: (row['median_drop_pct'] as num?)?.toDouble(),
      depreciation: depreciation,
    );
  }

  Depreciation _depreciationFrom(Map<String, dynamic> row) => Depreciation(
    sampleCount: (row['sample_count'] as num).toInt(),
    isFitted: row['is_fitted'] as bool,
    perYear: (row['per_year'] as num).toDouble(),
    per1000Km: (row['per_1000km'] as num).toDouble(),
  );

  Future<Map<String, dynamic>?> _behaviour(String motorcycleId) async => _client
      .from('model_market_behaviour')
      .select()
      .eq('motorcycle_id', motorcycleId)
      .maybeSingle();

  Future<Map<String, dynamic>?> _depreciation(String motorcycleId) async =>
      _client
          .from('model_depreciation')
          .select()
          .eq('motorcycle_id', motorcycleId)
          .maybeSingle();
}
