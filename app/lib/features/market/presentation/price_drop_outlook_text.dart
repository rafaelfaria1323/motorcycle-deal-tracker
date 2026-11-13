import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/price_drop_outlook.dart';
import 'market_behaviour_text.dart';

/// The share of the sample from which a way out counts as frequent.
const outlookFrequentShare = 0.4;

/// What waiting is likely to bring, from what the model's other ads did.
enum OutlookAdvice {
  /// Many dropped and fewer left: waiting may pay.
  wait,

  /// Many left before dropping: waiting risks losing the bike.
  buyNow,

  /// Neither often: the offer is where the price moves.
  neutral,
}

OutlookAdvice outlookAdvice(PriceDropOutlook o) {
  final dropShare = o.dropped / o.sample;
  final goneShare = o.gone / o.sample;
  if (dropShare >= outlookFrequentShare && dropShare > goneShare) {
    return OutlookAdvice.wait;
  }
  if (goneShare >= outlookFrequentShare) return OutlookAdvice.buyNow;
  return OutlookAdvice.neutral;
}

/// "Esperar ou comprar já?" (N.83): the lines of the card, null below
/// [minMarketData] ads followed.
({String intro, List<String> lines, String advice})? priceDropOutlookText(
  PriceDropOutlook o, {
  AppLanguage language = .portuguese,
}) {
  if (o.sample < minMarketData) return null;
  final messages = language.messages;
  final drop = o.medianDrop;
  return (
    intro: messages.priceDropOutlookIntro(days: o.days),
    lines: [
      if (drop != null && o.dropped > 0)
        messages.priceDropOutlookDroppedBy(
          count: o.dropped,
          sample: o.sample,
          drop: Formatters.percent(drop, language: language),
        )
      else
        messages.priceDropOutlookDropped(count: o.dropped, sample: o.sample),
      messages.priceDropOutlookGone(count: o.gone, sample: o.sample),
      messages.priceDropOutlookUnchanged(count: o.unchanged, sample: o.sample),
    ],
    advice: switch (outlookAdvice(o)) {
      .wait => messages.priceDropOutlookWait,
      .buyNow => messages.priceDropOutlookBuyNow,
      .neutral => messages.priceDropOutlookNeutral,
    },
  );
}
