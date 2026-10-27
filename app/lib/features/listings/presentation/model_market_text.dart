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
  AppLanguage language = AppLanguage.portuguese,
}) {
  if (p == null) return [language.messages.noActiveListingsWithPrice];
  if (p.count < minMarketData) {
    return [
      language.messages.askingPricesNotEnoughDataYet(
        count: p.count.toString(),
        value: p.count == 1
            ? language.messages.listing
            : language.messages.listings,
      ),
    ];
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
    language.messages.typicalAskingPriceHalfAreBetweenAnd(
      value: price(p.median),
      value2: price(p.p25),
      value3: price(p.p75),
    ),
    language.messages.fromTo(value: price(p.min), value2: price(p.max)),
    ?typical,
  ];
}
