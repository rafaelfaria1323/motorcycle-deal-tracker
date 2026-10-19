import 'package:collector/collector.dart';
import 'package:test/test.dart';

final until = DateTime.utc(2026, 10, 19, 8);
final lastWeek = DateTime.utc(2026, 10, 1);
final thisWeek = DateTime.utc(2026, 10, 15);

SummaryListing listing(
  String id, {
  String bike = 'Yamaha MT-07',
  String status = 'active',
  DateTime? firstSeenAt,
  DateTime? lastCheckedAt,
  double? price = 6800,
  int? dealScore,
  int? riskScore,
}) => SummaryListing(
  id: id,
  bike: bike,
  url: 'https://www.olx.pt/d/anuncio/$id.html',
  status: status,
  firstSeenAt: firstSeenAt ?? lastWeek,
  lastCheckedAt: lastCheckedAt ?? until,
  year: 2021,
  mileage: 12000,
  price: price,
  dealScore: dealScore,
  riskScore: riskScore,
);

WeeklySummary summary(
  List<SummaryListing> listings, [
  List<PricePoint> history = const [],
]) => buildWeeklySummary(listings: listings, history: history, until: until);

void main() {
  test('counts new, gone and live listings of the last 7 days', () {
    final s = summary([
      listing('old'),
      listing('new', firstSeenAt: thisWeek),
      listing(
        'new-gone',
        status: 'removed',
        firstSeenAt: thisWeek.add(const Duration(hours: 1)),
        lastCheckedAt: thisWeek.add(const Duration(days: 1)),
      ),
      listing('gone', status: 'removed', lastCheckedAt: thisWeek),
      listing('gone-earlier', status: 'removed', lastCheckedAt: lastWeek),
      listing('edge', firstSeenAt: until.subtract(const Duration(days: 7))),
    ]);
    expect(s.newListings.map((l) => l.id), ['edge', 'new', 'new-gone']);
    expect(s.goneCount, 2);
    expect(s.liveCount, 3);
  });

  test('a drop compares the price the week started with and the last one', () {
    final s = summary(
      [
        listing('a'),
        listing('b'),
        listing('c'),
        listing('gone', status: 'removed'),
      ],
      [
        PricePoint('a', 8000, lastWeek),
        PricePoint('a', 7600, thisWeek),
        PricePoint('a', 7200, thisWeek.add(const Duration(days: 1))),
        // Down and back up: no drop.
        PricePoint('b', 7000, lastWeek),
        PricePoint('b', 6500, thisWeek),
        PricePoint('b', 7000, thisWeek.add(const Duration(days: 1))),
        // Below the 1 % threshold.
        PricePoint('c', 7000, lastWeek),
        PricePoint('c', 6950, thisWeek),
        // Only live listings count.
        PricePoint('gone', 7000, lastWeek),
        PricePoint('gone', 5000, thisWeek),
      ],
    );
    expect(s.drops, hasLength(1));
    expect(s.drops.single.listing.id, 'a');
    expect(s.drops.single.oldPrice, 8000);
    expect(s.drops.single.newPrice, 7200);
  });

  test('a listing new this week drops from its first price', () {
    final s = summary(
      [listing('n', firstSeenAt: thisWeek)],
      [
        PricePoint('n', 9000, thisWeek),
        PricePoint('n', 8500, thisWeek.add(const Duration(days: 1))),
      ],
    );
    expect(s.drops.single.oldPrice, 9000);
  });

  test('best deals: live, risk below 50, by score then price', () {
    final s = summary([
      listing('a', dealScore: 80, price: 7000),
      listing('b', dealScore: 90, riskScore: 60),
      listing('c', dealScore: 80, price: 6500),
      listing('d', dealScore: 95, status: 'removed'),
      listing('e'),
      listing('f', dealScore: 70, riskScore: 20),
    ]);
    expect(s.bestDeals.map((l) => l.id), ['c', 'a', 'f']);
  });

  test('the message', () {
    final s = summary(
      [
        listing('a', dealScore: 88, price: 6900),
        listing('n1', bike: 'Honda CB650R', firstSeenAt: thisWeek, price: 7200),
        listing('n2', firstSeenAt: thisWeek),
        listing('n3', firstSeenAt: thisWeek),
        listing('g', status: 'removed', lastCheckedAt: thisWeek),
      ],
      [
        PricePoint('n1', 7500, thisWeek),
        PricePoint('n1', 7200, thisWeek.add(const Duration(days: 1))),
      ],
    );
    expect(
      formatWeeklySummary(s),
      '📊 Resumo da semana · 12/10 a 18/10\n'
      '\n'
      '🆕 3 anúncios novos (Yamaha MT-07 2, Honda CB650R 1)\n'
      '📉 1 baixa de preço\n'
      '🚫 1 saiu do mercado\n'
      '📋 4 anúncios ativos\n'
      '\n'
      '🏆 Melhores negócios\n'
      '1. Yamaha MT-07 2021 · 6 900 € · 12 000 km · Pontuação 88\n'
      'https://www.olx.pt/d/anuncio/a.html\n'
      '\n'
      '📉 Maiores baixas\n'
      'Honda CB650R 2021: 7 500 € → 7 200 € (−4 %)\n'
      'https://www.olx.pt/d/anuncio/n1.html',
    );
  });

  test('a quiet week still says so', () {
    expect(
      formatWeeklySummary(summary(const [])),
      '📊 Resumo da semana · 12/10 a 18/10\n'
      '\n'
      '🆕 0 anúncios novos\n'
      '📉 0 baixas de preço\n'
      '🚫 0 saíram do mercado\n'
      '📋 0 anúncios ativos',
    );
  });
}
