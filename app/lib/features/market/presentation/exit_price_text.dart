import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/exit_price.dart';
import 'market_behaviour_text.dart';

/// "Saíram do mercado por cerca de 6 300 €: …", the price multiplied by
/// [adjust] (a bike's condition, 1 = none). Null below [minMarketData]
/// gone ads: too few to say what they went for.
String? exitPriceLine(
  ExitPrice exit, {
  double adjust = 1,
  AppLanguage language = .portuguese,
}) {
  final median = exit.median;
  if (median == null || exit.goneCount < minMarketData) return null;
  return language.messages.exitPriceLine(
    price: Formatters.price(median * adjust, language: language),
    count: exit.goneCount,
  );
}

/// How [asking] compares with what the model's gone ads left at: "Este
/// anúncio pede 4 % mais." (within 1 %: the same). Null without both.
String? exitPriceComparison(
  ExitPrice exit,
  double? asking, {
  AppLanguage language = .portuguese,
}) {
  final median = exit.median;
  if (asking == null ||
      median == null ||
      median <= 0 ||
      exit.goneCount < minMarketData) {
    return null;
  }
  final messages = language.messages;
  final percent = ((asking / median - 1) * 100).round();
  if (percent.abs() < 1) return messages.exitPriceSame;
  final text = Formatters.percent(percent.abs(), language: language);
  return percent > 0
      ? messages.exitPriceAbove(percent: text)
      : messages.exitPriceBelow(percent: text);
}
