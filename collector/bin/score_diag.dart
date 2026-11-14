import 'package:collector/collector.dart';

// Temporary diagnostic (not for main): gone ads of two models.
Future<void> main() async {
  await withServiceClient((client) async {
    final models = await client
        .from('motorcycles')
        .select('id, brand, model')
        .inFilter('model', ['CB650R', 'PCX125', 'MT-07']);
    final since =
        DateTime.now().toUtc().subtract(const Duration(days: 28)).toIso8601String();
    for (final m in models) {
      print('== ${m['brand']} ${m['model']}');
      final rows = await client
          .from('listings')
          .select(
            'source, source_listing_id, seller_type, status, published_at, '
            'site_refreshed_at, first_seen_at, last_seen_at, last_checked_at, '
            'search_key, price, year, last_deal_score, last_pct_below_market, '
            'relisted_from, sold_marked_at',
          )
          .eq('motorcycle_id', m['id'] as String)
          .inFilter('status', ['removed', 'sold'])
          .isFilter('duplicate_of', null)
          .gte('last_seen_at', since)
          .order('last_seen_at');
      for (final r in rows) {
        print([
          r['source'], r['source_listing_id'], r['seller_type'],
          'pub=${r['published_at']}', 'ref=${r['site_refreshed_at']}',
          'first=${r['first_seen_at']}', 'last=${r['last_seen_at']}',
          'chk=${r['last_checked_at']}', 'key=${r['search_key']}',
          r['price'], r['year'], 'lds=${r['last_deal_score']}',
          'pos=${r['last_pct_below_market']}',
        ].join(' | '));
      }
    }
    final runs = await client
        .from('collector_runs')
        .select('started_at, status')
        .gte('started_at', since)
        .order('started_at');
    print('== runs');
    for (final r in runs) {
      print('${r['started_at']} ${r['status']}');
    }
  });
}
