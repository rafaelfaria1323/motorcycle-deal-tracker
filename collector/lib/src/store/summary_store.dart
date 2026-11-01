import 'package:supabase/supabase.dart';

import '../../collector.dart';
import 'store_support.dart';

/// What the weekly summary reads and keeps.
class SummaryStore(final SupabaseClient _client) {
  /// For the weekly summary: listings of the models in [bikeNames] (id to
  /// name), not duplicates, that are live or were first seen or found
  /// missing since [since].
  Future<List<SummaryListing>> summaryListings(
    Map<String, String> bikeNames,
    DateTime since,
  ) async {
    if (bikeNames.isEmpty) return const [];
    final from = since.toUtc().toIso8601String();
    final rows = await readAllPages(
      (start, end) => _client
          .from('listings')
          .select(
            'id, motorcycle_id, brand, model, url, status, first_seen_at, '
            'last_checked_at, year, mileage, price, deal_score, risk_score',
          )
          .inFilter('motorcycle_id', bikeNames.keys.toList())
          .isFilter('duplicate_of', null)
          .or(
            'status.in.(active,price_changed),'
            'first_seen_at.gte."$from",last_checked_at.gte."$from"',
          )
          .order('id')
          .range(start, end),
    );
    return [for (final r in rows) SummaryListing.fromRow(r, bikeNames)];
  }

  /// The whole price history of those of [listingIds] whose price was
  /// recorded since [since] (a new price, or a new listing's first one).
  /// Only [listingIds]' rows are read, never the whole table's week.
  Future<List<PricePoint>> priceHistoryChangedSince(
    Set<String> listingIds,
    DateTime since,
  ) async {
    final from = since.toUtc().toIso8601String();
    final ids = <String>{};
    // A few ids per request keep the address short.
    for (final chunk in _chunksOf100(listingIds.toList()..sort())) {
      final recent = await readAllPages(
        (start, end) => _client
            .from('listing_price_history')
            .select('listing_id')
            .inFilter('listing_id', chunk)
            .gte('observed_at', from)
            .order('id')
            .range(start, end),
      );
      ids.addAll([for (final r in recent) r['listing_id'] as String]);
    }

    final points = <PricePoint>[];
    for (final chunk in _chunksOf100(ids.toList()..sort())) {
      final rows = await readAllPages(
        (start, end) => _client
            .from('listing_price_history')
            .select('listing_id, price, observed_at')
            .inFilter('listing_id', chunk)
            .order('id')
            .range(start, end),
      );
      points.addAll([for (final r in rows) PricePoint.fromRow(r)]);
    }
    return points;
  }

  /// The models each account follows: account -> catalog id -> first year.
  /// With [account], only that account's.
  Future<Map<String, Map<String, int>>> followedModels({
    String? account,
  }) async {
    final rows = await readAllPages((start, end) {
      var query = _client
          .from('user_models')
          .select('user_id, motorcycle_id, min_year')
          .eq('tracked', true);
      if (account != null) query = query.eq('user_id', account);
      return query.order('user_id').order('motorcycle_id').range(start, end);
    });
    final byUser = <String, Map<String, int>>{};
    for (final r in rows) {
      byUser.putIfAbsent(r['user_id'] as String, () => {})[r['motorcycle_id']
          as String] = (r['min_year'] as num)
          .toInt();
    }
    return byUser;
  }

  /// Keeps [summary] as [userId]'s latest weekly summary (the app's
  /// "Resumo da semana").
  Future<void> saveWeeklySummary(
    String userId,
    WeeklySummary summary,
    Map<String, Object?> json,
  ) async {
    await _client.from('weekly_summaries').upsert({
      'user_id': userId,
      'since': summary.since.toUtc().toIso8601String(),
      'until': summary.until.toUtc().toIso8601String(),
      'summary': json,
      'made_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}

/// [ids] in groups of 100, so each request's address stays short.
Iterable<List<String>> _chunksOf100(List<String> ids) sync* {
  for (var i = 0; i < ids.length; i += 100) {
    yield ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
  }
}
