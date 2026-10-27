import 'pending_alert.dart';
import 'notification_text.dart';

/// A listing of a tracked model as the weekly summary sees it.
class SummaryListing {
  const SummaryListing({
    required this.id,
    required this.bike,
    required this.url,
    required this.status,
    required this.firstSeenAt,
    required this.lastCheckedAt,
    this.motorcycleId,
    this.year,
    this.mileage,
    this.price,
    this.dealScore,
    this.riskScore,
  });

  factory SummaryListing.fromRow(
    Map<String, dynamic> row,
    Map<String, String> bikeNames,
  ) => SummaryListing(
    id: row['id'] as String,
    bike: bikeNames[row['motorcycle_id']] ?? '${row['brand']} ${row['model']}',
    url: row['url'] as String,
    status: row['status'] as String,
    firstSeenAt: DateTime.parse(row['first_seen_at'] as String),
    lastCheckedAt: DateTime.parse(row['last_checked_at'] as String),
    motorcycleId: row['motorcycle_id'] as String?,
    year: (row['year'] as num?)?.toInt(),
    mileage: (row['mileage'] as num?)?.toInt(),
    price: (row['price'] as num?)?.toDouble(),
    dealScore: (row['deal_score'] as num?)?.toInt(),
    riskScore: (row['risk_score'] as num?)?.toInt(),
  );

  final String id;

  /// Catalog brand and model, e.g. "Yamaha MT-07".
  final String bike;
  final String url;
  final String status;
  final DateTime firstSeenAt;

  /// For a removed listing, when it was found missing.
  final DateTime lastCheckedAt;

  /// The catalog model, to pick each account's own models.
  final String? motorcycleId;
  final int? year;
  final int? mileage;
  final double? price;
  final int? dealScore;
  final int? riskScore;

  bool get isLive => status == 'active' || status == 'price_changed';
  bool get isGone => status == 'removed' || status == 'sold';
}

/// One `listing_price_history` row.
class PricePoint {
  const PricePoint(this.listingId, this.price, this.observedAt);

  factory PricePoint.fromRow(Map<String, dynamic> row) => PricePoint(
    row['listing_id'] as String,
    (row['price'] as num).toDouble(),
    DateTime.parse(row['observed_at'] as String),
  );

  final String listingId;
  final double price;
  final DateTime observedAt;
}

class PriceDrop {
  const PriceDrop(this.listing, this.oldPrice, this.newPrice);

  final SummaryListing listing;
  final double oldPrice;
  final double newPrice;

  double get fraction => (oldPrice - newPrice) / oldPrice;
}

class WeeklySummary {
  const WeeklySummary({
    required this.since,
    required this.until,
    required this.liveCount,
    required this.newListings,
    required this.goneCount,
    required this.drops,
    required this.bestDeals,
  });

  final DateTime since;
  final DateTime until;
  final int liveCount;
  final List<SummaryListing> newListings;
  final int goneCount;

  /// Live listings whose price fell this week, biggest drop first.
  final List<PriceDrop> drops;

  /// Live listings by Deal Score, best first (risk below 50 only).
  final List<SummaryListing> bestDeals;
}

/// The same 1 % threshold as price-reduction alerts.
const _minDrop = 0.01;

/// Same limit as excellent-opportunity alerts.
const _maxRisk = 50;

/// Builds the summary of the week before [until] from the tracked models'
/// listings and the price history of those whose price changed this week.
WeeklySummary buildWeeklySummary({
  required List<SummaryListing> listings,
  required List<PricePoint> history,
  required DateTime until,
  int bestCount = 5,
}) {
  final since = until.subtract(const Duration(days: 7));
  bool inWeek(DateTime t) => !t.isBefore(since) && t.isBefore(until);

  final live = listings.where((l) => l.isLive).toList();

  final newListings = listings.where((l) => inWeek(l.firstSeenAt)).toList()
    ..sort((a, b) => a.firstSeenAt.compareTo(b.firstSeenAt));

  final goneCount = listings
      .where((l) => l.isGone && inWeek(l.lastCheckedAt))
      .length;

  // A drop compares the last price this week with the price the week
  // started with (the listing's first price if it is new this week).
  final byListing = <String, List<PricePoint>>{};
  for (final p in history) {
    byListing.putIfAbsent(p.listingId, () => []).add(p);
  }
  final drops = <PriceDrop>[];
  for (final listing in live) {
    final points = byListing[listing.id];
    if (points == null) continue;
    points.sort((a, b) => a.observedAt.compareTo(b.observedAt));
    final before = points.where((p) => p.observedAt.isBefore(since));
    final during = points.where((p) => inWeek(p.observedAt)).toList();
    if (during.isEmpty) continue;
    final start = before.isNotEmpty ? before.last : during.first;
    final end = during.last;
    if (end.price <= start.price * (1 - _minDrop)) {
      drops.add(PriceDrop(listing, start.price, end.price));
    }
  }
  drops.sort((a, b) => b.fraction.compareTo(a.fraction));

  final bestDeals =
      live
          .where((l) => l.dealScore != null && (l.riskScore ?? 0) < _maxRisk)
          .toList()
        ..sort((a, b) {
          final byScore = b.dealScore!.compareTo(a.dealScore!);
          if (byScore != 0) return byScore;
          return (a.price ?? double.infinity).compareTo(
            b.price ?? double.infinity,
          );
        });

  return WeeklySummary(
    since: since,
    until: until,
    liveCount: live.length,
    newListings: newListings,
    goneCount: goneCount,
    drops: drops,
    bestDeals: bestDeals.take(bestCount).toList(),
  );
}

String _day(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';

String _bikeAndYear(SummaryListing l) =>
    [l.bike, if (l.year != null) '${l.year}'].join(' ');

/// The listings of the models an account follows ([models]: catalog id
/// -> first year), as the app's `in_my_models` picks them.
List<SummaryListing> listingsFollowed(
  List<SummaryListing> listings,
  Map<String, int> models,
) => [
  for (final l in listings)
    if (models[l.motorcycleId] case final from?
        when l.year == null || l.year! >= from)
      l,
];

String _iso(DateTime t) => t.toUtc().toIso8601String();

Map<String, Object?> _deal(SummaryListing l) => {
  'id': l.id,
  'bike': l.bike,
  'year': l.year,
  'price': l.price,
  'mileage': l.mileage,
  'deal_score': l.dealScore,
};

/// What the app's "Resumo da semana" page shows (`weekly_summaries.summary`):
/// counts, new listings per model (most first), the biggest drops and the
/// best deals, each with the listing's id so a tap opens it.
Map<String, Object?> weeklySummaryJson(WeeklySummary s, {int dropCount = 5}) {
  final perModel = <String, int>{};
  for (final l in s.newListings) {
    perModel[l.bike] = (perModel[l.bike] ?? 0) + 1;
  }
  final models = perModel.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return {
    'since': _iso(s.since),
    'until': _iso(s.until),
    'live': s.liveCount,
    'new': s.newListings.length,
    'gone': s.goneCount,
    'drops': s.drops.length,
    'new_by_model': [
      for (final e in models) {'bike': e.key, 'count': e.value},
    ],
    'biggest_drops': [
      for (final d in s.drops.take(dropCount))
        {..._deal(d.listing), 'old_price': d.oldPrice, 'price': d.newPrice},
    ],
    'best': [for (final l in s.bestDeals) _deal(l)],
  };
}

/// The Monday notification: the week in one line, and the best deal; a tap
/// opens the summary in the app.
Map<String, Object?> weeklySummaryPush(
  WeeklySummary s, {
  NotificationLanguage language = NotificationLanguage.portuguese,
}) {
  final lastDay = s.until.subtract(const Duration(days: 1));
  final best = s.bestDeals.firstOrNull;
  final counts = [
    language.newListings(s.newListings.length),
    language.priceDrops(s.drops.length),
    language.goneListings(s.goneCount),
  ].join(' · ');
  return {
    'title': language.weekTitle(_day(s.since), _day(lastDay)),
    'body': [
      counts,
      if (best != null)
        language.bestDeal(
          '${_bikeAndYear(best)} · '
          '${best.price == null ? '' : '${euros(best.price!, language: language)} · '}'
          '${language.score(best.dealScore)}',
        ),
    ].join('\n'),
    'url': '/#/summary',
    'tag': 'weekly-summary',
    'language': language.code,
  };
}
