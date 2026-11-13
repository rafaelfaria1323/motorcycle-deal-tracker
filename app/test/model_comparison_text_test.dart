import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/compare/presentation/compare_text.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/model_market.dart';
import 'package:motorcycle_deal_tracker/features/market/presentation/model_comparison_text.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/bike_value.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/ownership_settings.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/ownership_cost.dart';

final now = DateTime(2026, 11, 13);

PriceSpread spread({int count = 12, double median = 7000}) => PriceSpread(
  count: count,
  min: median - 2000,
  p25: median - 1000,
  median: median,
  p75: median + 1000,
  max: median + 2000,
  medianYear: 2021,
  medianMileage: 20000,
);

MarketBehaviour behaviour({
  double perYear = 0.08,
  double per1000Km = 0.006,
  bool fitted = true,
  int gone = 8,
  int priced = 10,
  int dropped = 4,
}) => MarketBehaviour(
  liveCount: 12,
  goneCount: gone,
  pricedCount: priced,
  droppedCount: dropped,
  medianDaysToGone: 40,
  medianDropPct: 5.2,
  depreciation: Depreciation(
    sampleCount: fitted ? 40 : 10,
    isFitted: fitted,
    perYear: perYear,
    per1000Km: per1000Km,
  ),
);

ModelMarket market(
  String name, {
  PriceSpread? prices,
  MarketBehaviour? behaviour,
  int? engineCc = 690,
}) => ModelMarket(
  motorcycleId: name,
  brand: 'Yamaha',
  model: name,
  prices: prices,
  behaviour: behaviour,
  engineCc: engineCc,
);

ComparedModel compared(
  ModelMarket model, {
  Map<int, BikeValue> values = const {},
  bool withCost = true,
}) => (
  model: model,
  values: values,
  cost: withCost
      ? typicalOwnershipCost(model, settings: const OwnershipSettings())
      : null,
);

CompareRow rowNamed(List<CompareRow> rows, String label) =>
    rows.singleWhere((r) => r.label == label);

void main() {
  final strings = AppLanguage.portuguese.messages;

  test('the five model years before this one', () {
    expect(comparisonYears(now), [2025, 2024, 2023, 2022, 2021]);
  });

  test('each year is priced at the normal mileage for its age', () {
    expect(
      comparisonMileage(2021, now),
      greaterThan(comparisonMileage(2025, now)),
    );
    // A bike of last year counts at least a year's use.
    expect(comparisonMileage(2025, now), greaterThanOrEqualTo(5000));
  });

  group('typicalOwnershipCost', () {
    test('needs five priced ads', () {
      expect(
        typicalOwnershipCost(
          market('MT-07', prices: spread(count: 4)),
          settings: const OwnershipSettings(),
        ),
        isNull,
      );
      expect(
        typicalOwnershipCost(
          market('MT-07', prices: spread()),
          settings: const OwnershipSettings(),
        ),
        isNotNull,
      );
    });

    test('a dearer bike of the same kind costs more to own', () {
      final cheap = typicalOwnershipCost(
        market('A', prices: spread(median: 5000), behaviour: behaviour()),
        settings: const OwnershipSettings(),
      )!;
      final dear = typicalOwnershipCost(
        market('B', prices: spread(median: 9000), behaviour: behaviour()),
        settings: const OwnershipSettings(),
      )!;
      expect(dear.perYear, greaterThan(cheap.perYear));
      expect(dear.depreciation, greaterThan(cheap.depreciation));
    });
  });

  group('modelComparisonRows', () {
    final a = compared(
      market('MT-07', prices: spread(), behaviour: behaviour()),
      values: {
        2025: const BikeValue(comparableCount: 5, estimate: 7400),
        2024: const BikeValue(comparableCount: 2, estimate: 6900),
      },
    );
    final b = compared(
      market(
        'R7',
        prices: spread(median: 9000),
        behaviour: behaviour(perYear: 0.05, per1000Km: 0.009),
      ),
      values: {2025: const BikeValue(comparableCount: 9, estimate: 9100)},
    );
    final rows = modelComparisonRows([a, b], now: now);

    test('one column per model, a dash for too little data', () {
      expect(rows.every((r) => r.values.length == 2), isTrue);
      final y2025 = rows.firstWhere((r) => r.label.contains('2025'));
      expect(y2025.values, [roughPrice(7400), roughPrice(9100)]);
      // Two comparables are not enough for a value.
      final y2024 = rows.firstWhere((r) => r.label.contains('2024'));
      expect(y2024.values, ['—', '—']);
    });

    test('the facts are not a contest', () {
      for (final label in [
        strings.modelCompareLiveAds,
        strings.modelCompareTypicalPrice,
        strings.modelCompareTimeToGone,
        strings.modelCompareSellersDropped,
      ]) {
        expect(rowNamed(rows, label).best, isEmpty, reason: label);
      }
    });

    test('lower loss and cost win', () {
      // R7 loses less a year, MT-07 less per 10 000 km.
      expect(rowNamed(rows, strings.modelCompareLossPerYear).best, {1});
      expect(rowNamed(rows, strings.modelCompareLossPer10000Km).best, {0});
      // The cheaper MT-07 costs less to own.
      expect(rowNamed(rows, strings.modelCompareCostPerYear).best, {0});
      expect(rowNamed(rows, strings.modelCompareTypicalPrice).values, [
        roughPrice(7000),
        roughPrice(9000),
      ]);
    });

    test('time to gone and price drops need five ads', () {
      final few = compared(
        market(
          'R3',
          prices: spread(count: 3),
          behaviour: behaviour(gone: 4, priced: 4),
        ),
        withCost: false,
      );
      final fewRows = modelComparisonRows([a, few], now: now);
      expect(rowNamed(fewRows, strings.modelCompareTimeToGone).values, [
        strings.modelCompareDays(days: 40),
        '—',
      ]);
      expect(
        rowNamed(fewRows, strings.modelCompareSellersDropped).values[1],
        '—',
      );
      expect(
        rowNamed(fewRows, strings.modelCompareTypicalPrice).values[1],
        '—',
      );
      // One known cost is no contest.
      expect(rowNamed(fewRows, strings.modelCompareCostPerYear).best, isEmpty);
    });

    test('general rates say so', () {
      final general = compared(
        market('R1', prices: spread(), behaviour: behaviour(fitted: false)),
      );
      final value = rowNamed(
        modelComparisonRows([a, general], now: now),
        strings.modelCompareLossPerYear,
      ).values[1];
      expect(value, contains('regra geral'));
    });

    test('English', () {
      final english = modelComparisonRows(
        [a, b],
        now: now,
        language: AppLanguage.english,
      );
      expect(english.first.label, 'Ads for sale');
      expect(english.first.values, ['12', '12']);
    });
  });

  test('the note names the owner\'s km and years', () {
    final note = modelComparisonNote(
      const OwnershipSettings(kmPerYear: 6000, yearsToKeep: 3),
    );
    expect(note, contains(Formatters.mileage(6000)));
    expect(note, contains('3 anos'));
  });
}
