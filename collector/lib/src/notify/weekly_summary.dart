import 'pending_alert.dart';

/// A listing of a tracked model as the weekly summary sees it.
class SummaryListing {
  const SummaryListing({
    required this.id,
    required this.bike,
    required this.url,
    required this.status,
    required this.firstSeenAt,
    required this.lastCheckedAt,
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

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String _bikeAndYear(SummaryListing l) =>
    [l.bike, if (l.year != null) '${l.year}'].join(' ');

/// The Telegram message (plain text).
String formatWeeklySummary(WeeklySummary s, {int dropCount = 3}) {
  final lastDay = s.until.subtract(const Duration(days: 1));
  final out = <String>[
    '📊 Resumo da semana · ${_day(s.since)} a ${_day(lastDay)}',
    '',
  ];

  // New listings per model, most first.
  final perModel = <String, int>{};
  for (final l in s.newListings) {
    perModel[l.bike] = (perModel[l.bike] ?? 0) + 1;
  }
  final models = perModel.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  final newLine = _count(
    s.newListings.length,
    'anúncio novo',
    'anúncios novos',
  );
  out
    ..add(
      models.isEmpty
          ? '🆕 $newLine'
          : '🆕 $newLine (${models.map((e) => '${e.key} ${e.value}').join(', ')})',
    )
    ..add('📉 ${_count(s.drops.length, 'baixa de preço', 'baixas de preço')}')
    ..add('🚫 ${_count(s.goneCount, 'saiu do mercado', 'saíram do mercado')}')
    ..add('📋 ${_count(s.liveCount, 'anúncio ativo', 'anúncios ativos')}');

  if (s.bestDeals.isNotEmpty) {
    out
      ..add('')
      ..add('🏆 Melhores negócios');
    for (final (i, l) in s.bestDeals.indexed) {
      final facts = [
        _bikeAndYear(l),
        if (l.price != null) euros(l.price!),
        if (l.mileage != null) '${euros(l.mileage!).replaceAll(' €', '')} km',
        'Pontuação ${l.dealScore}',
      ].join(' · ');
      out
        ..add('${i + 1}. $facts')
        ..add(l.url);
    }
  }

  if (s.drops.isNotEmpty) {
    out
      ..add('')
      ..add('📉 Maiores baixas');
    for (final d in s.drops.take(dropCount)) {
      final percent = (d.fraction * 100).round();
      out
        ..add(
          '${_bikeAndYear(d.listing)}: ${euros(d.oldPrice)} → '
          '${euros(d.newPrice)} (−$percent %)',
        )
        ..add(d.listing.url);
    }
  }

  return out.join('\n');
}
