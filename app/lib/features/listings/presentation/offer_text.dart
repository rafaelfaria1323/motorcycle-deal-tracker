import 'dart:math';

import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/market_behaviour.dart';
import 'market_behaviour_text.dart';
import 'negotiation_text.dart';
import '../../../core/localization/localizations.dart';

/// What to offer for a listing: where to start and the most to pay, with
/// the reasons in words. Built from asking prices, never from sales.
class OfferSuggestion {
  const OfferSuggestion({
    required this.opening,
    required this.ceiling,
    required this.reasons,
  });

  final double opening;
  final double ceiling;
  final List<String> reasons;

  /// "Comece por 6300 € e não passe de 6700 €."
  String headline({AppLanguage language = AppLanguage.portuguese}) =>
      language.messages.startAtAndDoNotGoAbove(
        price: Formatters.price(opening, language: language),
        price2: Formatters.price(ceiling, language: language),
      );

  /// The offers to make in turn: the opening, one halfway to the most to
  /// pay when there is room for it, and the most to pay as the last; each
  /// with the message to send.
  List<OfferStep> steps({AppLanguage language = AppLanguage.portuguese}) {
    final middle = _roundDown((opening + ceiling) / 2);
    return [
      OfferStep(
        language.messages.openingOffer,
        opening,
        offerMessage(opening, language: language),
      ),
      if (middle > opening && middle < ceiling)
        OfferStep(
          language.messages.ifDeclined,
          middle,
          offerMessage(middle, language: language),
        ),
      OfferStep(
        language.messages.finalOffer,
        ceiling,
        lastOfferMessage(ceiling, language: language),
      ),
    ];
  }

  /// The same plan with [amount] off the opening and the most to pay (a
  /// repair found at the visit), and [reason] added. The opening stays
  /// below the most to pay; nothing goes under one rounding step.
  OfferSuggestion lowerBy(double amount, String reason) {
    final newCeiling = max(_roundDown(ceiling - amount), offerStep);
    return OfferSuggestion(
      opening: max(
        min(_roundDown(opening - amount), _roundDown(newCeiling * 0.99)),
        offerStep,
      ),
      ceiling: newCeiling,
      reasons: [...reasons, reason],
    );
  }

  /// What to answer when the seller asks [counter] instead.
  String replyTo(
    double counter, {
    AppLanguage language = AppLanguage.portuguese,
  }) => reply(counter, language: language).advice;

  /// What to do when the seller asks [counter] instead, and the message to
  /// send for it.
  OfferReply reply(
    double counter, {
    AppLanguage language = AppLanguage.portuguese,
  }) {
    final steps = this.steps(language: language);
    // The offer before the last: below it, the seller is already close.
    final second = steps[steps.length - 2].price;
    final value = Formatters.price(counter, language: language);
    if (counter <= opening) {
      return OfferReply(
        language.messages.counterAcceptBelowOpening(asked: value),
        acceptMessage(counter, language: language),
      );
    }
    if (counter <= second) {
      return OfferReply(
        language.messages.counterAcceptWithinWorth(asked: value),
        acceptMessage(counter, language: language),
      );
    }
    if (counter <= ceiling) {
      final halfway = _roundDown((second + counter) / 2);
      // Too close to haggle over: no halfway above your last offer, or
      // one step from the seller's price.
      if (halfway <= second || counter - halfway <= offerStep) {
        return OfferReply(
          language.messages.counterAcceptWithinCeiling(
            asked: value,
            price: Formatters.price(ceiling, language: language),
          ),
          acceptMessage(counter, language: language),
        );
      }
      return OfferReply(
        language.messages.counterOfferHalfway(
          price: Formatters.price(halfway, language: language),
          asked: value,
        ),
        offerMessage(halfway, language: language),
      );
    }
    return OfferReply(
      language.messages.counterAboveCeiling(
        asked: value,
        price: Formatters.price(ceiling, language: language),
      ),
      lastOfferMessage(ceiling, language: language),
    );
  }
}

/// What to do about the seller's counter-offer, and the message to send.
class OfferReply {
  const OfferReply(this.advice, this.message);

  final String advice;
  final String message;
}

/// The seller's counter-offer as typed: "8500", "8.500", "8 500 €". Null
/// for anything that is not a price.
double? parseCounterOffer(
  String text, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final value = Formatters.parsePrice(text, language: language);
  return value != null && value >= offerStep ? value : null;
}

/// One offer of the plan.
class OfferStep {
  const OfferStep(this.label, this.price, this.message);

  final String label;
  final double price;

  /// Ready to send to the seller with this offer.
  final String message;
}

/// Where the opening offer starts below the ceiling before anything else is
/// known: a rule of thumb, not measured (dealers negotiate less).
const privateMargin = 0.06;
const dealerMargin = 0.03;

/// Never suggest starting more than this far below the ceiling.
const maxMargin = 0.10;

/// Never suggest starting more than this far below the estimated value: a
/// much lower offer on a fairly priced bike is rarely taken seriously.
const maxBelowEstimate = 0.10;

/// The text tells of an accident or a repair to do (the risk reasons that
/// cap the Deal Score at 79): the reference is the estimate less the
/// database's repair allowance (`damaged_value`), with this much more room,
/// up to [damagedMaxMargin]. The real damage is unknown, so the reference
/// sets no floor.
const damageMargin = 0.05;
const damagedMaxMargin = 0.15;
const damageReasons = {'possible_accident', 'needs_repair'};

/// Scratches or dents in the text: a little more room.
const cosmeticMargin = 0.02;

/// Up on the site this long without a model figure counts as long.
const defaultLongListingDays = 45;

/// Extra room when on sale longer than the typical time, more than twice
/// it and more than three times it.
const longListingMargins = [0.03, 0.05, 0.07];

/// Extra room for a bike put up again after its earlier ad went.
const relistedMargin = 0.02;

/// The fewest comparable listings an estimate needs to set the most to pay
/// (the database's price score needs the same).
const minComparables = 3;

/// Prices are rounded to this many euros.
const offerStep = 50.0;

/// Asking prices below this are placeholders ("1 €", "consulte"); the
/// database leaves them out of the comparables too.
const minRealPrice = 300.0;

/// Null without an asking price (or a placeholder one, under
/// [minRealPrice]) or an estimated value, when the estimate
/// rests on fewer than 3 comparable listings (as the price score), for a
/// removed listing and for a repeat of another listing (it has no value of
/// its own).
///
/// [daysListed] counts from when the bike went on sale (the site's date,
/// earlier relists included), [market] is the model's behaviour (may be
/// null while it loads or when it failed).
OfferSuggestion? suggestOffer(
  Listing listing, {
  MarketBehaviour? market,
  int? daysListed,
  AppLanguage language = AppLanguage.portuguese,
}) {
  final price = listing.price;
  final undamaged = (listing.scoreBreakdown?['market_price'] as num?)
      ?.toDouble();
  if (price == null ||
      price < minRealPrice ||
      undamaged == null ||
      undamaged <= 0) {
    return null;
  }
  if (listing.isRemoved || listing.duplicateOf != null) return null;
  final comparables = (listing.scoreBreakdown?['market_listing_count'] as num?)
      ?.toInt();
  if (comparables != null && comparables < minComparables) return null;

  final reasons = <String>[];
  final riskReasons =
      (listing.scoreBreakdown?['risk_reasons'] as List? ?? const []).toSet();
  final damaged = riskReasons.any(damageReasons.contains);
  final damagedValue = (listing.scoreBreakdown?['damaged_value'] as num?)
      ?.toDouble();
  final allowance = (listing.scoreBreakdown?['damage_allowance'] as num?)
      ?.toDouble();
  final estimate = damaged && damagedValue != null && damagedValue > 0
      ? damagedValue
      : undamaged;
  if (damaged && allowance != null && damagedValue != null) {
    reasons.add(
      language.messages.offerDamagedValue(
        percent: Formatters.percent(allowance * 100, language: language),
        price: Formatters.price(damagedValue, language: language),
      ),
    );
  }

  // The most to pay: the asking price, or the estimated value when the
  // asking price is above it.
  final double ceiling;
  // How far below the estimate the asking price already is: the seller has
  // given that much already, so it comes off the room to negotiate.
  final alreadyBelow = price < estimate ? 1 - price / estimate : 0.0;
  if (price > estimate * 1.02) {
    ceiling = _roundDown(estimate);
    reasons.add(
      language.messages.askingPriceIsAboveEstimatedValueDoNot(
        percent: Formatters.percent(
          (price / estimate - 1) * 100,
          language: language,
        ),
        price: Formatters.price(ceiling, language: language),
      ),
    );
  } else {
    ceiling = _roundDown(price);
    if (price < estimate * 0.98) {
      reasons.add(
        language.messages.offerAlreadyBelowEstimate(
          percent: Formatters.percent(alreadyBelow * 100, language: language),
          price: Formatters.price(estimate, language: language),
        ),
      );
    } else {
      reasons.add(language.messages.askingPriceIsInLineWithEstimatedValue);
    }
  }

  final dealer = listing.sellerType == SellerType.dealer;
  var margin = dealer ? dealerMargin : privateMargin;
  reasons.add(
    dealer
        ? language.messages.offerDealerOpening(
            percent: Formatters.percent(dealerMargin * 100, language: language),
          )
        : language.messages.privateSellerStartBelowPrice(
            percent: Formatters.percent(
              privateMargin * 100,
              language: language,
            ),
          ),
  );

  // Long on sale: the seller has been waiting and may take a lower offer.
  // More the longer it is: past the typical time, twice it, three times it.
  final enoughGone =
      market != null &&
      market.goneCount >= minMarketData &&
      market.medianDaysToGone != null;
  final typicalDays = enoughGone
      ? market.medianDaysToGone!
      : defaultLongListingDays;
  if (daysListed != null && daysListed > typicalDays) {
    final level = daysListed > 3 * typicalDays
        ? 2
        : daysListed > 2 * typicalDays
        ? 1
        : 0;
    margin += longListingMargins[level];
    final howLong = enoughGone
        ? language.messages.onSaleVsTypical(
            howMuch: [
              language.messages.moreThan,
              language.messages.moreThanTwice,
              language.messages.moreThanThreeTimes,
            ][level],
            typicalDays: (typicalDays).toString(),
          )
        : language.messages.longTime;
    reasons.add(
      language.messages.offerLongOnSale(
        daysListed: (daysListed).toString(),
        howLong: howLong,
        consequence: level == 0
            ? language.messages.thereIsMoreRoomToNegotiate
            : language.messages.sellerMayAcceptLowerOffer,
      ),
    );
  }

  // Put up again after an earlier ad went: it did not sell at that price.
  if (listing.relistedFrom != null) {
    margin += relistedMargin;
    reasons.add(language.messages.itWasListedBeforeAndDidNotSell);
  }

  final dropped = (listing.priceChange ?? 0) <= -1;
  if (dropped) {
    margin -= 0.02;
    reasons.add(language.messages.sellerHasAlreadyReducedPriceThereIsLess);
  } else if (market != null &&
      market.pricedCount >= minMarketData &&
      market.droppedCount * 3 >= market.pricedCount &&
      market.medianDropPct != null) {
    // A third or more of this model's sellers drop, by this much.
    final usual = min(market.medianDropPct! / 2, 4.0);
    margin += usual / 100;
    reasons.add(
      language.messages.offerSellersOftenDrop(
        percent: Formatters.percent(
          market.medianDropPct!,
          decimals: 1,
          language: language,
        ),
      ),
    );
  }

  final risk = listing.riskScore;
  if (risk != null && risk >= 50) {
    margin += 0.03;
    reasons.add(language.messages.riskIsHighCheckWhatIsMissingAnd);
  }

  if (damaged) {
    margin += damageMargin;
    reasons.add(language.messages.offerDamage);
  } else if (riskReasons.contains('cosmetic_damage')) {
    margin += cosmeticMargin;
    reasons.add(language.messages.offerScratches);
  }

  if (ceiling < offerStep) return null;
  // At least 1 % (a dealer's 3 % less an earlier drop, or a price already
  // well below the estimate), so the opening is always below the ceiling.
  margin = (margin - alreadyBelow).clamp(
    0.01,
    damaged ? damagedMaxMargin : maxMargin,
  );
  // The damage is unknown: no floor from the reference.
  final floor = damaged
      ? offerStep
      : _roundDown(estimate * (1 - maxBelowEstimate));
  final opening = min(
    max(_roundDown(ceiling * (1 - margin)), floor),
    _roundDown(ceiling * 0.99),
  );
  return OfferSuggestion(opening: opening, ceiling: ceiling, reasons: reasons);
}

/// Days the bike has been on sale: from the earliest relisted date, the
/// site's publication date or, without one, the first time we saw it.
int? daysOnSale(Listing listing, {DateTime? now}) {
  final since =
      listing.relistedSince ?? listing.publishedAt ?? listing.firstSeenAt;
  if (since == null) return null;
  return max(0, (now ?? DateTime.now()).difference(since).inDays);
}

double _roundDown(double value) => (value / offerStep).floor() * offerStep;
