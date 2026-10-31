import '../../../core/formatting/formatters.dart';
import '../domain/entities/model_market.dart';
import 'market_behaviour_text.dart';
import '../../../core/localization/localizations.dart';

/// Cheapest typical asking price first; models without prices last.
List<ModelMarket> byMedianPrice(List<ModelMarket> models) {
  final sorted = [...models];
  sorted.sort((a, b) {
    final x = a.prices?.median;
    final y = b.prices?.median;
    if (x == null || y == null) {
      if (x != y) return x == null ? 1 : -1;
      return a.name.compareTo(b.name);
    }
    final byPrice = x.compareTo(y);
    return byPrice != 0 ? byPrice : a.name.compareTo(b.name);
  });
  return sorted;
}

/// The asking-price lines of a model in the comparison.
List<String> priceSpreadLines(
  PriceSpread? p, {
  AppLanguage language = .portuguese,
}) {
  if (p == null) return [language.messages.noActiveListingsWithPrice];
  if (p.count < minMarketData) {
    return [language.messages.askingPricesFewData(count: p.count)];
  }

  String price(double value) => Formatters.price(value, language: language);
  final year = p.medianYear;
  final km = p.medianMileage == null
      ? null
      : Formatters.mileage(p.medianMileage, language: language);
  final typical = switch ((year, km)) {
    (null, null) => null,
    (final year?, null) => language.messages.typicalBikeIsFrom(
      year: (year).toString(),
    ),
    (null, final km?) => language.messages.typicalBikeHas(km: km),
    (final year?, final km?) => language.messages.typicalBikeIsFromWith(
      year: (year).toString(),
      km: km,
    ),
  };
  return [
    language.messages.typicalAskingPrice(
      median: price(p.median),
      p25: price(p.p25),
      p75: price(p.p75),
    ),
    language.messages.fromTo(from: price(p.min), to: price(p.max)),
    ?typical,
  ];
}

/// How many weeks back a price trend is measured, at most.
const trendWeeks = 4;

/// The weeks a trend may be read from: those with enough ads.
List<PriceTrendWeek> trendWeeksWithData(List<PriceTrendWeek> weeks) => [
  for (final w in weeks)
    if (w.count >= minMarketData) w,
];

/// The model's price trend: the adjusted median of the latest week with
/// enough ads against the week [trendWeeks] before it, or the earliest week
/// with enough ads since then. A change under 1 % reads as steady.
String priceTrendLine(
  List<PriceTrendWeek> weeks, {
  AppLanguage language = .portuguese,
}) {
  final enough = trendWeeksWithData(weeks);
  if (enough.length < 2) return language.messages.priceTrendFewData;
  final last = enough.last;
  final from = last.weekStart.subtract(const Duration(days: 7 * trendWeeks));
  final first = enough.firstWhere((w) => !w.weekStart.isBefore(from));
  if (identical(first, last)) return language.messages.priceTrendFewData;

  final span = (last.weekStart.difference(first.weekStart).inDays / 7).round();
  final change = (last.adjustedMedian / first.adjustedMedian - 1) * 100;
  if (change.abs() < 1) return language.messages.priceTrendSteady(weeks: span);
  final pct = Formatters.percent(change.abs(), decimals: 1, language: language);
  return change < 0
      ? language.messages.priceTrendDown(pct: pct, weeks: span)
      : language.messages.priceTrendUp(pct: pct, weeks: span);
}
