import '../../domain/entities/weekly_summary.dart';

class WeeklySummaryModel {
  const WeeklySummaryModel._();

  static const columns = 'summary, made_at';

  /// A `weekly_summaries` row; `summary` as the collector writes it
  /// (`weeklySummaryJson`). Entries it cannot read are left out.
  static WeeklySummary fromJson(Map<String, dynamic> json) {
    final s = json['summary'] as Map<String, dynamic>;
    List<Map<String, dynamic>> list(String key) => [
      for (final e in s[key] as List<dynamic>? ?? const [])
        if (e is Map<String, dynamic>) e,
    ];
    int count(String key) => (s[key] as num?)?.toInt() ?? 0;

    return WeeklySummary(
      since: DateTime.parse(s['since'] as String).toLocal(),
      until: DateTime.parse(s['until'] as String).toLocal(),
      madeAt: DateTime.parse(json['made_at'] as String).toLocal(),
      liveCount: count('live'),
      newCount: count('new'),
      goneCount: count('gone'),
      dropCount: count('drops'),
      newByModel: [
        for (final e in list('new_by_model'))
          (bike: e['bike'] as String, count: (e['count'] as num).toInt()),
      ],
      biggestDrops: list('biggest_drops').map(_deal).toList(),
      bestDeals: list('best').map(_deal).toList(),
    );
  }

  static SummaryDeal _deal(Map<String, dynamic> e) => SummaryDeal(
    listingId: e['id'] as String,
    bike: e['bike'] as String,
    year: (e['year'] as num?)?.toInt(),
    price: (e['price'] as num?)?.toDouble(),
    oldPrice: (e['old_price'] as num?)?.toDouble(),
    mileage: (e['mileage'] as num?)?.toInt(),
    dealScore: (e['deal_score'] as num?)?.toInt(),
  );
}
