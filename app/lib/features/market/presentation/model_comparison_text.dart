import 'dart:math';

import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../../compare/presentation/compare_text.dart';
import '../../listings/presentation/offer_text.dart' show minComparables;
import '../../listings/presentation/score_explanation.dart';
import '../../valuation/domain/entities/bike_value.dart';
import '../../valuation/domain/entities/fuel_price.dart';
import '../../valuation/domain/entities/ownership_settings.dart';
import '../../valuation/presentation/ownership_cost.dart';
import '../domain/entities/market_behaviour.dart';
import '../domain/entities/model_market.dart';
import 'market_behaviour_text.dart';

/// How many model years the comparison of two models prices (N.81).
const comparedYears = 5;

/// One model in the comparison: its market, its value by year
/// ([comparisonYears] at [expectedMileage]) and the yearly cost of owning
/// its typical bike (null without a typical price).
typedef ComparedModel = ({
  ModelMarket model,
  Map<int, BikeValue> values,
  OwnershipCost? cost,
});

/// Last year and the [comparedYears] - 1 before it: the newest bikes
/// sold used.
List<int> comparisonYears(DateTime now) => [
  for (var i = 1; i <= comparedYears; i++) now.year - i,
];

/// The mileage each year is priced at: the normal for its age.
int comparisonMileage(int year, DateTime now) =>
    expectedMileage(year, decimalYear(now));

/// The yearly cost of owning [model]'s typical bike: bought at its median
/// asking price, of its median year, at the owner's figures.
OwnershipCost? typicalOwnershipCost(
  ModelMarket model, {
  required OwnershipSettings settings,
  FuelPrice? fuelPrice,
}) {
  final prices = model.prices;
  if (prices == null || prices.count < minMarketData) return null;
  return ownershipCost(
    price: prices.median,
    settings: settings,
    engineCc: model.engineCc,
    year: prices.medianYear,
    sport: isSportBike(brand: model.brand, model: model.model),
    maintenance: model.maintenance,
    depreciation: model.behaviour?.depreciation,
    fuelPrice: fuelPrice,
  );
}

/// Two (or more) models side by side, in reading order: what they cost,
/// what each year is worth, how fast they lose value and sell, what
/// owning one costs. Only the loss in value and the cost of owning are a
/// contest (lower is better); the rest are facts about different bikes.
List<CompareRow> modelComparisonRows(
  List<ComparedModel> models, {
  required DateTime now,
  AppLanguage language = .portuguese,
}) {
  final strings = language.messages;
  String price(double v) => roughPrice(v, language: language);
  String pct(double v) =>
      Formatters.percent(v, decimals: 1, language: language);

  CompareRow row(
    String label,
    String? Function(ComparedModel) text, {
    num? Function(ComparedModel)? lowerIsBetter,
  }) => CompareRow(
    label,
    [for (final m in models) text(m) ?? '—'],
    best: lowerIsBetter == null
        ? const {}
        : bestOf([
            for (final m in models) lowerIsBetter(m),
          ], higherIsBetter: false),
  );

  PriceSpread? prices(ComparedModel m) {
    final p = m.model.prices;
    return p == null || p.count < minMarketData ? null : p;
  }

  MarketBehaviour? behaviour(ComparedModel m) => m.model.behaviour;
  Depreciation? depreciation(ComparedModel m) => behaviour(m)?.depreciation;
  // The share of the value lost, as the market page's depreciation line.
  double loss(double rate) => (1 - exp(-rate)) * 100;
  String lossText(Depreciation d, double rate) => d.isFitted
      ? pct(loss(rate))
      : strings.modelCompareGeneralRule(rate: pct(loss(rate)));

  int? daysToGone(ComparedModel m) {
    final b = behaviour(m);
    if (b == null || b.goneCount < minMarketData) return null;
    return b.medianDaysToGone;
  }

  double? droppedShare(ComparedModel m) {
    final b = behaviour(m);
    if (b == null || b.pricedCount < minMarketData) return null;
    return b.droppedCount * 100 / b.pricedCount;
  }

  double? value(ComparedModel m, int year) {
    final v = m.values[year];
    return v == null || v.comparableCount < minComparables ? null : v.estimate;
  }

  double maintenance(OwnershipCost c) =>
      c.tyres + c.services + c.chain + c.valves;

  return [
    row(strings.modelCompareLiveAds, (m) {
      final b = behaviour(m);
      return b == null ? null : '${b.liveCount}';
    }),
    row(strings.modelCompareTypicalPrice, (m) {
      final p = prices(m);
      return p == null ? null : price(p.median);
    }),
    row(strings.modelCompareTypicalBike, (m) {
      final p = prices(m);
      return p == null
          ? null
          : [
              if (p.medianYear != null) '${p.medianYear}',
              if (p.medianMileage != null)
                Formatters.mileage(p.medianMileage, language: language),
            ].join(' · ');
    }),
    for (final year in comparisonYears(now))
      row(
        strings.modelCompareValueOf(
          year: '$year',
          km: Formatters.mileage(
            comparisonMileage(year, now),
            language: language,
          ),
        ),
        (m) {
          final v = value(m, year);
          return v == null ? null : price(v);
        },
      ),
    row(strings.modelCompareLossPerYear, (m) {
      final d = depreciation(m);
      return d == null ? null : lossText(d, d.perYear);
    }, lowerIsBetter: (m) => depreciation(m)?.perYear),
    row(strings.modelCompareLossPer10000Km, (m) {
      final d = depreciation(m);
      return d == null ? null : lossText(d, d.per1000Km * 10);
    }, lowerIsBetter: (m) => depreciation(m)?.per1000Km),
    row(strings.modelCompareTimeToGone, (m) {
      final days = daysToGone(m);
      return days == null ? null : strings.modelCompareDays(days: days);
    }),
    row(strings.modelCompareSellersDropped, (m) {
      final share = droppedShare(m);
      if (share == null) return null;
      final drop = behaviour(m)?.medianDropPct;
      final shareText = Formatters.percent(share.round(), language: language);
      return drop == null || share == 0
          ? shareText
          : strings.modelCompareDroppedBy(share: shareText, drop: pct(drop));
    }),
    row(
      strings.modelCompareCostPerYear,
      (m) => m.cost == null ? null : price(m.cost!.perYear),
      lowerIsBetter: (m) => m.cost?.perYear,
    ),
    row(
      strings.modelCompareCostDepreciation,
      (m) => m.cost == null ? null : price(m.cost!.depreciation),
    ),
    row(strings.modelCompareCostFuel, (m) {
      final fuel = m.cost?.fuel;
      return fuel == null ? null : price(fuel);
    }),
    row(
      strings.modelCompareCostInsuranceTax,
      (m) =>
          m.cost == null ? null : price(m.cost!.insurance + (m.cost!.iuc ?? 0)),
    ),
    row(
      strings.modelCompareCostMaintenance,
      (m) => m.cost == null ? null : price(maintenance(m.cost!)),
    ),
  ];
}

/// The note under the comparison: where the figures come from.
String modelComparisonNote(
  OwnershipSettings settings, {
  AppLanguage language = .portuguese,
}) => language.messages.modelCompareNote(
  km: Formatters.mileage(settings.kmPerYear, language: language),
  years: settings.yearsToKeep,
);
