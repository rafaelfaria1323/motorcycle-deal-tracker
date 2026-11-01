import '../../../core/formatting/formatters.dart';
import '../../favourites/domain/entities/favourite.dart';
import '../domain/entities/listing.dart';
import '../../market/domain/entities/market_behaviour.dart';
import '../../market/presentation/market_behaviour_text.dart';
import 'offer_text.dart';
import '../../valuation/presentation/ownership_cost.dart';
import 'score_explanation.dart';
import '../../favourites/presentation/viewing_checklist.dart';
import '../../../core/localization/localizations.dart';

/// A problem marked at the visit and what fixing it typically costs.
class const VisitRepair(final String title, final double cost);

/// What the viewing checklist found: problems with a repair cost, and
/// problems that stop the deal until they are cleared up.
class const VisitFindings({
  final List<VisitRepair> repairs = const [],
  final List<String> blockers = const [],
}) {
  double get total => repairs.fold(0, (sum, r) => sum + r.cost);

  bool get isEmpty => repairs.isEmpty && blockers.isEmpty;

  /// "pneus (~300 €), corrente e cremalheira (~200 €)".
  String repairsText({AppLanguage language = .portuguese}) => repairs
      .map(
        (r) =>
            '${r.title.toLowerCase()} (~${Formatters.price(r.cost, language: language)})',
      )
      .join(', ');
}

/// Checklist items whose problem is no matter of price: papers that don't
/// match, a debt on the bike, an engine or gearbox that needs a mechanic.
const visitBlockers = {'documents', 'registry', 'cold_start', 'test_ride'};

/// The typical cost of fixing a problem marked on [key] (workshop prices,
/// 2026), from the bike's running costs where they apply. Null for items
/// with no fixed price (the blockers).
double? repairCost(String key, RunningCostTable costs) => switch (key) {
  'tyres' => costs.tyreSet,
  'chain' => costs.chainKit,
  'service' => costs.service,
  'brakes' => 150,
  'suspension' => 200,
  'fall' => 150,
  'keys' => 120,
  'electrics' => 80,
  _ => null,
};

/// The problems marked in [checklist], in list order.
VisitFindings visitFindings(
  Map<String, ChecklistEntry> checklist, {
  int? engineCc,
  AppLanguage language = .portuguese,
}) {
  final costs = runningCostsFor(engineCc);
  final repairs = <VisitRepair>[];
  final blockers = <String>[];
  for (final item in viewingChecklistItems(language: language)) {
    if (checklist[item.key]?.mark != .issue) continue;
    if (visitBlockers.contains(item.key)) {
      blockers.add(item.title);
    } else if (repairCost(item.key, costs) case final cost?) {
      repairs.add(VisitRepair(item.title, cost));
    }
  }
  return VisitFindings(repairs: repairs, blockers: blockers);
}

/// The offer after the visit: the repairs come off both the opening and
/// the most to pay. Unchanged without repairs.
OfferSuggestion afterVisit(
  OfferSuggestion offer,
  VisitFindings findings, {
  AppLanguage language = .portuguese,
}) {
  if (findings.repairs.isEmpty) return offer;
  return offer.lowerBy(
    findings.total,
    language.messages.atViewingThisIsDeductedFromOfferAnd(
      repairsText: findings.repairsText(language: language),
    ),
  );
}

/// Tyres this old are probably due, unless the ad says they are new.
const oldTyresYears = 5;

/// What to say to the seller to justify a lower price, strongest first,
/// from what we know of this bike and its market. [cheaper] are live
/// listings of the same model, of a similar year and not more km, that
/// cost less; [visit] what the viewing checklist found.
List<String> negotiationArguments(
  Listing listing, {
  MarketBehaviour? market,
  int? daysListed,
  List<Listing> cheaper = const [],
  VisitFindings? visit,
  DateTime? today,
  AppLanguage language = .portuguese,
}) {
  final now = today ?? DateTime.now();
  final price = listing.price;
  final data = listing.scoreBreakdown ?? const <String, dynamic>{};
  final arguments = <String>[];

  if (visit != null && visit.repairs.isNotEmpty) {
    arguments.add(
      language.messages.foundAtViewingYouWillNeedToSpend(
        repairsText: visit.repairsText(language: language),
        price: Formatters.price(visit.total, language: language),
      ),
    );
  }

  final estimate = (data['market_price'] as num?)?.toDouble();
  final comparables = (data['market_listing_count'] as num?)?.toInt();
  if (price != null &&
      estimate != null &&
      estimate > 0 &&
      (comparables ?? minComparables) >= minComparables &&
      price > estimate * 1.03) {
    arguments.add(
      language.messages.itIsAboveMarketValueForItsYear(
        percent: Formatters.percent(
          (price / estimate - 1) * 100,
          language: language,
        ),
        price: Formatters.price(price - estimate, language: language),
        price3: Formatters.price(estimate, language: language),
      ),
    );
  }

  if (cheaper.isNotEmpty) {
    final cheapest = cheaper
        .map((l) => l.price)
        .whereType<double>()
        .fold<double?>(null, (a, b) => a == null || b < a ? b : a);
    if (cheapest != null) {
      arguments.add(
        language.messages.cheaperSimilarListings(
          count: cheaper.length,
          model: listing.model,
          price: Formatters.price(cheapest, language: language),
        ),
      );
    }
  }

  final km = listing.mileage;
  final year = listing.year;
  if (km != null && year != null) {
    final normal = expectedMileage(year, decimalYear(now));
    if (km > normal * 1.1) {
      arguments.add(
        language.messages.itHasAboveNormalForBikeFromAbout(
          mileage: Formatters.mileage(km, language: language),
          year: (year).toString(),
          mileage3: Formatters.mileage(normal, language: language),
        ),
      );
    }
  }

  final reasons = (data['risk_reasons'] as List? ?? const []).toSet();
  for (final (code, text) in _riskArguments(language: language)) {
    if (reasons.contains(code)) arguments.add(text);
  }
  if (reasons.contains('relisted') || reasons.contains('relisted_often')) {
    arguments.add(language.messages.itWasForSaleInAnotherListingAnd);
  }

  if (daysListed != null) {
    final typical =
        market != null &&
            market.goneCount >= minMarketData &&
            market.medianDaysToGone != null
        ? market.medianDaysToGone!
        : null;
    if (daysListed > (typical ?? defaultLongListingDays)) {
      arguments.add(
        typical == null
            ? language.messages.itHasBeenForSaleForDays(
                daysListed: (daysListed).toString(),
              )
            : language.messages.itHasBeenForSaleForDaysBike(
                daysListed: (daysListed).toString(),
                typical: (typical).toString(),
              ),
      );
    }
  }

  final initial = listing.initialPrice;
  if (price != null && initial != null && initial > price) {
    arguments.add(
      language.messages.priceAlreadyDroppedFromToSellerWantsTo(
        price: Formatters.price(initial, language: language),
        price2: Formatters.price(price, language: language),
      ),
    );
  }

  final extras = data['extras'] as List? ?? const [];
  if (year != null &&
      now.year - year >= oldTyresYears &&
      !extras.contains('new_tyres') &&
      visit?.repairs.any((r) => r.title == language.messages.tyres) != true) {
    arguments.add(
      language.messages.argumentOldTyres(
        age: (now.year - year).toString(),
        price: Formatters.price(
          runningCostsFor(listing.engineCc).tyreSet,
          language: language,
        ),
      ),
    );
  }

  return arguments;
}

List<(String, String)> _riskArguments({AppLanguage language = .portuguese}) => [
  ('possible_accident', language.messages.argumentAccidentResale),
  ('needs_repair', language.messages.itNeedsRepairsOrPartsYouWillHave),
  ('cosmetic_damage', language.messages.itHasScratchesOrDentsThatAffectPrice),
  (
    'no_service_book',
    language.messages.itDoesNotHaveCompleteServiceBookMissing,
  ),
  ('many_owners', language.messages.itHasHad3OrMoreOwners),
  ('imported', language.messages.itIsImportedItWillBeWorthLess),
  ('a2_limited', language.messages.itIsA2Version35KWRemovingRestriction),
  ('a2_unlocked', language.messages.itWasUnrestrictedA2VersionAndDoesNot),
  ('text_mileage_mismatch', language.messages.argumentMoreMileageInText),
  (
    'text_year_mismatch',
    language.messages.yearInDescriptionDoesNotMatchListing,
  ),
];

/// Ready to send when making the offer [amount] (the first or a second
/// one).
String offerMessage(double amount, {AppLanguage language = .portuguese}) =>
    language.messages.thankYouForYourReplyIfEverythingIs(
      price: Formatters.price(amount, language: language),
    );

/// Ready to send with the most you will pay.
String lastOfferMessage(double amount, {AppLanguage language = .portuguese}) =>
    language.messages.iUnderstandMyFinalOfferIsThatIs(
      price: Formatters.price(amount, language: language),
    );

/// Ready to send when taking the seller's price.
String acceptMessage(double amount, {AppLanguage language = .portuguese}) =>
    language.messages.agreedWhenAndWhereCanWeCompletePurchase(
      price: Formatters.price(amount, language: language),
    );

String walkAwayMessage({AppLanguage language = .portuguese}) =>
    language.messages.thankYouForYourTimeICannotManage;

enum Urgency { low, medium, high }

/// How keen the seller seems to be to sell, from what the ads show, with
/// the reasons ("à venda há 90 dias", "já baixou o preço").
class const SellerUrgency(final Urgency level, final List<String> reasons) {
  /// "Pressa do vendedor: alta (à venda há 90 dias, já baixou o preço)".
  String text({AppLanguage language = .portuguese}) {
    final label = switch (level) {
      Urgency.high => language.messages.high,
      Urgency.medium => language.messages.medium,
      Urgency.low => language.messages.low,
    };
    return reasons.isEmpty
        ? language.messages.sellerUrgency(label: label)
        : language.messages.sellerUrgencyLine(
            label: label,
            reasons: reasons.join(', '),
          );
  }
}

/// An ad renewed on the site this recently, and at least this long after it
/// was published, is one the seller is still pushing.
const recentRenewalDays = 30;

/// Points: on sale past the model's typical time (1, 2 past twice it, 3
/// past three times it: that alone is high), an earlier drop (1), put up
/// again after an earlier ad (1, or 2 when often), an old ad renewed on the
/// site in the last [recentRenewalDays] days (1). 3 or more is high, 1-2
/// medium, none low.
SellerUrgency sellerUrgency(
  Listing listing, {
  MarketBehaviour? market,
  int? daysListed,
  DateTime? today,
  AppLanguage language = .portuguese,
}) {
  var points = 0;
  final reasons = <String>[];

  final typical =
      market != null &&
          market.goneCount >= minMarketData &&
          market.medianDaysToGone != null
      ? market.medianDaysToGone!
      : defaultLongListingDays;
  if (daysListed != null && daysListed > typical) {
    points += daysListed > 3 * typical
        ? 3
        : daysListed > 2 * typical
        ? 2
        : 1;
    reasons.add(
      language.messages.forSaleForDays(daysListed: (daysListed).toString()),
    );
  }

  final price = listing.price;
  final before = [listing.initialPrice, listing.priceBeforeDrop]
      .whereType<double>()
      .fold<double?>(null, (a, b) => a == null || b > a ? b : a);
  if (price != null && before != null && before > price) {
    points += 1;
    reasons.add(language.messages.alreadyReducedPrice);
  }

  final renewed = listing.siteRefreshedAt;
  final published = listing.publishedAt;
  if (renewed != null && published != null) {
    final ago = (today ?? DateTime.now()).difference(renewed).inDays;
    if (ago <= recentRenewalDays &&
        renewed.difference(published).inDays >= recentRenewalDays) {
      points += 1;
      reasons.add(
        ago == 0
            ? language.messages.renewedListingToday
            : language.messages.renewedListingDaysAgo(ago: (ago).toString()),
      );
    }
  }

  final risk = (listing.scoreBreakdown?['risk_reasons'] as List? ?? const [])
      .toSet();
  if (risk.contains('relisted_often')) {
    points += 2;
    reasons.add(language.messages.relistedSeveralTimes);
  } else if (risk.contains('relisted') || listing.relistedFrom != null) {
    points += 1;
    reasons.add(language.messages.wasInEarlierListing);
  }

  final level = points >= 3
      ? Urgency.high
      : points >= 1
      ? Urgency.medium
      : Urgency.low;
  return SellerUrgency(level, reasons);
}

/// A dealer rarely gives much off the price but often adds something: what
/// to ask for instead of (or as well as) a discount. Tyres only on a bike
/// old enough for them to be due, unless the ad says they are new.
List<String> dealerAsks(
  Listing listing, {
  DateTime? today,
  AppLanguage language = .portuguese,
}) {
  final year = listing.year;
  final extras = listing.scoreBreakdown?['extras'] as List? ?? const [];
  final tyresDue =
      !extras.contains('new_tyres') &&
      ((year != null && (today ?? DateTime.now()).year - year >= 3) ||
          (listing.mileage ?? 0) >= 10000);
  return [
    language.messages.serviceBeforeDelivery,
    if (tyresDue) language.messages.newTyres,
    language.messages.dealerAskWarranty,
    language.messages.ownershipRegistrationPaidByDealer,
  ];
}

/// Ready to send to a dealer: the price, and the extras to include.
String dealerMessage(
  Listing listing,
  double amount, {
  DateTime? today,
  AppLanguage language = .portuguese,
}) {
  final asks = dealerAsks(listing, today: today, language: language);
  return [
    language.messages.helloGoodAfternoon,
    '',
    language.messages.dealerAsksMessage(
      brand: listing.brand,
      model: listing.model,
      year: listing.year == null
          ? ''
          : language.messages.fromNegotiationText(
              year: listing.year.toString(),
            ),
      price: Formatters.price(amount, language: language),
    ),
    for (final ask in asks) '- $ask;',
    '',
    language.messages.thankYou,
  ].join('\n');
}
