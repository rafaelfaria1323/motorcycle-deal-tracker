import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/gone_deal.dart';
import 'package:motorcycle_deal_tracker/features/market/presentation/gone_deals_text.dart';

final now = DateTime(2026, 11, 12, 12);

GoneDeal deal(
  String id, {
  int? score,
  int days = 10,
  int goneDaysAgo = 5,
  int? year = 2020,
  int? mileage = 20000,
}) => GoneDeal(
  listingId: id,
  year: year,
  mileage: mileage,
  price: 6000,
  dealScore: score,
  daysListed: days,
  goneAt: now.subtract(Duration(days: goneDaysAgo)),
);

List<GoneDeal> good(List<int> days) => [
  for (final (i, d) in days.indexed) deal('g$i', score: 80 + i, days: d),
];

List<GoneDeal> others(List<int> days) => [
  for (final (i, d) in days.indexed) deal('o$i', score: 60, days: d),
];

void main() {
  group('goneDealsLine', () {
    test('says nothing without good deals', () {
      expect(goneDealsLine(const []), null);
      expect(goneDealsLine(others([1, 2, 3, 4, 5, 6])), null);
      // Never scored: not a good deal.
      expect(goneDealsLine([deal('x')]), null);
    });

    test('only introduces the list below 5 good deals', () {
      expect(
        goneDealsLine(good([3, 4])),
        'Boas oportunidades deste modelo (Deal Score 80 ou mais) que saíram '
        'nos últimos 90 dias e provavelmente foram vendidas:',
      );
      expect(
        goneDealsLine(good([3, 4]), language: .english),
        "This model's good deals (Deal Score 80 or more) that left in the "
        'last 90 days and were likely sold:',
      );
    });

    test('gives the median days from 5 good deals', () {
      expect(
        goneDealsLine(good([9, 3, 5, 4, 20]) + others([30, 40])),
        'As boas oportunidades deste modelo (Deal Score 80 ou mais) que '
        'saíram nos últimos 90 dias e provavelmente foram vendidas estiveram '
        'à venda 5 dias (mediana de 5).',
      );
    });

    test('compares with the other sales when they are 5 too', () {
      final line = goneDealsLine(
        good([1, 2, 3, 4, 5]) + others([20, 30, 40, 50, 60, 70]),
      );
      expect(line, contains('à venda 3 dias (mediana de 5).'));
      expect(line, endsWith(' As outras vendas levaram 45 dias.'));
    });
  });

  test('an even number of good deals averages the middle two', () {
    final line = goneDealsLine(
      good([1, 2, 4, 6, 8, 10]) + others([20, 30, 41, 50, 61, 70]),
    );
    expect(line, contains('à venda 5 dias (mediana de 6).'));
    expect(line, endsWith('As outras vendas levaram 46 dias.'));
    expect(
      goneDealsLine(
        good([0, 0, 0, 1, 1]) + others([1, 1, 1, 1, 1]),
        language: .english,
      ),
      allOf(
        contains('were on sale for less than 1 day (median of 5).'),
        endsWith('The other sales took 1 day.'),
      ),
    );
  });

  group('fastGoneDeals', () {
    test('lists the quickest good deals, the latest first on a tie', () {
      final list = fastGoneDeals([
        deal('slow', score: 90, days: 30),
        deal('other', score: 79, days: 1),
        deal('old', score: 85, days: 2, goneDaysAgo: 40),
        deal('new', score: 85, days: 2, goneDaysAgo: 3),
        deal('quick', score: 80, days: 1),
        deal('next', score: 81, days: 9),
      ]);
      expect([for (final d in list) d.listingId], ['quick', 'new', 'old']);
    });
  });

  group('goneDealText', () {
    test('gives the facts, the days on sale and when it left', () {
      expect(
        goneDealText(deal('a', score: 86, days: 5, goneDaysAgo: 10), now: now),
        '2020 · ${Formatters.mileage(20000)} · ${Formatters.price(6000)} · '
        'Deal Score 86: 5 dias à venda, saiu há 10 dias',
      );
      expect(
        goneDealText(
          deal('a', score: 86, days: 1, goneDaysAgo: 1),
          now: now,
          language: .english,
        ),
        '2020 · ${Formatters.mileage(20000, language: .english)} · '
        '${Formatters.price(6000, language: .english)} · '
        'Deal Score 86: 1 day on sale, left yesterday',
      );
    });

    test('leaves out an unknown year or mileage', () {
      expect(
        goneDealText(
          deal(
            'a',
            score: 90,
            days: 0,
            goneDaysAgo: 0,
            year: null,
            mileage: null,
          ),
          now: now,
        ),
        '${Formatters.price(6000)} · Deal Score 90: menos de 1 dia à venda, '
        'saiu hoje',
      );
    });
  });
}
