import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/model_market.dart';
import 'package:motorcycle_deal_tracker/features/market/presentation/model_market_text.dart';

PriceSpread spread({
  int count = 12,
  double median = 7000,
  int? year = 2020,
  int? mileage = 15000,
}) => PriceSpread(
  count: count,
  min: 5000,
  p25: 6000,
  median: median,
  p75: 8000,
  max: 9500,
  medianYear: year,
  medianMileage: mileage,
);

ModelMarket model(String name, {double? median}) => ModelMarket(
  motorcycleId: name,
  brand: 'Marca',
  model: name,
  prices: median == null ? null : spread(median: median),
);

PriceTrendWeek week(int daysFromStart, double adjusted, {int count = 8}) =>
    PriceTrendWeek(
      weekStart: DateTime.utc(2026, 9, 7).add(Duration(days: daysFromStart)),
      count: count,
      median: adjusted + 500,
      adjustedMedian: adjusted,
    );

void main() {
  group('priceTrendLine', () {
    test('the latest week against the one four weeks before', () {
      final weeks = [
        week(0, 9000),
        week(7, 8000),
        week(14, 7900),
        week(21, 7800),
        week(28, 7600),
        week(35, 7600),
      ];
      // From 8 000 (week 7) to 7 600 (week 35): 5 % down in 4 weeks.
      expect(
        priceTrendLine(weeks),
        'Preço típico desceu ${Formatters.percent(5, decimals: 1)} '
        'nas últimas 4 semanas (ajustado ao ano e km)',
      );
      expect(
        priceTrendLine(weeks, language: AppLanguage.english),
        'Typical price down '
        '${Formatters.percent(5, decimals: 1, language: AppLanguage.english)} '
        'over the last 4 weeks (adjusted for year and km)',
      );
    });

    test('reads the adjusted median, not the plain one', () {
      expect(
        priceTrendLine([week(0, 8000), week(7, 8400)]),
        'Preço típico subiu ${Formatters.percent(5, decimals: 1)} '
        'na última semana (ajustado ao ano e km)',
      );
    });

    test('weeks with few ads are left out at both ends', () {
      final weeks = [
        week(0, 5000, count: 4),
        week(7, 8000),
        week(14, 8050),
        week(21, 7000, count: 4),
      ];
      expect(
        priceTrendLine(weeks),
        'Preço típico estável na última semana (ajustado ao ano e km)',
      );
    });

    test('under 1 % either way is steady', () {
      expect(
        priceTrendLine([week(0, 8000), week(14, 7925)]),
        'Preço típico estável nas últimas 2 semanas (ajustado ao ano e km)',
      );
      expect(
        priceTrendLine([week(0, 8000), week(14, 8075)]),
        'Preço típico estável nas últimas 2 semanas (ajustado ao ano e km)',
      );
      expect(
        priceTrendLine([week(0, 8000), week(14, 8080)]),
        startsWith('Preço típico subiu'),
      );
    });

    test('a single week with enough ads is too little', () {
      const few = 'Tendência dos preços: ainda poucos dados';
      expect(priceTrendLine(const []), few);
      expect(priceTrendLine([week(0, 8000)]), few);
      expect(priceTrendLine([week(0, 8000), week(7, 7000, count: 4)]), few);
      expect(
        priceTrendLine([
          week(0, 8000, count: 4),
        ], language: AppLanguage.english),
        'Price trend: not enough data yet',
      );
    });

    test('trendWeeksWithData keeps the weeks with at least 5 ads', () {
      final weeks = [week(0, 1, count: 5), week(7, 2, count: 4)];
      expect(trendWeeksWithData(weeks), [weeks.first]);
    });
  });

  group('priceSpreadLines', () {
    test('typical price, middle half, range and the typical bike', () {
      expect(priceSpreadLines(spread()), [
        'Preço pedido típico ${Formatters.price(7000)} '
            '(metade entre ${Formatters.price(6000)} e '
            '${Formatters.price(8000)})',
        'De ${Formatters.price(5000)} a ${Formatters.price(9500)}',
        'A mota típica é de 2020, com ${Formatters.mileage(15000)}',
      ]);
    });

    test('the typical bike leaves out what is unknown', () {
      expect(
        priceSpreadLines(spread(mileage: null)).last,
        'A mota típica é de 2020',
      );
      expect(
        priceSpreadLines(spread(year: null)).last,
        'A mota típica tem ${Formatters.mileage(15000)}',
      );
      expect(priceSpreadLines(spread(year: null, mileage: null)), hasLength(2));
    });

    test('few listings are not presented as a typical price', () {
      expect(priceSpreadLines(spread(count: 4)), [
        'Preços pedidos: ainda poucos dados (4 anúncios)',
      ]);
      expect(priceSpreadLines(spread(count: 1)), [
        'Preços pedidos: ainda poucos dados (1 anúncio)',
      ]);
      expect(priceSpreadLines(spread(count: 5)), hasLength(3));
    });

    test('no live listing with a price', () {
      expect(priceSpreadLines(null), ['Sem anúncios ativos com preço']);
    });
  });

  test('byMedianPrice: cheapest first, ties by name, no prices last', () {
    final sorted = byMedianPrice([
      model('D'),
      model('C', median: 8000),
      model('B', median: 6000),
      model('A'),
      model('E', median: 6000),
    ]);

    expect([for (final m in sorted) m.model], ['B', 'E', 'C', 'A', 'D']);
  });
}
