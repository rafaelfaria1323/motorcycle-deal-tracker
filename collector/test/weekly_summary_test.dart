import 'package:collector/collector.dart';
import 'package:test/test.dart';

final until = DateTime.utc(2026, 10, 19, 8);
final lastWeek = DateTime.utc(2026, 10);
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
  String? motorcycleId,
  int? year = 2021,
}) => SummaryListing(
  id: id,
  bike: bike,
  url: 'https://www.olx.pt/d/anuncio/$id.html',
  status: status,
  firstSeenAt: firstSeenAt ?? lastWeek,
  lastCheckedAt: lastCheckedAt ?? until,
  motorcycleId: motorcycleId,
  year: year,
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

  test('a drop of exactly 1 % counts', () {
    final s = summary(
      [listing('a')],
      [PricePoint('a', 10000, lastWeek), PricePoint('a', 9900, thisWeek)],
    );
    expect(s.drops.single.newPrice, 9900);
  });

  test('the drop starts from the latest price before the week', () {
    final s = summary(
      [listing('a')],
      [
        PricePoint('a', 9000, lastWeek.subtract(const Duration(days: 3))),
        PricePoint('a', 8000, lastWeek),
        PricePoint('a', 7500, thisWeek),
      ],
    );
    expect(s.drops.single.oldPrice, 8000);
  });

  test('best deals: risk exactly 50 is left out, 49 is kept', () {
    final s = summary([
      listing('r50', dealScore: 90, riskScore: 50),
      listing('r49', dealScore: 80, riskScore: 49),
    ]);
    expect(s.bestDeals.map((l) => l.id), ['r49']);
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

  test('the summary for the app', () {
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
    const deal = {'year': 2021, 'mileage': 12000};
    expect(weeklySummaryJson(s), {
      'since': '2026-10-12T08:00:00.000Z',
      'until': '2026-10-19T08:00:00.000Z',
      'live': 4,
      'new': 3,
      'gone': 1,
      'drops': 1,
      'new_by_model': [
        {'bike': 'Yamaha MT-07', 'count': 2},
        {'bike': 'Honda CB650R', 'count': 1},
      ],
      'biggest_drops': [
        {
          'id': 'n1',
          'bike': 'Honda CB650R',
          ...deal,
          'price': 7200.0,
          'deal_score': null,
          'old_price': 7500.0,
        },
      ],
      'best': [
        {
          'id': 'a',
          'bike': 'Yamaha MT-07',
          ...deal,
          'price': 6900.0,
          'deal_score': 88,
        },
      ],
    });
    expect(weeklySummaryPush(s), {
      'title': '📊 Resumo da semana · 12/10 a 18/10',
      'body':
          '3 anúncios novos · 1 baixa de preço · 1 saiu do mercado\n'
          'Melhor: Yamaha MT-07 2021 · 6 900 € · Pontuação 88',
      'url': '/#/summary',
      'tag': 'weekly-summary',
    });
  });

  test('a quiet week still says so', () {
    expect(
      weeklySummaryPush(summary(const []))['body'],
      '0 anúncios novos · 0 baixas de preço · 0 saíram do mercado',
    );
  });

  group('per account', () {
    final listings = [
      listing('mt07-2021', motorcycleId: 'mt07'),
      listing('mt07-2019', motorcycleId: 'mt07', year: 2019),
      listing('mt07-no-year', motorcycleId: 'mt07', year: null),
      listing('r7', motorcycleId: 'r7', firstSeenAt: thisWeek),
      listing('unmatched'),
    ];

    test('each account sees its own models from its first year', () {
      expect(listingsFollowed(listings, {'mt07': 2020}).map((l) => l.id), [
        'mt07-2021',
        'mt07-no-year',
      ]);
      expect(listingsFollowed(listings, {}), isEmpty);
    });

    test('every account, or only the one that asked', () {
      final follows = {
        'u1': {'mt07': 2015},
        'u2': {'r7': 2021},
      };
      Map<String, WeeklySummary> summaries([String? account]) =>
          summariesByAccount(
            follows: follows,
            listings: listings,
            history: const [],
            until: until,
            account: account,
          );

      final all = summaries();
      expect(all.keys, ['u1', 'u2']);
      expect(all['u1']!.liveCount, 3);
      expect(all['u2']!.newListings.map((l) => l.id), ['r7']);

      expect(summaries('u2').keys, ['u2']);
      expect(summaries('u3')['u3']!.liveCount, 0);
    });
  });
}
