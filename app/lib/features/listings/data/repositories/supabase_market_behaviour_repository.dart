import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/bike_value.dart';
import '../../domain/entities/bike_value_request.dart';
import '../../domain/entities/listing.dart' show minRealPrice;
import '../../domain/entities/market_behaviour.dart';
import '../../domain/entities/model_market.dart';
import '../../domain/repositories/market_behaviour_repository.dart';

class SupabaseMarketBehaviourRepository implements MarketBehaviourRepository {
  SupabaseMarketBehaviourRepository(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _clock;

  /// How long a model's figures are reused. They change only when a
  /// collection runs (hours apart), and one listing page asks for them
  /// from four cards at once (offer, message, costs, market).
  static const reuseFor = Duration(minutes: 10);

  final _forModel =
      <String, ({DateTime at, Future<MarketBehaviour?> figures})>{};

  /// The figures of a model (the same for every account), read once for
  /// all the cards asking within [reuseFor]; a failed read isn't kept, so
  /// the next one asks again.
  @override
  Future<MarketBehaviour?> getForModel(String motorcycleId) {
    final now = _clock();
    final kept = _forModel[motorcycleId];
    if (kept != null && now.difference(kept.at) < reuseFor) {
      return kept.figures;
    }
    final figures = _readForModel(motorcycleId);
    _forModel[motorcycleId] = (at: now, figures: figures);
    unawaited(
      figures.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_forModel[motorcycleId]?.figures, figures)) {
            _forModel.remove(motorcycleId);
          }
        },
      ),
    );
    return figures;
  }

  Future<MarketBehaviour?> _readForModel(String motorcycleId) async {
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
  Future<TimeToSale?> getTimeToSale(String listingId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'listing_time_to_sale',
      params: {'p_listing_id': listingId},
    );
    return rows.isEmpty
        ? null
        : timeToSaleFrom(rows.first as Map<String, dynamic>);
  }

  @override
  Future<Map<String, double>> getLivePrices(String motorcycleId) async {
    final rows = await _client
        .from('listings')
        .select('id, price')
        .eq('motorcycle_id', motorcycleId)
        .isFilter('duplicate_of', null)
        .inFilter('status', ['active', 'price_changed'])
        // Placeholders ("1 €") are no price to compare with.
        .gte('price', minRealPrice);
    return {
      for (final r in rows) r['id'] as String: (r['price'] as num).toDouble(),
    };
  }

  @override
  Future<List<ModelMarket>> getTrackedModels() async {
    final models = await _client
        .from('motorcycles')
        .select('id, brand, model')
        .eq('tracked_by_me', true);
    final ids = [for (final m in models) m['id'] as String];
    if (ids.isEmpty) return const [];

    Future<Map<String, Map<String, dynamic>>> byModel(String view) async {
      final rows = await _client
          .from(view)
          .select()
          .inFilter('motorcycle_id', ids);
      return {for (final r in rows) r['motorcycle_id'] as String: r};
    }

    final (prices, behaviour, depreciation, trend) = await (
      byModel('model_price_summary'),
      byModel('model_market_behaviour'),
      byModel('model_depreciation'),
      _trend(ids),
    ).wait;

    return [
      for (final m in models)
        _modelMarket(
          m,
          prices[m['id']],
          behaviour[m['id']],
          depreciation[m['id']],
          trend[m['id']] ?? const [],
        ),
    ];
  }

  @override
  Future<BikeValue> getBikeValue(
    String motorcycleId, {
    required int year,
    int? mileage,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'bike_value',
      params: {
        'p_motorcycle_id': motorcycleId,
        'p_year': year,
        'p_mileage': mileage,
      },
    );
    return rows.isEmpty
        ? const BikeValue(comparableCount: 0)
        : bikeValueFrom(rows.first as Map<String, dynamic>);
  }

  @override
  Future<String> bikeValueModel({
    required String brand,
    required String model,
    String? olxSearch,
    String? standvirtualSearch,
    int? engineCcMin,
    int? engineCcMax,
  }) => _client.rpc<String>(
    'bike_value_model',
    params: {
      'p_brand': brand,
      'p_model': model,
      'p_olx_search': olxSearch,
      'p_standvirtual_search': standvirtualSearch,
      'p_engine_cc_min': engineCcMin,
      'p_engine_cc_max': engineCcMax,
    },
  );

  @override
  Future<({String requestId, bool ready})> requestBikeValue(
    String motorcycleId, {
    required int year,
    int? mileage,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'request_bike_value',
        params: {
          'p_motorcycle_id': motorcycleId,
          'p_year': year,
          'p_mileage': mileage,
        },
      );
      final row = rows.first as Map<String, dynamic>;
      return (
        requestId: row['request_id'] as String,
        ready: row['ready'] as bool,
      );
    } on PostgrestException catch (e) {
      // request_bike_value's cap on waiting requests a day.
      if (e.code == '54000') throw const BikeValueRequestLimit();
      rethrow;
    }
  }

  @override
  Future<List<BikeValueRequest>> getBikeValueRequests() async {
    final rows = await _client
        .from('bike_value_requests')
        .select(
          'id, motorcycle_id, year, mileage, requested_at, answered_at, '
          'motorcycles(brand, model)',
        )
        .order('requested_at', ascending: false)
        .limit(20);
    return [for (final r in rows) bikeValueRequestFrom(r)];
  }

  /// Each model's weeks, oldest first.
  Future<Map<String, List<PriceTrendWeek>>> _trend(List<String> ids) async {
    final rows = await _client
        .from('model_price_trend')
        .select()
        .inFilter('motorcycle_id', ids)
        .order('week_start');
    final weeks = <String, List<PriceTrendWeek>>{};
    for (final r in rows) {
      (weeks[r['motorcycle_id'] as String] ??= []).add(priceTrendWeekFrom(r));
    }
    return weeks;
  }

  ModelMarket _modelMarket(
    Map<String, dynamic> model,
    Map<String, dynamic>? prices,
    Map<String, dynamic>? behaviour,
    Map<String, dynamic>? depreciation,
    List<PriceTrendWeek> trend,
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
      trend: trend,
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

  Future<Map<String, dynamic>?> _behaviour(String motorcycleId) async =>
      await _client
          .from('model_market_behaviour')
          .select()
          .eq('motorcycle_id', motorcycleId)
          .maybeSingle();

  Future<Map<String, dynamic>?> _depreciation(String motorcycleId) async =>
      await _client
          .from('model_depreciation')
          .select()
          .eq('motorcycle_id', motorcycleId)
          .maybeSingle();
}

/// A row of `model_price_trend`.
PriceTrendWeek priceTrendWeekFrom(Map<String, dynamic> row) => PriceTrendWeek(
  weekStart: DateTime.parse(row['week_start'] as String),
  count: (row['listing_count'] as num).toInt(),
  median: (row['median_price'] as num).toDouble(),
  adjustedMedian: (row['median_adjusted_price'] as num).toDouble(),
);

/// The row of `listing_time_to_sale`.
TimeToSale timeToSaleFrom(Map<String, dynamic> row) => TimeToSale(
  band: switch (row['band']) {
    'below' => PriceBand.below,
    'near' => PriceBand.near,
    'above' => PriceBand.above,
    _ => null,
  },
  goneCount: (row['gone_count'] as num).toInt(),
  liveCount: (row['live_count'] as num).toInt(),
  daysListed: (row['days_listed'] as num).toInt(),
  typicalDays: (row['typical_days'] as num?)?.toInt(),
  remainingDays: (row['remaining_days'] as num?)?.toInt(),
);

/// The row of `bike_value`.
BikeValue bikeValueFrom(Map<String, dynamic> row) => BikeValue(
  comparableCount: (row['comparable_count'] as num).toInt(),
  estimate: (row['fair_price'] as num?)?.toDouble(),
  low: (row['low_price'] as num?)?.toDouble(),
  high: (row['high_price'] as num?)?.toDouble(),
);

/// A row of `bike_value_requests` with its model's names.
BikeValueRequest bikeValueRequestFrom(Map<String, dynamic> row) {
  final model = row['motorcycles'] as Map<String, dynamic>;
  final answered = row['answered_at'] as String?;
  return BikeValueRequest(
    id: row['id'] as String,
    motorcycleId: row['motorcycle_id'] as String,
    brand: model['brand'] as String,
    model: model['model'] as String,
    year: (row['year'] as num).toInt(),
    mileage: (row['mileage'] as num?)?.toInt(),
    requestedAt: DateTime.parse(row['requested_at'] as String),
    answeredAt: answered == null ? null : DateTime.parse(answered),
  );
}
